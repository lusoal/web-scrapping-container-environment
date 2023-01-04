#!/bin/bash

echo What is your AWS Account ID?

read AWS_ACCOUNT_ID

echo What is the region that you deployed the solution?

read AWS_REGION

echo $AWS_REGION $AWS_ACCOUNT_ID

REGISTRY_ID=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/scrape-app

echo "Login into AWS ECR Registry"

aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $REGISTRY_ID

echo "Building scrape application Image"

cd scrape_app

docker buildx build --push --tag $REGISTRY_ID:latest -o type=image --platform=linux/amd64 .

echo "Create spot service linked role"

aws iam create-service-linked-role --aws-service-name spot.amazonaws.com
