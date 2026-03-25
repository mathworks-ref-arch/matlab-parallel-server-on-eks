# Copyright 2026 The MathWorks, Inc.

# ------------------------
# Parameter Equivalents
# ------------------------

variable "cluster_name" {
  description = "The name of an existing EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of an existing VPC in which to deploy this stack"
  type        = string
  validation {
    condition     = length(var.vpc_id) > 0
    error_message = "Must be the ID of an existing VPC."
  }
}

variable "subnet_ids" {
  description = "IDs of existing subnets. To access the instance from anywhere, ensure that your subnet auto-assigns public IP addresses and is connected to the internet."
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "Must be the IDs of existing subnets within the chosen VPC."
  }
}

variable "resource_suffix" {
  description = "ID to append to resources"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for EFS encryption (uses AWS managed key if not specified)"
  type        = string
  default     = ""
}

variable "enable_backup" {
  description = "Enable automatic backups for EFS filesystem"
  type        = bool
  default     = false
}

variable "cluster_security_group_id" {
  description = "EKS cluster security group ID to allow EFS access"
  type        = string
}
