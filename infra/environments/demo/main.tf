module "app" {
  source = "../../modules/ecs-fargate-app"

  aws_region          = var.aws_region
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  container_port      = var.container_port
  container_image     = var.container_image
  task_cpu            = var.task_cpu
  task_memory         = var.task_memory
  desired_count       = var.desired_count
  log_retention_days  = var.log_retention_days
}
