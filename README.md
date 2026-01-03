# Capstone Terraform Infrastructure

Multi-environment Azure infrastructure as code for Gopal's capstone project.

## Structure

- `bootstrap/` - Terraform state storage setup
- `modules/` - Reusable Terraform modules
- `envs/` - Environment-specific configurations (dev, qa, prod)
- `pipelines/` - Azure DevOps CI/CD pipelines

## Getting Started

1. Bootstrap Terraform state storage:
```bash
cd bootstrap
terraform init
terraform apply
```

2. Deploy environments:
```bash
cd envs/dev
terraform init
terraform apply
```
