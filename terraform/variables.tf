# Copyright 2026 The MathWorks, Inc.

# ------------------------
# Parameter Equivalents
# ------------------------

variable "aws_region" {
  description = "AWS region to deploy MATLAB Parallel Server.  Supported regions: eu-west-1, us-east-1, us-west-2, ap-northeast-1. For other regions, copy the MATLAB snapshot to your desired region."
  type        = string

  validation {
    condition     = contains(["eu-west-1", "us-east-1", "us-west-2", "ap-northeast-1"], var.aws_region)
    error_message = "Region must be one of: eu-west-1, us-east-1, us-west-2, ap-northeast-1."
  }
}

variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "default"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = ""
}

variable "matlab_release" {
  description = "The matlab release to deploy"
  type        = string
  default     = "R2025b"

  validation {
    condition     = contains(["R2025b", "R2025a", "R2024b"], var.matlab_release)
    error_message = "Release must be one of R2025b, R2025a, R2024b."
  }
}

locals {
  computed_cluster_name = var.cluster_name != "" ? var.cluster_name : "matlab-parallel-server-${random_uuid.stackid.result}"
}

variable "job_manager_instance_type" {
  description = "EC2 instance type for job manager"
  type        = string
  default     = "t3.large"
}

variable "node_instance_type" {
  description = "EC2 instance type for the worker node group"
  type        = string
  default     = "m5.xlarge"
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 0
  validation {
    condition     = var.desired_size >= 0
    error_message = "desired_size must be 0 or greater."
  }
}

variable "max_worker_nodes" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
  validation {
    condition     = var.max_worker_nodes >= 0
    error_message = "max_worker_nodes must be 0 or greater."
  }
}

variable "min_worker_nodes" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 0
  validation {
    condition     = var.min_worker_nodes >= 0
    error_message = "min_worker_nodes must be 0 or greater."
  }
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
  type        = set(string)
  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "Must be the IDs of existing subnets within the chosen VPC."
  }
}

variable "additional_security_groups" {
  description = "The IDs of additional security groups to attach to nodes"
  type        = set(string)
  default     = []
}

variable "enable_efs_backup" {
  description = "Enable automatic backups for EFS filesystem"
  type        = bool
  default     = false
}

variable "public_access_cidr_blocks" {
  description = "The CIDR blocks to allow access to the control plane. This field should be formatted as <ip_address>/<mask>. E.g. [\"11.22.33.44/32\",\"44.55.66.77/32\"]"
  type        = set(string)

  validation {
    condition     = !contains(var.public_access_cidr_blocks, "0.0.0.0/0")
    error_message = "Public access from 0.0.0.0/0 is not allowed. Please specify restricted CIDR blocks for EKS control plane access."
  }

  validation {
    condition = alltrue([
      for cidr in var.public_access_cidr_blocks :
      can(cidrhost(cidr, 0))
    ])
    error_message = "All values must be valid CIDR blocks (e.g., 10.0.0.0/8, 192.168.1.0/24)."
  }
}

variable "node_label_key" {
  description = "Kubernetes node label key used to distinguish Job Manager and Worker node groups"
  type        = string
  default     = "mjs-node-type"
}

variable "job_manager_node_label_value" {
  description = "Node label value applied to the Job Manager node group"
  type        = string
  default     = "JobManagerNodeGroup"
}

variable "worker_node_label_value" {
  description = "Node label value applied to the Worker node group"
  type        = string
  default     = "WorkerNodeGroup"
}

variable "worker_ebs_snapshot_id" {
  description = "Optional snapshot ID for the worker data volume. If empty, falls back to the regional snapshot map."
  type        = string
  default     = ""
}

variable "system_node_instance_type" {
  description = "EC2 instance type for the untainted system node group (hosts kube-system and managed add-ons)"
  type        = string
  default     = "t3.medium"
}

variable "worker_memory_gib" {
  description = "Memory request/limit (in GiB) per MATLAB worker pod. Must be at least 4 GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.worker_memory_gib >= 4
    error_message = "worker_memory_gib must be at least 4 GiB."
  }
}
