# Git
.git
.gitignore

# Maven build output — rebuilt inside Docker
target/

# Local config with credentials
application-local.properties
application-aws.properties
.env

# Frontend — not part of Spring Boot image
frontend/

# Terraform — not needed in image
terraform/

# Lambda — not part of Spring Boot image
lambda/

# IDE files
.idea/
*.iml
.vscode/

# Docker files themselves
Dockerfile
.dockerignore