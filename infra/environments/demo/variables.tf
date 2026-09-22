variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag all resources."
  type        = string
  default     = "urlshort"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "container_port" {
  description = "Port the app listens on inside the container."
  type        = number
  default     = 8000
}

variable "container_image" {
  description = <<-EOT
    Full image URI including tag, e.g.
    123456789012.dkr.ecr.ap-southeast-1.amazonaws.com/urlshort:latest

    Left with no default on purpose: the ECR repo must exist and the image
    must be pushed before this has a real value. See README.md for the
    two-step apply.
  EOT
  type = string
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MB."
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of tasks to run. Kept at 1 — this is a demo, not a scaled service."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch log retention. Short on purpose since this is a temporary demo."
  type        = number
  default     = 3
}
