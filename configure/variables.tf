#----------------------------------------------------------------------------
# REQUIRED PARAMETERS: You must provide a value for each of these parameters.
#----------------------------------------------------------------------------

variable "region" {
  description = "AWS region"
  type        = string
}

variable "key_name" {
  description = "The name of the key pair that allows to securely connect to the instance after launch"
  type        = string
}

variable "subnet_id" {
  description = "The  ID of a subnet in the VPC where the OPS instance will be deployed"
  type        = string
}

variable "file_system_id" {
  description = "Identifier of the FSx file system"
  type        = string
}

#---------------------------------------------------------------
# OPTIONAL PARAMETERS: These parameters have resonable defaults.
#---------------------------------------------------------------

variable "environment" {
  description = "Environment i.e. dev, test, stage, prod"
  type        = string
  default     = "dev"
}

variable "ops_instance_type" {
  description = "The EC2 instance type for the OPS instance"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "The ID of the AWS EC2 AMI to use (if null the latest Amazon Linux 2 is selected)"
  type        = string
  default     = null
}

variable "ssh_allowed_cidr" {
  description = "The allowed CIDR IP range for SSH access to the OPS instance"
  type        = string
  default     = null
}

variable "ops_name" {
  description = "The computer name of the OPS instance"
  type        = string
  default     = "ops01"
}
