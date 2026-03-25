# Copyright 2026 The MathWorks, Inc.

resource "local_file" "helm_values_override" {
  filename        = "${path.root}/values-override-${var.resource_suffix}.yaml"
  file_permission = "0600"

  content = <<EOT
global:
  nodeLabel:
    key: "${var.node_label_key}"
    jobManagerValue: "${var.job_manager_node_label_value}"
    workerValue: "${var.worker_node_label_value}"

matlabPath: "${var.matlab_path}"

efsFilesystemID: "${var.efs_filesystem_id}"

cluster-autoscaler:
  awsRegion: "${var.aws_region}"
  autoDiscovery:
    clusterName: "${var.cluster_name}"

mjs:
  matlabRelease: "${local.lower_matlab_release}"
  loadBalancerAnnotations:
    service.beta.kubernetes.io/load-balancer-source-ranges: "${join(", ", var.load_balancer_source_ranges)}"
  maxWorkers: ${var.mjs_max_workers}

  workerMemoryRequest: "${var.worker_memory_gib}Gi"
  workerMemoryLimit: "${var.worker_memory_gib}Gi"

  # Ensure the job-manager only runs on the job-manager node
  jobManagerNodeSelector:
    ${var.node_label_key}: ${var.job_manager_node_label_value}

  jobManagerTolerations:
    - key: "JobManagerNode"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

  # Ensure workers only run on worker nodes
  workerNodeSelector:
    ${var.node_label_key}: ${var.worker_node_label_value}

  workerTolerations:
    - key: "WorkerNode"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"

EOT
}