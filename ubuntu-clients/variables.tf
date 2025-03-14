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

variable "ubuntu_subnet_id" {
  description = "The subnet IDs to use for the Ubuntu client. Should be at least two for multi-AZ deployment"
  type        = list(string)
}


#---------------------------------------------------------------
# OPTIONAL PARAMETERS: These parameters have resonable defaults.
#---------------------------------------------------------------

variable "environment" {
  description = "Environment i.e. dev, test, stage, prod"
  type        = string
  default     = "dev"
}

variable "ubuntu_instance_type" {
  description = "The EC2 instance type for the Ubuntu client"
  type        = string
  default     = "t3.small"
}

variable "ubuntu_ami_id" {
  description = "The ID of the AWS EC2 AMI to use (if null the latest Ubuntu TLS is selected)"
  type        = string
  default     = null
}

variable "ssh_allowed_cidr" {
  description = "The allowed CIDR IP range for SSH access to the OPS instance"
  type        = string
  default     = null
}

variable "ubuntu_name" {
  description = "The Name tag to use for the Ubuntu client"
  type        = string
  default     = "Ubuntu-Client"
}

variable "nfs_server" {
  description = "The NFS server IP address or hostname"
  type        = string
  default     = null
}

variable "nfs_volume_path" {
  description = "The NFS volume path"
  type        = string
  default     = null
}