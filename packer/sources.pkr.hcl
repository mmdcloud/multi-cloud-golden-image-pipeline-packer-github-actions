# ==============================================================================
# AWS EBS Builder (Amazon Linux / Ubuntu)
# ==============================================================================
source "amazon-ebs" "builder" {
  region        = var.aws_region
  instance_type = var.aws_instance_type
  ami_name      = local.image_name
  ami_description = "Production Hardened Golden Image (${var.security_compliance_level}) built from ${var.base_os}"

  # Source Base AMI Search (Ubuntu 22.04 LTS official Canonical image)
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical official account
    most_recent = true
  }

  # Network & Placement
  vpc_id    = var.aws_vpc_id != "" ? var.aws_vpc_id : null
  subnet_id = var.aws_subnet_id != "" ? var.aws_subnet_id : null

  # Storage & Volume Encryption (KMS)
  encrypt_boot = true
  kms_key_id   = var.aws_kms_key_id != "" ? var.aws_kms_key_id : null

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = var.aws_kms_key_id != "" ? var.aws_kms_key_id : null
  }

  # Security Hardening: IMDSv2 Strict Enforcement (Zero token leakage)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # SSH & Connection
  ssh_username = "ubuntu"
  ssh_timeout  = "15m"

  # AMI Distribution & Permissions
  ami_regions = var.aws_ami_regions
  ami_users   = var.aws_ami_users

  # 180-day deprecation policy by default
  deprecation_time = timeadd(timestamp(), "4320h")

  # Standardized Tagging
  tags        = local.standard_tags
  snapshot_tags = merge(local.standard_tags, {
    SnapshotOf = local.image_name
  })
}

# ==============================================================================
# GCP Compute Engine Builder
# ==============================================================================
source "googlecompute" "builder" {
  project_id   = var.gcp_project_id
  zone         = var.gcp_zone
  machine_type = var.gcp_machine_type

  # Source Base OS Image (Ubuntu 22.04 LTS)
  source_image_family  = "ubuntu-2204-lts"
  source_image_project_id = ["ubuntu-os-cloud"]

  # Target Golden Image Attributes
  image_name        = lower(replace(local.image_name, ".", "-"))
  image_description = "Production Hardened Golden Image (${var.security_compliance_level}) built from ${var.base_os}"
  image_family      = "golden-${var.base_os}"

  # Network
  network    = var.gcp_network
  subnetwork = var.gcp_subnetwork != "" ? var.gcp_subnetwork : null

  # Storage & CMEK Disk Encryption
  disk_size              = 20
  disk_type              = "pd-balanced"
  kms_key                = var.gcp_cmek_key != "" ? var.gcp_cmek_key : null
  image_storage_locations = var.gcp_image_storage_locations

  # Shielded VM Security Configuration (vTPM, Secure Boot, Integrity Monitoring)
  enable_secure_boot          = true
  enable_vtpm                 = true
  enable_integrity_monitoring = true

  # SSH Connection
  ssh_username = "packer"
  ssh_timeout  = "15m"

  # Standardized Labels
  image_labels = local.gcp_labels
}

# ==============================================================================
# Azure ARM Builder
# ==============================================================================
source "azure-arm" "builder" {
  # Azure Authentication is handled dynamically via OIDC or Service Principal
  subscription_id = var.azure_subscription_id

  # Build VM Location & Sizing
  location                          = var.azure_location
  temp_resource_group_name          = "rg-packer-temp-${local.build_timestamp}"
  build_resource_group_name         = var.azure_resource_group
  vm_size                           = var.azure_vm_size

  # Base Image: Ubuntu 22.04 LTS Canonical
  os_type         = "Linux"
  image_publisher = "Canonical"
  image_offer     = "0001-com-ubuntu-server-jammy"
  image_sku       = "22_04-lts-gen2"
  image_version   = "latest"

  # Target Managed Image
  managed_image_name                = local.image_name
  managed_image_resource_group_name = var.azure_resource_group

  # Target Azure Compute Gallery (Shared Image Gallery) publishing (optional)
  dynamic "shared_image_gallery_destination" {
    for_each = var.azure_gallery_name != "" ? [1] : []
    content {
      subscription         = var.azure_subscription_id
      resource_group       = var.azure_resource_group
      gallery_name         = var.azure_gallery_name
      image_name           = var.azure_image_definition_name
      image_version        = var.image_version
      replication_regions  = [var.azure_location]
    }
  }

  # Disk Configuration & Encryption (Customer-Managed Key / DES)
  os_disk_size_gb              = 30
  disk_encryption_set_id       = var.azure_disk_encryption_set_id != "" ? var.azure_disk_encryption_set_id : null

  # Secure Boot & vTPM Support (Gen2)
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Standardized Tags
  azure_tags = local.standard_tags
}
