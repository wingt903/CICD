locals {
  common_tags = {
    project     = "aws-migration-cicd"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/cicd/${var.environment}/application"
  retention_in_days = var.environment == "prod" ? 90 : 30
  tags              = local.common_tags
}

resource "aws_sns_topic" "alerts" {
  name = "cicd-${var.environment}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_ssm_parameter" "approved_ami" {
  name  = "/${var.environment}/approved/ami/base"
  type  = "String"
  value = "ami-PLACEHOLDER"
  tags  = local.common_tags
}

output "approved_ami_parameter" {
  value       = aws_ssm_parameter.approved_ami.name
  description = "SSM path that stores the approved AMI for this environment"
}
