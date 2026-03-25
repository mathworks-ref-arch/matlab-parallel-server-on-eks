# Copyright 2026 The MathWorks, Inc.

#--------------------------------------------
# External Data Sources 
#--------------------------------------------

data "aws_eks_cluster" "eks_cluster" {
  name = var.cluster_name
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_caller_identity" "current" {
}

data "aws_partition" "current" {
}

#-----------------------------------------------------------------
# Security group
#-----------------------------------------------------------------

resource "aws_security_group" "efs" {
  name        = "EFSSecurityGroup-${var.resource_suffix}"
  description = "Security group rules for the EFS attached to instance"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.cluster_security_group_id]
  }

}

#--------------------------------------------
# Elastic Filesystem
#--------------------------------------------

resource "aws_efs_file_system" "efs" {
  encrypted  = true
  kms_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
}

resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.efs.id

  backup_policy {
    status = var.enable_backup ? "ENABLED" : "DISABLED"
  }
}

resource "aws_efs_mount_target" "mount_targets" {
  for_each = toset(var.subnet_ids)

  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

#--------------------------------------------
# EKS CSI Driver Add-on
#--------------------------------------------
resource "aws_eks_addon" "efs_csi_driver" {
  cluster_name             = data.aws_eks_cluster.eks_cluster.name
  addon_name               = "aws-efs-csi-driver"
  service_account_role_arn = aws_iam_role.efs_csi_driver_role.arn
}

# --------------------------
# Roles
# -------------------------
resource "aws_iam_role" "efs_csi_driver_role" {
  name = "EFSCSIDriverRole-${var.resource_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = { # For more granular control, review AWS documentation: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "${replace(data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:*:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_efs_csi_driver_policy_attachment" {
  role       = aws_iam_role.efs_csi_driver_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}