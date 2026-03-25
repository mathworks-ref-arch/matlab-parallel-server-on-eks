# Copyright 2026 The MathWorks, Inc.

#------------------------------------------
# Outputs
#------------------------------------------

output "values_override_filename" {
  value = resource.local_file.helm_values_override.filename
}

output "mjs_max_workers" {
  value = var.mjs_max_workers
}