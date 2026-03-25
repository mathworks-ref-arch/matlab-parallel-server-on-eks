# Copyright 2026 The MathWorks, Inc.

# ------------------------
# Mappings as Locals
# ------------------------

locals {
  snapshot_map = {
    "eu-west-1" = {
      "R2024b" = {
        snapshot_id = "snap-0b21f2d2170e349ff"
      }
      "R2025a" = {
        snapshot_id = "snap-00cbca5502dce44de"
      }

      "R2025b" = {
        snapshot_id = "snap-07073395fde7beb7b"
      }
    }
    "us-east-1" = {
      "R2024b" = {
        snapshot_id = "snap-0a0a9f223577f6264"
      }
      "R2025a" = {
        snapshot_id = "snap-07f2a77cb87a99951"
      }

      "R2025b" = {
        snapshot_id = "snap-0a4d33ed1517e7631"
      }
    }

    "us-west-2" = {
      "R2024b" = {
        snapshot_id = "snap-094fb8136ebee322b"
      }
      "R2025a" = {
        snapshot_id = "snap-0a3ad0300e394079a"
      }

      "R2025b" = {
        snapshot_id = "snap-0b29d445c298e36f9"
      }
    }

    "ap-northeast-1" = {
      "R2024b" = {
        snapshot_id = "snap-003682cb5c8104ad1"
      }
      "R2025a" = {
        snapshot_id = "snap-0155966e9207d373c"
      }

      "R2025b" = {
        snapshot_id = "snap-0f284e28b4a4e0db0"
      }
    }

  }

  ebs_volume_mapping = {
    ebs_device_name = {
      SATA = "/dev/sdb"
    }
    matlab_root = {
      container = "/opt/matlab"
    }
  }
}

# ------------------------
# Cluster security ID
# ------------------------

locals {
  cluster_sg_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}

