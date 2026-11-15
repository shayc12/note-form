# Note Form — Codex workshop

One public GitHub repository, one application EC2 and one private S3 bucket.
The training Ubuntu server is the separate workspace for Codex, Git and Terraform.

## Run locally
Use Python 3, create `.venv`, then install `requirements.txt` inside it.
Run `.venv/bin/gunicorn --workers 1 --bind 0.0.0.0:8080 app:app`.
With S3_BUCKET unset, notes are saved locally under notes/.
Check GET /health, POST /notes, and the exact JSON file returned by the save.

## GitHub before deployment
Use this SAME public repository and main branch for the whole day.
Review staged source, commit and push; compare local HEAD with remote main.
Verify an anonymous clone without saved GitHub credentials contains the tested
S3-capable app, boto3 requirement, Terraform and scripts BEFORE first EC2 apply.
Never publish credentials, private keys, real tfvars, state, saved plans or notes.

## Create AWS once
From infra/, Codex runs init, fmt, validate and saves a plan for review before apply.
Inputs: public repo_url, unique lab_id and jblabs-* bucket_name, actual existing
StudentCeiling ARN, local SSH public-key path, and approved app/SSH source CIDRs.
Store real values only in ignored training.auto.tfvars. Keep private SSH keys
outside the repository. Use temporary learner AWS environment credentials only.
Use us-east-1 and t3.micro. Verify the prefilled official Canonical Ubuntu 22.04
x86_64 AMI in the class account before launch.

Terraform owns 12 resources: VPC, public subnet, internet gateway, route table and
association; private S3 bucket; EC2, Security Group and registered public key;
student-* IAM role, inline policy and instance profile. Attach StudentCeiling
to the role at creation. The IAM policy grants only s3:PutObject on this bucket's
notes/* objects. No bucket policy, lifecycle or public ACL changes.

At first boot EC2 installs Git/Python/venv, clones public main over HTTPS without
GitHub credentials, installs requirements and starts notes-app on port 8080.
Runtime S3 access uses the EC2 role, not learner keys. Source is not embedded in TF.
Record actual instance_id, bucket_name and app_url outside Git as the baseline.
Compare the EC2 checkout commit with public GitHub main. Save a note and retrieve
its exact S3 object via the learner CLI; health alone does not prove S3 access.

## Update the SAME EC2
Make and test the category change on the training host. Review, commit and push
SAME public main; verify the target SHA. Through the existing restricted SSH route,
Codex runs on the existing app EC2:
`sudo bash /opt/notes-app/scripts/update-app.sh <reviewed-full-main-sha>`
The script performs a fast-forward pull, verifies the SHA, installs dependencies
and restarts only notes-app. It stops on local source changes or branch divergence.
Do not run Terraform apply, rerun first-boot setup or change infrastructure inputs
for this app-only update. Compare actual EC2 ID/bucket to baseline, verify new
work/default/invalid-category behavior and read an earlier S3 object unchanged.

## Cleanup only at the end
Push wanted source first. Review and remove only known test note objects.
Review/apply a destroy plan for the 12 owned resources. Preserve the training
host, platform StudentCeiling policy, this source repository and unrelated data.
Verify original resources are gone and Terraform state is empty.

See docs/workshop-prompts.md for the exact sequence. Actual test evidence is
kept on the training host outside Git, with PASS / FAIL / NOT RUN statuses.
