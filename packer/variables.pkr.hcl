# ==============================================================================
# General & Pipeline Variables
# ==============================================================================

variable "environment" {
  type        = string
  description = "Target environment for image distribution (e.g. staging, prod)"
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "image_version" {
  type        = string
  description = "Semantic version of the golden image (e.g., 1.0.0)"
  default     = "1.0.0"
}

variable "base_os" {
  type        = string
  description = "Base operating system name"
  default     = "ubuntu-22.04"
}

variable "build_id" {
  type        = string
  description = "GitHub Actions Run ID or unique pipeline execution identifier"
  default     = "local"
}

variable "git_commit_sha" {
  type        = string
  description = "Git commit hash of the configuration"
  default     = "development"
}

variable "security_compliance_level" {
  type        = string
  description = "Compliance baseline level (e.g. CIS-Level-1, CIS-Level-2, STIG)"
  default     = "CIS-Level-1"
}

variable "enable_cis_hardening" {
  type        = bool
  description = "Flag to enable/disable CIS benchmark hardening"
  default     = true
}

variable "enable_automated_testing" {
  type        = bool
  description = "Flag to execute Goss compliance validation during build"
  default     = true
}

# ==============================================================================
# AWS Configuration Variables
# ==============================================================================

variable "aws_region" {
  type        = string
  description = "Primary AWS region for AMI creation"
  default     = "us-east-1"
}

variable "aws_instance_type" {
  type        = string
  description = "AWS EC2 instance type used during building"
  default     = "t3.medium"
}

variable "aws_kms_key_id" {
  type        = string
  description = "AWS KMS Key ARN or Alias for EBS volume encryption (blank for AWS-managed default key)"
  default     = ""
}

variable "aws_vpc_id" {
  type        = string
  description = "VPC ID where the temporary build EC2 instance will run (optional)"
  default     = ""
}

variable "aws_subnet_id" {
  type        = string
  description = "Subnet ID where the temporary build EC2 instance will run (optional)"
  default     = ""
}

variable "aws_ami_regions" {
  type        = list(string)
  description = "Target regions where the resulting AMI will be automatically copied"
  default     = []
}

variable "aws_ami_users" {
  type        = list(string)
  description = "List of AWS Account IDs allowed to launch the resulting AMI"
  default     = []
}

# ==============================================================================
# GCP Configuration Variables
# ==============================================================================

variable "gcp_project_id" {
  type        = string
  description = "GCP Project ID where image will be built and published"
  default     = ""
}

variable "gcp_zone" {
  type        = string
  description = "GCP compute zone for building (e.g., us-central1-a)"
  default     = "us-central1-a"
}

variable "gcp_machine_type" {
  type        = string
  description = "GCP machine type for the builder instance"
  default     = "e2-medium"
}

variable "gcp_network" {
  type        = string
  description = "VPC network for GCP build instance (optional)"
  default     = "default"
}

variable "gcp_subnetwork" {
  type        = string
  description = "VPC subnetwork for GCP build instance (optional)"
  default     = ""
}

variable "gcp_cmek_key" {
  type        = string
  description = "Customer-Managed Encryption Key (CMEK) resource string for GCP disk encryption"
  default     = ""
}

variable "gcp_image_storage_locations" {
  type        = list(string)
  description = "GCP regional or multi-regional storage locations for the image"
  default     = ["us"]
}

# ==============================================================================
# Azure Configuration Variables
# ==============================================================================

variable "azure_subscription_id" {
  type        = string
  description = "Azure Subscription ID"
  default     = ""
}

variable "azure_resource_group" {
  type        = string
  description = "Azure Resource Group for temporary build resources and image output"
  default     = "rg-golden-images"
}

variable "azure_location" {
  type        = string
  description = "Azure region (e.g. eastus, westeurope)"
  default     = "eastus"
}

variable "azure_vm_size" {
  type        = string
  description = "Azure Virtual Machine size used for building"
  default     = "Standard_B2s"
}

variable "azure_gallery_name" {
  type        = string
  description = "Azure Compute Gallery (Shared Image Gallery) name"
  default     = ""
}

variable "azure_image_definition_name" {
  type        = string
  description = "Azure Image Definition name inside the Compute Gallery"
  default     = "golden-ubuntu-2204"
}

variable "azure_disk_encryption_set_id" {
  type        = string
  description = "Resource ID of the Azure Disk Encryption Set for CMK encryption"
  default     = ""
}
