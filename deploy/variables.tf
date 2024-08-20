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
  default     = 384
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

variable "security_group_id" {
  description = "The ID for the security group that applies to the specified network interfaces created for file system access"
  type        = string
  default     = null
}

variable "deployment_type" {
  description = "Specifies the file system deployment type, valid values are MULTI_AZ_1, MULTI_AZ_2, SINGLE_AZ_1, and SINGLE_AZ_2."
  type        = string
  default     = "SINGLE_AZ_1"
}

