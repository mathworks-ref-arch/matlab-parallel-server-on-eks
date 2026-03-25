# Copyright 2026 The MathWorks, Inc.

#------------------------------------------
# Outputs
#------------------------------------------
output "efs_id" {
  value = module.filesystem.efs_file_system_id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "stack_uuid_tag" {
  value = random_uuid.stackid.result
}

output "current_caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "current_context_arn" {
  value = data.aws_iam_session_context.current.issuer_arn
}

output "matlab_release" {
  value = var.matlab_release
}

output "helm_values_override_file" {
  value = module.local.values_override_filename
}
