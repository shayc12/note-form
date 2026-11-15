#!/bin/bash
set -euo pipefail
: "${BUCKET_NAME:?Missing bucket name}"
: "${BUCKET_REGION:?Missing bucket region}"
[[ "$BUCKET_NAME" == jblabs-* ]] || exit 2
[[ "$BUCKET_REGION" == us-east-1 ]] || exit 2
owner=$(aws sts get-caller-identity --query Account --output text --no-cli-pager)
err=$(mktemp)
trap 'rm -f "$err"' EXIT
if aws s3api head-bucket --bucket "$BUCKET_NAME" --expected-bucket-owner "$owner" --region "$BUCKET_REGION" --no-cli-pager > /dev/null 2>"$err"; then
  exists=yes
elif grep -Eq '404|Not Found|NotFound|NoSuchBucket' "$err"; then
  exists=no
else
  cat "$err" >&2
  exit 1
fi
case "${1:?Choose create or delete}" in
  create)
    if [[ "$exists" == no ]]; then
      aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$BUCKET_REGION" --no-cli-pager
    fi
    aws s3api head-bucket --bucket "$BUCKET_NAME" --expected-bucket-owner "$owner" --region "$BUCKET_REGION" --no-cli-pager
    echo "Verified one owned bucket: $BUCKET_NAME"
    ;;
  delete)
    if [[ "$exists" == yes ]]; then
      # Refuses a nonempty bucket. Review/remove only workshop objects first.
      aws s3api delete-bucket --bucket "$BUCKET_NAME" --expected-bucket-owner "$owner" --region "$BUCKET_REGION" --no-cli-pager
    fi
    echo "Bucket deletion request completed: $BUCKET_NAME"
    ;;
  *) exit 2 ;;
esac
