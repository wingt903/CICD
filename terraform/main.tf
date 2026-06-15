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
  value = var.approved_ami_id
  tags  = local.common_tags
}

resource "aws_ebs_volume" "app_data" {
  availability_zone = var.app_volume_availability_zone
  size              = var.app_volume_size_gb
  type              = var.app_volume_type
  encrypted         = true
  iops              = contains(["gp3", "io1", "io2"], var.app_volume_type) ? var.app_volume_iops : null
  throughput        = var.app_volume_type == "gp3" ? var.app_volume_throughput : null

  tags = merge(local.common_tags, {
    Name    = "cicd-${var.environment}-app-data"
    purpose = "application-data"
    mount   = var.app_mount_point
  })
}

resource "aws_volume_attachment" "app_data" {
  device_name = var.app_volume_device_name
  volume_id   = aws_ebs_volume.app_data.id
  instance_id = var.app_instance_id
}

resource "aws_ssm_parameter" "app_mount_config" {
  name = "/${var.environment}/app/storage/mount-config"
  type = "String"
  value = jsonencode({
    mount_point      = var.app_mount_point
    filesystem_type  = var.app_filesystem_type
    filesystem_label = var.app_filesystem_label
  })
  tags = local.common_tags
}

resource "aws_ssm_parameter" "app_data_volume_id" {
  name  = "/${var.environment}/app/storage/app-data-volume-id"
  type  = "String"
  value = aws_ebs_volume.app_data.id
  tags  = local.common_tags
}
