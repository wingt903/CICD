output "approved_ami_parameter" {
  value       = aws_ssm_parameter.approved_ami.name
  description = "SSM path that stores the approved AMI for this environment"
}

output "app_data_volume_id" {
  value       = aws_ebs_volume.app_data.id
  description = "Mandatory secondary EBS volume ID for application data"
}

output "app_data_mount_config_parameter" {
  value       = aws_ssm_parameter.app_mount_config.name
  description = "SSM path that stores logical application mount configuration"
}

output "app_data_volume_parameter" {
  value       = aws_ssm_parameter.app_data_volume_id.name
  description = "SSM path that stores the attached application data EBS volume ID"
}

output "app_data_storage_contract" {
  value = {
    volume_id        = aws_ebs_volume.app_data.id
    mount_point      = var.app_mount_point
    filesystem_type  = var.app_filesystem_type
    filesystem_label = var.app_filesystem_label
    attached_to      = var.app_instance_id
  }
  description = "Terraform-owned storage contract for application data volume and mount metadata"
}
