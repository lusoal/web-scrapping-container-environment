# output "vpc_private_subnet_cidr" {
#   description = "VPC private subnet CIDR"
#   value       = module.vpc.private_subnets_cidr_blocks
# }

output "vpc_public_subnet_ids" {
  description = "VPC public subnet IDs"
  value       = module.vpc.public_subnets
}

output "vpc_cidr" {
  description = "VPC CIDR"
  value       = module.vpc.vpc_cidr_block
}

output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks_blueprints.eks_cluster_id
}

output "dynamo_table_name" {
  value       = aws_dynamodb_table.basic-dynamodb-table.name
  description = "DynamoDB table name"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.bucket.bucket
  description = "S3 bucket name to use in the demonstration"
}

output "ecr_registry_name" {
  value       = aws_ecr_repository.ecr-registry.name
  description = "ECR registry name to use on push"
}

output "ecs_security_group_id" {
  value       = aws_security_group.ecs_task_sg.id
  description = "SG ID to use in ECS task definition"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.ecs-cluster-scrapping.name
  description = "ECS cluster name"
}

output "task_definition_family" {
  value       = "${aws_ecs_task_definition.web-scrapping-app-task.family}:1"
  description = "Family to use in docker compose application"
}

output "ecr_image_uri" {
  value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.registry_name}:latest"
}

output "identity-oidc-issuer" {
  value = split("https://", data.aws_eks_cluster.example.identity[0].oidc[0].issuer)[1]
}
# output "eks_managed_nodegroups" {
#   description = "EKS managed node groups"
#   value       = module.eks_blueprints.managed_node_groups
# }

# output "eks_managed_nodegroup_ids" {
#   description = "EKS managed node group ids"
#   value       = module.eks_blueprints.managed_node_groups_id
# }

# output "eks_managed_nodegroup_arns" {
#   description = "EKS managed node group arns"
#   value       = module.eks_blueprints.managed_node_group_arn
# }

# output "eks_managed_nodegroup_role_name" {
#   description = "EKS managed node group role name"
#   value       = module.eks_blueprints.managed_node_group_iam_role_names
# }

# output "eks_managed_nodegroup_status" {
#   description = "EKS managed node group status"
#   value       = module.eks_blueprints.managed_node_groups_status
# }

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.eks_blueprints.configure_kubectl
}

# # Region used for Terratest
# output "region" {
#   value       = local.region
#   description = "AWS region"
# }