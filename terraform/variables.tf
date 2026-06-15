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
  description = "Bootstrap AMI ID placeholder for SSM parameter initialization; replace with a real approved AMI before production rollout"
  default     = "ami-00000000000000000"
}

variable "app_instance_id" {
  type        = string
  description = "EC2 instance ID for application host that receives the mandatory secondary data volume"
  validation {
    condition     = can(regex("^i-([0-9a-f]{8}|[0-9a-f]{17})$", var.app_instance_id))
    error_message = "app_instance_id must be a valid EC2 instance ID format (for example: i-0123456789abcdef0)."
  }
}

variable "app_volume_availability_zone" {
  type        = string
  description = "Availability Zone for the application secondary EBS data volume"
}

variable "app_volume_size_gb" {
  type        = number
  description = "Size in GiB for the mandatory secondary application data volume"
  default     = 100
}

variable "app_volume_type" {
  type        = string
  description = "EBS volume type for the mandatory application data volume"
  default     = "gp3"
  validation {
    condition     = contains(["gp3", "io1", "io2"], var.app_volume_type)
    error_message = "app_volume_type must be one of: gp3, io1, io2."
  }
}

variable "app_volume_iops" {
  type        = number
  description = "Provisioned IOPS for the application data volume when supported by the selected volume type"
  default     = 3000
  validation {
    condition = (
      (var.app_volume_type == "gp3" && var.app_volume_iops >= 3000) ||
      (contains(["io1", "io2"], var.app_volume_type) && var.app_volume_iops >= 100)
    )
    error_message = "app_volume_iops must be >=3000 for gp3 and >=100 for io1/io2 volume types."
  }
}

variable "app_volume_throughput" {
  type        = number
  description = "Provisioned throughput (MiB/s) for the application data volume when supported by the selected volume type"
  default     = 125
  validation {
    condition     = var.app_volume_type != "gp3" || (var.app_volume_throughput >= 125 && var.app_volume_throughput <= 1000)
    error_message = "app_volume_throughput must be between 125 and 1000 MiB/s for gp3 volume type."
  }
}

variable "app_volume_device_name" {
  type        = string
  description = "Requested Linux device name for EBS attachment (used only as an attachment hint)"
  default     = "/dev/sdf"
}

variable "app_mount_point" {
  type        = string
  description = "Logical mount point for application data"
  default     = "/webserver"
}

variable "app_filesystem_type" {
  type        = string
  description = "Filesystem type for the application data volume"
  default     = "xfs"
}

variable "app_filesystem_label" {
  type        = string
  description = "Filesystem label used by configuration management to mount application data"
  default     = "WEBAPPDATA"
}
