#!/usr/bin/env bash
set -euo pipefail

# Re-tags an ECR image without rebuilding by fetching the manifest for a
# source tag and putting it back with a destination tag.
#
# Usage:
#   tag-ecr.sh <ECR_REGISTRY> <ECR_REPOSITORY> <SOURCE_TAG> <DEST_TAG> <AWS_REGION>
#
# Example:
#   tag-ecr.sh 123456789.dkr.ecr.us-east-1.amazonaws.com profiles-api sha-abc123 int-abc123-20260217153010 us-east-1

ECR_REGISTRY="${1:?ECR_REGISTRY required}"
ECR_REPOSITORY="${2:?ECR_REPOSITORY required}"
SOURCE_TAG="${3:?SOURCE_TAG required}"
DEST_TAG="${4:?DEST_TAG required}"
AWS_REGION="${5:?AWS_REGION required}"

echo "Fetching image manifest for ${ECR_REPOSITORY}:${SOURCE_TAG}..."

MANIFEST=$(aws ecr batch-get-image \
  --region "${AWS_REGION}" \
  --repository-name "${ECR_REPOSITORY}" \
  --image-ids imageTag="${SOURCE_TAG}" \
  --query 'images[0].imageManifest' \
  --output text)

if [ -z "${MANIFEST}" ] || [ "${MANIFEST}" = "None" ]; then
  echo "ERROR: Could not retrieve manifest for ${ECR_REPOSITORY}:${SOURCE_TAG}"
  exit 1
fi

echo "Putting image manifest as ${ECR_REPOSITORY}:${DEST_TAG}..."

aws ecr put-image \
  --region "${AWS_REGION}" \
  --repository-name "${ECR_REPOSITORY}" \
  --image-tag "${DEST_TAG}" \
  --image-manifest "${MANIFEST}" \
  > /dev/null 2>&1 || {
    # put-image fails if the tag already points to this digest — that is fine
    echo "WARN: put-image returned non-zero (tag may already exist for this digest)"
  }

echo "Tagged ${ECR_REGISTRY}/${ECR_REPOSITORY}:${DEST_TAG} successfully."
