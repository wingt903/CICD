bucket         = "cicd-terraform-state-dev"
key            = "aws-migration-cicd/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "cicd-terraform-lock-dev"
encrypt        = true
