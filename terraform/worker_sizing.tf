# Copyright 2026 The MathWorks, Inc.

#--------------------------------------------
# Instance type metadata
#--------------------------------------------
data "aws_ec2_instance_type" "worker" {
  instance_type = var.node_instance_type
}

#--------------------------------------------
# Locals for worker sizing (CPU + Memory aware)
#--------------------------------------------
locals {

  #####################################################
  # Scheduling constants
  #####################################################
  # For detailed information on the default memory and CPU resource requests related to MJS, refer to:
  # https://github.com/mathworks-ref-arch/matlab-parallel-server-on-kubernetes/blob/main/helm_values.md 

  # Worker pod requests (matches MJS chart defaults)
  worker_cpu_request_m = 2000 # 2 vCPU

  # Worker memory request derived from Terraform variable
  # User supplies GiB; convert to MiB
  worker_mem_request_mib = var.worker_memory_gib * 1024

  # Pool-proxy pod (1 per 32 workers)
  poolproxy_cpu_request_m   = 500 # 0.5 vCPU
  poolproxy_mem_request_mib = 512 # 0.5 GiB

  # System overhead per worker node
  system_cpu_overhead_m   = 300  # kubelet, aws-node, efs-csi, proxy
  system_mem_overhead_mib = 1024 # ~1 GiB

  # Fraction of EC2 instance capacity that Kubernetes makes allocatable
  alloc_cpu_fraction = 0.95
  alloc_mem_fraction = 0.90


  #####################################################
  # 1) Read EC2 instance type metadata dynamically
  #####################################################

  _vcpus   = try(data.aws_ec2_instance_type.worker.default_vcpus, 4)
  _mem_mib = try(data.aws_ec2_instance_type.worker.memory_size, 8192)

  # EARLY VALIDATION (worker memory must fit on instance)

  _memory_validation = (
    local.worker_mem_request_mib + local.system_mem_overhead_mib <= floor(local._mem_mib * local.alloc_mem_fraction)
  )

  # The following dummy value holds a precondition to validate memory sizing early.
  validated_worker_memory = 0

  #####################################################
  # 2) Convert to allocatable resources
  #####################################################

  alloc_cpu_m   = floor(local._vcpus * 1000 * local.alloc_cpu_fraction)
  alloc_mem_mib = floor(local._mem_mib * local.alloc_mem_fraction)


  #####################################################
  # 3) Per-node usable resources (minus system overhead)
  #####################################################

  usable_cpu_m   = max(0, local.alloc_cpu_m - local.system_cpu_overhead_m)
  usable_mem_mib = max(0, local.alloc_mem_mib - local.system_mem_overhead_mib)


  #####################################################
  # 4) Max workers per node (CPU + memory)
  #####################################################

  workers_per_node_by_cpu = floor(local.usable_cpu_m / local.worker_cpu_request_m)
  workers_per_node_by_mem = floor(local.usable_mem_mib / local.worker_mem_request_mib)

  workers_per_node_raw = max(0, min(
    local.workers_per_node_by_cpu,
    local.workers_per_node_by_mem
  ))


  #####################################################
  # 5) Preliminary cluster-wide workers (node * count)
  #####################################################

  prelim_workers = local.workers_per_node_raw * var.max_worker_nodes


  #####################################################
  # 6) Pool proxy count (1 per 32 workers; at least 1)
  #####################################################

  poolproxy_count = (
    local.prelim_workers > 0 ?
    max(1, ceil(local.prelim_workers / 32)) :
    0
  )


  #####################################################
  # 7) Cluster-wide usable capacity (subtract overheads)
  #####################################################

  total_alloc_cpu_m   = local.alloc_cpu_m * var.max_worker_nodes
  total_alloc_mem_mib = local.alloc_mem_mib * var.max_worker_nodes

  total_system_cpu_overhead_m   = local.system_cpu_overhead_m * var.max_worker_nodes
  total_system_mem_overhead_mib = local.system_mem_overhead_mib * var.max_worker_nodes

  poolproxy_total_cpu_m   = local.poolproxy_cpu_request_m * local.poolproxy_count
  poolproxy_total_mem_mib = local.poolproxy_mem_request_mib * local.poolproxy_count

  workers_by_cpu_cluster = floor(
    max(0,
      local.total_alloc_cpu_m
      -local.total_system_cpu_overhead_m
      -local.poolproxy_total_cpu_m
    ) / local.worker_cpu_request_m
  )

  workers_by_mem_cluster = floor(
    max(0,
      local.total_alloc_mem_mib
      -local.total_system_mem_overhead_mib
      -local.poolproxy_total_mem_mib
    ) / local.worker_mem_request_mib
  )


  #####################################################
  # 8) Final maxWorkers value fed into the Helm chart
  #####################################################

  computed_mjs_max_workers = min(
    local.prelim_workers,
    local.workers_by_cpu_cluster,
    local.workers_by_mem_cluster
  )
}

#--------------------------------------------
# MEMORY VALIDATION BLOCK
#--------------------------------------------
resource "null_resource" "validate_worker_memory" {
  triggers = {
    always = timestamp()
  }

  lifecycle {
    precondition {
      condition     = local._memory_validation
      error_message = "ERROR: worker_memory_gib=${var.worker_memory_gib} GiB is too large for EC2 instance type ${var.node_instance_type}, which only has ${local._mem_mib} MiB total and ${floor(local._mem_mib * local.alloc_mem_fraction)} MiB allocatable. Reduce worker_memory_gib or choose a larger instance type."
    }
  }
}