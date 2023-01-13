#!/bin/bash
aws s3 rm s3://'YOUR_BUCKET_NAME_HERE'/ --recursive --include "*"


aws ecr batch-delete-image --region 'YOUR_REGION_HERE' \
    --repository-name 'YOUR_ECR_NAME_HERE' \
    --image-ids "$(aws ecr list-images --region 'YOUR_REGION_HERE' --repository-name 'YOUR_ECR_NAME_HERE' --query 'imageIds[*]' --output json
)" || true
