resource "random_string" "random" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "bucket" {
  bucket = "${var.bucket_name}-${random_string.random.result}"

  tags = {
    Name        = "${var.bucket_name}-${random_string.random.result}"
    Environment = "Dev"
  }
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name           = var.table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "IP"
  range_key      = "SCRAPE"

  attribute {
    name = "IP"
    type = "S"
  }

  attribute {
    name = "SCRAPE"
    type = "S"
  }

  tags = {
    Name        = var.table_name
    Environment = "Dev"
  }
}


resource "aws_ecr_repository" "ecr-registry" {
  name                 = var.registry_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_security_group" "ecs_task_sg" {
  name        = "ecs_task_sg"
  description = "Allow egress traffic only for ECS task"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "ecs_task_sg"
    Environment = "Dev"
  }
}

resource "aws_ecs_cluster" "ecs-cluster-scrapping" {
  name = "${var.cluster_name}-ecs"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task Definition Params
data "aws_caller_identity" "current" {}



resource "aws_iam_role" "ecs_execution_role" {
  name                = "ecsTaskExecutionRole"
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "Dev"
  }
}

resource "aws_iam_role" "task_role" {
  name                = "web-scrapping-ecs-task-role"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"] # Change to Dynamo DB and S3 Only
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "Dev"
  }
}

resource "aws_ecs_task_definition" "web-scrapping-app-task" {
  family                   = "web-scrapping-app"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task_role.arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name      = "web-scrapping"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.registry_name}:latest"
      essential = true
    }
  ])

  depends_on = [aws_iam_role.ecs_execution_role, aws_iam_role.task_role]
}

# Karpenter Role for provisioner

resource "aws_iam_role" "karpenter_role_provisioner" {
  name = "karpenter-node-role"
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess", "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly", "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"]
  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EKSWorkerAssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = "Dev"
  }
}

resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "karpenter-node-role"
  role = aws_iam_role.karpenter_role_provisioner.name
}

## EKS Scrape App 

data "aws_eks_cluster" "example" {
  name = local.name
  depends_on = [
    module.eks_blueprints
  ]
}

module "iam_eks_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "scrape-sa-role"

  oidc_providers = {
    one = {
      provider_arn               = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${split("https://", data.aws_eks_cluster.example.identity[0].oidc[0].issuer)[1]}"
      namespace_service_accounts = ["default:scrape-sa"]
    }
  }
}


resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = module.iam_eks_role.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "null_resource" "export_eks_config" {
  provisioner "local-exec" {
    command = module.eks_blueprints.configure_kubectl
  }
}


resource "null_resource" "exec_sa" {
  provisioner "local-exec" {
    command = "kubectl create sa scrape-sa -ndefault && kubectl annotate sa scrape-sa eks.amazonaws.com/role-arn=${module.iam_eks_role.iam_role_arn} -ndefault"
  }

  depends_on = [
    null_resource.export_eks_config
  ]
}

resource "aws_eip" "elastic_ips" {
  count = var.eip_config.enabled ? var.eip_config.elastic_ips : 0
  vpc = true
}
