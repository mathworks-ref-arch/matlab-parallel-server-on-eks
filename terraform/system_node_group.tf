# Copyright 2026 The MathWorks, Inc.
#
# Untainted "system" node group for kube-system and managed add-ons
# This complements the existing tainted Job Manager and Worker groups so
# EKS managed add-ons (like aws-efs-csi-driver) can schedule successfully.

# --------------------------------------------
# Launch template for the system node group
# --------------------------------------------
resource "aws_launch_template" "system" {
  name_prefix = "system-"

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

  # Ensure system nodes have the EKS cluster security group so they can reach EFS/NFS
  # and control-plane as applicable. Preserve user-provided additional SGs as well.
  vpc_security_group_ids = concat([local.cluster_sg_id], tolist(var.additional_security_groups))
}

# --------------------------------------------
# System node group (untainted, fixed size 1)
# --------------------------------------------
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "system-${random_id.resource_suffix.hex}"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn

  subnet_ids = var.subnet_ids

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  instance_types = [var.system_node_instance_type]

  launch_template {
    id      = aws_launch_template.system.id
    version = "$Latest"
  }

  labels = {
    "node-type" = "system"
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.stack_tags
}