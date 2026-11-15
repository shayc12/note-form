# Live end-to-end verification

Verified from the Ubuntu training host against the public GitHub repository and a real AWS lab account.

| Check | Result |
|---|---|
| Python venv, port 8080, health and exact local JSON save | PASS |
| Invalid empty input | PASS: HTTP 400 |
| Real Git push and anonymous public clone | PASS |
| VS Code browser-preview form submission | PASS after relative-action fix |
| Official Ubuntu x86_64 AMI availability | PASS |
| Supported t3.micro availability zone | PASS: queried before successful launch |
| Full bounded IAM role, inline write policy and profile | PASS |
| EC2 first-boot clone of public GitHub and matching commit | PASS |
| Live EC2 form to S3 and exact object read-back | PASS |
| Category feature unit/API tests | PASS: 8 tests; mocked S3 distinguished from live checks |
| Bash health loop and Python JSON loop | PASS |
| Git pull and service restart on the SAME EC2 | PASS |
| SAME instance ID, bucket, URL and earlier note | PASS |
| Work, missing-category general and invalid-category 400 | PASS in live AWS |
| Read-only Terraform plan after app update | PASS: zero changes |
| Secrets/private keys/state absent from Git history | PASS |
| Final 12-resource destroy plan | PASS: plan reviewed only |
| Actual resource deletion | NOT RUN: owner requested keeping AWS for demonstration |

## Corrections discovered during the real run

1. The form needs a relative action to work through the VS Code preview prefix.
2. The restricted account denies S3 GetBucketWebsite reads made by the standard
   bucket resource. The Terraform-owned bucket lifecycle therefore uses the small
   infra/bucket.sh CLI helper with ownership/existence checks and no expanded
   permissions. Native automatic S3 drift detection is replaced by explicit CLI
   verification and the live save/read-back test.
3. An automatically selected AZ did not offer t3.micro. Codex now checks offerings
   and supplies availability_zone explicitly before first EC2 creation.
4. Learner AWS credentials expired during the run and were refreshed in the same
   terminal. The deployed app kept working via its own EC2 IAM role.

Exactly one application EC2 and one bucket were used. Before any EC2 existed,
its unused subnet was moved to a supported AZ. The existing bucket was preserved
when correcting the permission mismatch. No second EC2 or second bucket was created.

Detailed IDs, note keys and evidence are retained outside Git on the training host.
No cloud credentials, private keys, state or real training variables are published.
