#----------------------------------------------------------------------------
# REQUIRED PARAMETERS: You must provide a value for each of these parameters.
#----------------------------------------------------------------------------

variable "region" {
  description = "AWS region"
  type        = string
}

variable "subnet_ids" {
  description = "A list of IDs for the subnets that the file system will be accessible from (up to two subnets can be provided)"
  type        = list(string)
}

variable "preferred_subnet_id" {
  description = "The ID for the subnet that the file system will be accessible from (only one subnet can be provided)"
  type        = string
}

variable "storage_capacity" {
  description = "Specifies the storage capacity (GiB) of the file system. Valid values are 1024 and 196608/524288"
  type        = number
  default     = 1024
}

#---------------------------------------------------------------
# OPTIONAL PARAMETERS: These parameters have resonable defaults.
#---------------------------------------------------------------

variable "environment" {
  description = "Environment i.e. dev, test, stage, prod"
  type        = string
  default     = "dev"
}

variable "throughput_capacity" {
  description = "Sets the throughput capacity (in MBps) for the file system. Valid values are 128, 256, 512, 1024, 2048, and 4096."
  type        = number
  default     = 128
}

variable "name_tag" {
  description = "Value for the name tag associated with the file system"
  type        = string
  default     = "My-File-System"
}

variable "kms_key_id" {
  description = "ARN for the KMS key to encrypt the file system at rest (defaults to an AWS managed KMS key)"
  type        = string
  default     = null
}

variable "security_group_ids" {
  description = "A list of IDs for the security groups that apply to the network interfaces created for file system access"
  type        = list(string)
  default     = null
}

variable "deployment_type" {
  description = "Specifies the file system deployment type, valid values are MULTI_AZ_1, MULTI_AZ_2, SINGLE_AZ_1, and SINGLE_AZ_2."
  type        = string
  default     = "SINGLE_AZ_1"
}

variable "automatic_backup_retention_days" {
  description = "Specifies the number of days to retain automatic backups. Valid values are 0 to 90."
  type        = number
  default     = 0
}

variable "ha_pairs" {
  description = "Specifies the number of HA pairs to create. Valid values are 1 to 12."
  type        = number
  default     = 1
}