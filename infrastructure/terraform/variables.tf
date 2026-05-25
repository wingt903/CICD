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
  default     = "ops@example.com"
}
