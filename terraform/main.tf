# Copyright 2026 The MathWorks, Inc.

# ------------------------
# UUID for tagging 
# ------------------------

resource "random_uuid" "stackid" {}

resource "random_id" "resource_suffix" {
  byte_length = 4 # 4 bytes = 8 hex characters
}

# --------------------------
# Roles
# -------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "EKSClusterRole-${random_id.resource_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role" "eks_node_group_role" {
  name = "EKSNodeGroupRole-${random_id.resource_suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_ec2_container_policy_attachment" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_eks_cni_policy_attachment" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy" "eks_node_group_ca_policy" {
  name = "ClusterAutoScalingPolicy-${random_id.resource_suffix.hex}"
  role = aws_iam_role.eks_node_group_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = ["arn:${data.aws_partition.current.partition}:autoscaling:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled"                        = "true",
            "aws:ResourceTag/k8s.io/cluster-autoscaler/${local.computed_cluster_name}" = "owned"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ]
        # Describe* actions do not allow resource level perms, since describe is a global action
        # we can only limit it to the current region
        Resource = "*",
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" : "${data.aws_region.current.region}"
          }
        }
      }
    ]
  })
}

#-----------------------------------------------------------------
# Access Entry 
#-----------------------------------------------------------------
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

resource "aws_eks_access_entry" "current_user_access_entry" {
  depends_on    = [aws_eks_cluster.eks_cluster]
  cluster_name  = local.computed_cluster_name
  principal_arn = data.aws_iam_session_context.current.issuer_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "current_user_policy_association" {
  depends_on    = [aws_eks_cluster.eks_cluster]
  cluster_name  = local.computed_cluster_name
  principal_arn = data.aws_iam_session_context.current.issuer_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

#--------------------------------------------
# KMS Key
#--------------------------------------------
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS cluster secrets encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

#--------------------------------------------
# Cluster
#--------------------------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = local.computed_cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  access_config {
    authentication_mode = "API"
  }

  encryption_config {
    resources = ["secrets"]

    provider {
      key_arn = aws_kms_key.eks_secrets.arn
    }
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.public_access_cidr_blocks
  }

}

# --------------------------------------------
#  Launch templates
# --------------------------------------------
resource "aws_launch_template" "job_manager" {
  name_prefix = "job-manager-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens = "optional"
  }

  # vpc_security_group_ids = var.additional_security_groups
}

resource "aws_launch_template" "worker" {
  name_prefix = "worker-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  block_device_mappings {
    device_name = local.ebs_volume_mapping.ebs_device_name.SATA
    ebs {
      delete_on_termination = true
      snapshot_id           = var.worker_ebs_snapshot_id != "" ? var.worker_ebs_snapshot_id : local.snapshot_map[data.aws_region.current.region][var.matlab_release].snapshot_id
      volume_type           = "gp3"
      encrypted             = true
    }
  }

  metadata_options {
    http_tokens = "optional"
  }

  user_data = base64encode(templatefile("${path.module}/worker_userdata.sh.tftpl", {
    DeviceName = local.ebs_volume_mapping.ebs_device_name.SATA
    MatlabRoot = local.ebs_volume_mapping.matlab_root.container
  }))

  vpc_security_group_ids = concat([local.cluster_sg_id], tolist(var.additional_security_groups))
}

#--------------------------------------------
# Node groups
#--------------------------------------------
resource "aws_eks_node_group" "job_manager" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "job-manager-${random_id.resource_suffix.hex}"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  subnet_ids = var.subnet_ids

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  instance_types = [var.job_manager_instance_type]

  launch_template {
    id      = aws_launch_template.job_manager.id
    version = "$Latest"
  }

  labels = {
    "${var.node_label_key}" = var.job_manager_node_label_value
  }

  taint {
    key    = "JobManagerNode"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
}

resource "aws_eks_node_group" "worker" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "worker-${random_id.resource_suffix.hex}"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  subnet_ids = var.subnet_ids

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_worker_nodes
    max_size     = var.max_worker_nodes
  }

  instance_types = [var.node_instance_type]

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  labels = {
    "${var.node_label_key}" = var.worker_node_label_value
  }

  taint {
    key    = "WorkerNode"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = {
    "k8s.io/cluster-autoscaler/enabled"                        = "true"
    "k8s.io/cluster-autoscaler/${local.computed_cluster_name}" = "owned"
  }
}

#--------------------------------------------
# OICD Provider
#--------------------------------------------

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks_cluster_oicd_provider" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint
  ]
}

#--------------------------------------------
# Cluster resources
#--------------------------------------------
# Variables and data sources required:
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Data sources required for OIDC provider and account ID
data "aws_caller_identity" "current" {
}


#--------------------------------------------
# Modules 
#--------------------------------------------

module "filesystem" {
  source                    = "./modules/filesystem"
  cluster_name              = aws_eks_cluster.eks_cluster.name
  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  resource_suffix           = random_id.resource_suffix.hex
  kms_key_arn               = aws_kms_key.eks_secrets.arn
  enable_backup             = var.enable_efs_backup
  cluster_security_group_id = local.cluster_sg_id


  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_openid_connect_provider.eks_cluster_oicd_provider
  ]

}

module "local" {
  source                       = "./modules/local"
  cluster_name                 = aws_eks_cluster.eks_cluster.name
  matlab_release               = var.matlab_release
  aws_region                   = data.aws_region.current.region
  efs_filesystem_id            = module.filesystem.efs_file_system_id
  load_balancer_source_ranges  = var.public_access_cidr_blocks
  resource_suffix              = random_id.resource_suffix.hex
  matlab_path                  = local.ebs_volume_mapping.matlab_root.container
  node_label_key               = var.node_label_key
  job_manager_node_label_value = var.job_manager_node_label_value
  worker_node_label_value      = var.worker_node_label_value
  mjs_max_workers              = local.computed_mjs_max_workers
  worker_memory_gib            = var.worker_memory_gib

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]

}
