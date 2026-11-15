# Workshop prompts — one continuous project

Run these in order from the Ubuntu training project. They are instructions for
Codex, not commands to paste directly into Bash. Never put AWS/GitHub secrets in
chat or source. The instructor examples help learners write their own lab prompts.

## 1. Inspect first
Inspect this Ubuntu server and project without changing anything. Report Python,
venv, Git, AWS CLI, Terraform, repository status and whether port 8080 is available.

## 2. Connect one public repository
Set up this folder for the same public GitHub main repository. Review .gitignore,
create a README, commit and push. If authentication is missing, guide me through
GitHub device login. Compare local/remote SHA and verify an anonymous clone.

## 3. Build and run locally
Create a minimal Flask notes form with title/content and Save note. POST /notes
validates input, saves unique notes/<id>.json locally and returns its key. Add
GET /health. Create .venv, install dependencies, run on 0.0.0.0:8080 with debug off,
submit a note, read the exact file and test an empty title returns 400.

## 4. Publish the local version
Review source, commit and push the working app to our SAME public main. Verify
push, matching SHA and anonymous clone without stored credentials.

## 5. Add S3 and publish BEFORE EC2
Keep local mode when S3_BUCKET is unset. With it set, use boto3 PutObject for
UTF-8 JSON in that bucket's notes/* prefix. Add boto3, test honestly and push this
S3-ready version, Terraform and scripts BEFORE the initial EC2 apply.

## 6. Prepare the full environment
Use us-east-1, t3.micro, the verified Ubuntu x86_64 AMI and jblabs-* bucket.
Create our VPC/public subnet/route, security group and SSH public-key registration.
Create student-* role/policy/profile with existing StudentCeiling on the role and
only s3:PutObject to our bucket notes/*. EC2 first boot must clone our PUBLIC main
and start on 8080, without any AWS/GitHub credentials in code or startup data.
Keep application source out of Terraform user data. Use exactly one app EC2 and
one bucket, 12 resources total. Restrict 8080 to approved sources and 22 to the
training host. Discover real boundary ARN; generate a local SSH key outside Git.
Format/validate and show the initial plan. Stop before apply for review.

## 7. Apply once and verify
Apply the reviewed plan once. Save actual EC2 ID, bucket and URL outside Git.
Wait for boot, compare EC2 Git HEAD with public main, check health, save a note,
read back the exact S3 object and retain its key/content. Report actual evidence.
Diagnose failures on this instance instead of creating another environment.

## 8. Change the app on the SAME server
Add general/work/personal category. Missing defaults general; invalid returns400.
Test locally, review, commit and push SAME public main. Verify target SHA, then
pull it with --ff-only on SAME EC2, install requirements and restart only notes-app.
No Terraform apply or new EC2/bucket. Prove original IDs unchanged, target code
runs, all category checks pass, and the earlier S3 object remains unchanged.

## 9. Document and cleanup
Finalize README and push source with no secrets/state/note data. Only at the end,
review known objects and the 12-resource destroy plan, then delete our test
resources. Preserve training host, existing StudentCeiling policy and repository.

## Lab permission and availability checks
Before initial apply, query t3.micro availability-zone offerings and set availability_zone explicitly. This lab denies GetBucketWebsite, so use the existing infra/bucket.sh through terraform_data for owned-bucket create/verify/delete rather than aws_s3_bucket advanced reads. Preserve the one bucket and restrict IAM exactly as above. The local HTML form must use a relative action so it works behind VS Code preview.
