locals {
  # Standardized timestamp in YYYYMMDD-HHMMSS format
  build_timestamp = formatdate("YYYYMMDD-hhmmss", timestamp())

  # Standardized Golden Image Name: golden-os-version-timestamp
  image_name = "golden-${var.base_os}-v${var.image_version}-${local.build_timestamp}"

  # Enterprise Tagging & Metadata Schema applied across all clouds
  standard_tags = {
    Name               = local.image_name
    BaseOS             = var.base_os
    Version            = var.image_version
    Environment        = var.environment
    Compliance         = var.security_compliance_level
    ManagedBy          = "Packer-GitHub-Actions"
    BuildId            = var.build_id
    GitCommitSha       = var.git_commit_sha
    Hardened           = tostring(var.enable_cis_hardening)
    AutomatedTesting   = tostring(var.enable_automated_testing)
    CreationDate       = local.build_timestamp
  }

  # GCP Labels require lowercase letters, numbers, hyphens, and underscores only
  gcp_labels = {
    name              = lower(replace(local.image_name, ".", "-"))
    base_os           = lower(replace(var.base_os, ".", "-"))
    version           = lower(replace(var.image_version, ".", "-"))
    environment       = lower(var.environment)
    compliance        = lower(replace(var.security_compliance_level, "-", "_"))
    managed_by        = "packer_github_actions"
    build_id          = lower(replace(var.build_id, ".", "-"))
    git_commit_sha    = lower(substr(var.git_commit_sha, 0, 8))
  }
}
