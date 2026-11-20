# ==============================================================================
# AWS Provider Variables
# ==============================================================================
aws_region        = "us-east-1"
aws_instance_type = "t3.medium"

# KMS Customer-Managed Key ARN for EBS Volume Encryption
# Leave empty string to use AWS default aws/ebs KMS key
aws_kms_key_id    = ""

# VPC and Subnet IDs (Optional: provide if building inside existing private VPC)
aws_vpc_id        = ""
aws_subnet_id     = ""

# Target regions for automated cross-region AMI replication
aws_ami_regions   = [
  "us-east-1",
  "us-west-2",
  "eu-west-1"
]

# External AWS Account IDs permitted to launch this AMI (cross-account sharing)
aws_ami_users     = []
