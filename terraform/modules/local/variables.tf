# Copyright 2026 The MathWorks, Inc.

# ------------------------
# Parameter Equivalents
# ------------------------

variable "cluster_name" {
  description = "The name of an existing EKS cluster"
  type        = string
}

variable "matlab_release" {
  description = "The MATLAB release of the cluster"
  type        = string
}

variable "efs_filesystem_id" {
  description = "EFS filesystem ID created for this deployment"
  type        = string
}

variable "aws_region" {
  description = "The AWS region of the resources"
  type        = string
}

variable "load_balancer_source_ranges" {
  description = "The CIDR source range for which the load balancer allows access"
  type        = list(string)
}

variable "resource_suffix" {
  description = "ID to append to resources"
  type        = string
}

variable "matlab_path" {
  description = "Path inside the worker nodes to mount MATLAB (e.g., /opt/matlab)"
  type        = string
}

variable "node_label_key" {
  description = "Kubernetes node label key used by EKS node groups"
  type        = string
}

variable "job_manager_node_label_value" {
  description = "Node label value used for Job Manager nodes"
  type        = string
}

variable "worker_node_label_value" {
  description = "Node label value used for Worker nodes"
  type        = string
}

variable "mjs_max_workers" {
  description = "Computed maxWorkers passed from root module."
  type        = number
}
variable "worker_memory_gib" {
  description = "Memory (GiB) to allocate to each MATLAB worker pod. Used for both request and limit."
  type        = number
}