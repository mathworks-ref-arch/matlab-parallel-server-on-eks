# Copyright 2026 The MathWorks, Inc.

# ------------------------
# Variables
# ------------------------

# ------------------------
# Required variables
# ------------------------

# The MATLAB release to deploy. Allowed values: "R2026a", "R2025b", "R2025a", "R2024b"
matlab_release = "R2026a"

# AWS region to deploy MATLAB Parallel Server.
# Supported regions: "eu-west-1", "us-east-1", "us-west-2", "ap-northeast-1"
aws_region = "us-east-1"

aws_profile = "default"

# ID of an existing VPC in which to deploy this stack.
# Must be the ID of an existing VPC.
vpc_id = "<EXISTING_VPC_ID>"

# IDs of existing subnets within the chosen VPC.
# Example: ["subnet-abc123", "subnet-def456"]
subnet_ids = ["<EXISTING_SUBNET_1>", "<EXISTING_SUBNET_2>"]

# The CIDR blocks to allow access to the control plane.
# Format each as "<ip_address>/<mask>", e.g., ["11.22.33.44/32","44.55.66.77/32"]
public_access_cidr_blocks = ["<CIDR_1>", "<CIDR_2>", "<CIDR_3>"]

# ------------------------
# Optional variables
# ------------------------

# The name of the EKS cluster (leave as "" to auto-generate a name)
cluster_name = ""

# EC2 instance type for job manager
job_manager_instance_type = "t3.large"

# EC2 instance type for the worker node group
node_instance_type = "m5.xlarge"

# System node group instance type.
# This node group is dedicated to running cluster-level system pods such as Cluster autoscaler, EFS CSI driver/controller, core Kubernetes services (e.g., CoreDNS, kube-proxy, aws-node) and other infrastructure or add-on components required for cluster operations.
# Application workloads will not be scheduled here.
system_node_instance_type = "t3.medium"

# Desired initial number of worker nodes (default: 0)
desired_size = 0
# Maximum number of worker nodes (default: 4)
max_worker_nodes = 4

# Minimum number of worker nodes (default: 0)
min_worker_nodes = 0

# Memory request for each worker pod.
worker_memory_gib = 8

# The IDs of additional security groups to attach to nodes (default: [])
additional_security_groups = []

# Enable automatic backups for EFS filesystem (default: false)
enable_efs_backup = false