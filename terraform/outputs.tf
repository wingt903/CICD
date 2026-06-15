output "approved_ami_parameter" {
  value       = aws_ssm_parameter.approved_ami.name
  description = "SSM path that stores the approved AMI for this environment"
}
