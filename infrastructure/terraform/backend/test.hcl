bucket         = "cicd-terraform-state-test"
key            = "aws-migration-cicd/terraform.tfstate"
region         = "ap-southeast-1"
dynamodb_table = "cicd-terraform-lock-test"
encrypt        = true
