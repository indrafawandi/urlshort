output "app_url" {
  value = module.app.app_url
}

output "ecr_repository_url" {
  value = module.app.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.app.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.app.ecs_service_name
}

output "vpc_id" {
  value = module.app.vpc_id
}
