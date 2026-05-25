variable "aws_region" {
  type        = string
  description = "AWS region for environment deployment"
  default     = "ap-southeast-1"
}

variable "environment" {
  type        = string
  description = "Environment name: dev, test, or prod"
}

variable "alarm_email" {
  type        = string
  description = "Notification endpoint for environment alarms"
}

variable "approved_ami_id" {
  type        = string
  description = "Approved AMI ID to publish into environment SSM parameter"
  default     = "ami-00000000000000000"
}
