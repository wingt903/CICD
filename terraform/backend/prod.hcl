bucket         = "cicd-terraform-state-prod"
key            = "aws-migration-cicd/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "cicd-terraform-lock-prod"
encrypt        = true
