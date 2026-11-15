terraform {
  required_version = ">= 1.6.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
variable "region" {
  type    = string
  default = "us-east-1"
  validation {
    condition     = var.region == "us-east-1"
    error_message = "This workshop only uses us-east-1."
  }
}
provider "aws" { region = var.region }
variable "repo_url" {
  type        = string
  description = "Public GitHub HTTPS clone URL; main must contain the tested S3 app before apply."
  validation {
    condition     = can(regex("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\\.git$", var.repo_url))
    error_message = "Use a public https://github.com/OWNER/REPO.git URL without credentials."
  }
}
variable "lab_id" {
  type        = string
  description = "A unique short lowercase label for this participant's lab."
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,30}$", var.lab_id))
    error_message = "Use 3-31 lowercase letters, digits or hyphens."
  }
}
variable "bucket_name" {
  type = string
  validation {
    condition     = startswith(var.bucket_name, "jblabs-")
    error_message = "The globally unique bucket name must start with jblabs-."
  }
}
variable "ami_id" {
  type        = string
  description = "Ubuntu 22.04 LTS x86_64 in us-east-1; verify before class."
  default     = "ami-033ea4ff4a9c726dc"
}
variable "student_ceiling_arn" {
  type        = string
  description = "The actual existing platform StudentCeiling policy ARN; discover, do not invent."
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:policy/(.*/)?StudentCeiling$", var.student_ceiling_arn))
    error_message = "Use the existing StudentCeiling policy ARN from this lab account."
  }
}
variable "ssh_public_key_path" {
  type        = string
  description = "Path to the public .pub file of the local lab SSH key; keep the private key outside Git."
}
variable "ssh_cidr" {
  type        = string
  description = "Verified training host egress IPv4 CIDR for diagnostic SSH."
  validation {
    condition     = can(cidrnetmask(var.ssh_cidr)) && var.ssh_cidr != "0.0.0.0/0"
    error_message = "Use a restricted IPv4 CIDR for SSH."
  }
}
variable "allowed_cidrs" {
  type        = list(string)
  description = "Verified approved browser/training source IPv4 CIDRs for port 8080."
  validation {
    condition     = length(var.allowed_cidrs) > 0 && alltrue([for c in var.allowed_cidrs : can(cidrnetmask(c)) && c != "0.0.0.0/0"])
    error_message = "Use at least one restricted IPv4 source CIDR for the app."
  }
}
locals {
  name       = "student-notes-${var.lab_id}"
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"
}
# A clean class account has no default VPC. Terraform owns this dedicated
# public network; no console setup, default VPC, NAT or paid endpoint is needed.
resource "aws_vpc" "lab" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = local.name }
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public" }
}
resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = local.name }
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
  tags = { Name = local.name }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "terraform_data" "notes" {
  input            = { bucket_name = var.bucket_name, region = var.region }
  triggers_replace = [var.bucket_name]
  provisioner "local-exec" {
    command     = "bash ./bucket.sh create"
    environment = { BUCKET_NAME = self.input.bucket_name, BUCKET_REGION = self.input.region }
  }
  provisioner "local-exec" {
    when        = destroy
    command     = "bash ./bucket.sh delete"
    environment = { BUCKET_NAME = self.input.bucket_name, BUCKET_REGION = self.input.region }
  }
}
# New bucket private defaults; no bucket policy, lifecycle or ACL changes.
resource "aws_iam_role" "app" {
  name                 = "${local.name}-role"
  permissions_boundary = var.student_ceiling_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}
# This is an IAM identity policy, NOT a disallowed S3 bucket policy.
# The app only writes notes; the learner's CLI identity reads them back.
resource "aws_iam_role_policy" "notes_write" {
  name       = "${local.name}-write"
  role       = aws_iam_role.app.id
  depends_on = [terraform_data.notes]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${local.bucket_arn}/notes/*"
    }]
  })
}
resource "aws_iam_instance_profile" "app" {
  name = "${local.name}-profile"
  role = aws_iam_role.app.name
}
resource "aws_key_pair" "lab" {
  key_name   = "${local.name}-ssh"
  public_key = file(pathexpand(var.ssh_public_key_path))
}
resource "aws_security_group" "web" {
  name_prefix = "${local.name}-"
  vpc_id      = aws_vpc.lab.id
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.app.name
  key_name                    = aws_key_pair.lab.key_name
  metadata_options { http_tokens = "required" }
  # App updates use Git on the SAME running EC2, not user-data replacement.
  user_data_replace_on_change = false
  user_data = templatefile("${path.module}/bootstrap.sh.tftpl", {
    repo_url    = var.repo_url
    bucket_name = terraform_data.notes.output.bucket_name
    region      = var.region
  })
  depends_on = [aws_iam_role_policy.notes_write, aws_route_table_association.public]
  tags       = { Name = local.name }
}
output "bucket_name" { value = terraform_data.notes.output.bucket_name }
output "instance_id" { value = aws_instance.app.id }
output "app_url" { value = "http://${aws_instance.app.public_ip}:8080" }
