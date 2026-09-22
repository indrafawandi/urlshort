resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Lets `terraform destroy` remove the repo even if images are still in
  # it. Without this, destroy fails with "repository not empty" and you
  # have to manually delete images first — an easy thing to forget on a
  # demo teardown.
  force_delete = true

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# Keep the repo from accumulating untagged layers across rebuilds during
# iteration. Tagged images (what the ECS service actually uses) are
# untouched.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after 1 day"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 1
      }
      action = { type = "expire" }
    }]
  })
}
