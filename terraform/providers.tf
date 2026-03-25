# Copyright 2026 The MathWorks, Inc.

# ------------------------
# AWS Region & Partition
# ------------------------

data "aws_region" "current" {}
data "aws_partition" "current" {}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Creator = "mw-k8s-parallel-server-terraform"
      StackID = random_uuid.stackid.result
    }
  }
}
