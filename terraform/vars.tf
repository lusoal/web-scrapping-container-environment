# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  description = "Name of cluster - used by Terratest for e2e test automation"
  type        = string
  default     = "web-scrapping-demo"
}

variable "aws_region" {
  type = string
}

variable "bucket_name" {
  default     = "bucket-web-srapping-app"
  description = "Define a unique name for your bucket"
}

variable "table_name" {
  default = "web-scrapping"
}

variable "registry_name" {
  default = "scrape-app"
}

variable "eip_config" {
  default = {
    enabled       = false
    elastic_ips   = 3
  }
}
