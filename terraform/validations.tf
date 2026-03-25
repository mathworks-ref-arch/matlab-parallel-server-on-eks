# Copyright 2026 The MathWorks, Inc.

###############################################
# Subnet existence validation
###############################################
data "aws_subnet" "validate" {
  for_each = var.subnet_ids
  id       = each.value
}

locals {

  # 1. Subnet count
  validation_subnet_count_ok = length(var.subnet_ids) >= 2

  # 2. Subnet syntax + VPC membership
  validation_subnet_validity = {
    for sn, subnet in data.aws_subnet.validate :
    sn => (length(trimspace(sn)) > 0 && can(regex("^subnet-[0-9a-f]{8,17}$", sn)) && subnet.vpc_id == var.vpc_id)
  }

  validation_all_subnets_valid = alltrue(values(local.validation_subnet_validity))

  # 3. Snapshot validation
  validation_snapshot_exists = contains(keys(local.snapshot_map[data.aws_region.current.region]), var.matlab_release)

  # 4. Node label validation
  validation_node_label_key_ok = trimspace(var.node_label_key) != ""

  # 5. Autoscaling consistency
  validation_maxnodes_consistent = (var.max_worker_nodes > 0 || local.computed_mjs_max_workers == 0)

  # 6. Memory validation helpers
  validation_instance_mem_total           = try(data.aws_ec2_instance_type.worker.memory_size, 0)
  validation_worker_mem_request_mib       = var.worker_memory_gib * 1024
  validation_min_allocatable_required_mib = local.validation_worker_mem_request_mib + 1024
  validation_instance_allocatable_mib     = floor(local.validation_instance_mem_total * 0.90)

  # 7. Final memory feasibility check (ON ONE LINE)
  validation_memory_ok = local.validation_instance_allocatable_mib >= local.validation_min_allocatable_required_mib
}

resource "null_resource" "extra_validation" {

  triggers = {
    always = timestamp()
  }

  lifecycle {

    precondition {
      condition     = local.validation_subnet_count_ok
      error_message = "At least two subnets are required."
    }

    precondition {
      condition     = local.validation_all_subnets_valid
      error_message = "Invalid subnet: must be non-empty, match AWS syntax, exist, and belong to the VPC."
    }

    precondition {
      condition     = local.validation_snapshot_exists
      error_message = "Snapshot mapping missing for matlab_release or region."
    }

    precondition {
      condition     = local.validation_node_label_key_ok
      error_message = "node_label_key must be a non-empty string."
    }

    precondition {
      condition     = local.validation_memory_ok
      error_message = "Worker memory exceeds allocatable memory for this EC2 instance type."
    }

    precondition {
      condition     = local.validation_maxnodes_consistent
      error_message = "Invalid autoscaling: max_worker_nodes=0 but computed workers > 0."
    }
  }
}