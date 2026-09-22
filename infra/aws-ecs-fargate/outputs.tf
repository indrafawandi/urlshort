output "app_url" {
  description = "Public URL of the deployed app."
  value       = "http://${aws_lb.this.dns_name}"
}

output "ecr_repository_url" {
  description = "Push images here (docker tag/push), then reference in container_image."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "vpc_id" {
  value = aws_vpc.this.id
}
