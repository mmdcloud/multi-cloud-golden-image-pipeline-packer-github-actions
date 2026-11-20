# Production-Grade Multi-Cloud Golden Image Pipeline

[![Packer CI](https://github.com/mohit/multi-cloud-golden-image-pipeline-packer-github-actions/actions/workflows/packer-ci.yml/badge.svg)](https://github.com/mohit/multi-cloud-golden-image-pipeline-packer-github-actions/actions/workflows/packer-ci.yml)
[![CIS Benchmark Level 1](https://img.shields.io/badge/Compliance-CIS%20Level%201-success.svg)](https://www.cisecurity.org/cis-benchmarks/)
[![Keyless Auth OIDC](https://img.shields.io/badge/Security-Keyless%20OIDC-blue.svg)](docs/OIDC_SETUP.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

An enterprise-ready, fully automated **Golden Machine Image Pipeline** supporting **AWS (AMI)**, **Google Cloud Platform (Compute Engine)**, and **Microsoft Azure (Managed Image / Azure Compute Gallery)** using **HashiCorp Packer (HCL2)**, **Ansible**, **Goss**, and **GitHub Actions**.

---

## 🌟 Key Features & Enterprise Capabilities

- **Multi-Cloud Parity**: Identical OS baseline, security controls, and agent configurations across AWS, GCP, and Azure.
- **CIS Benchmark Level 1 Hardening**:
  - Kernel & sysctl hardening (ASLR, SYN flood protection, Martian packet logging, disabled IP redirects & forwarding).
  - OpenSSH daemon lockdown (root login disabled, password auth disabled, strict cryptography ciphers).
  - Immutable audit logging with `auditd`.
  - PAM quality policies and brute force lockouts (`pam_pwquality`, `pam_faillock`).
  - UFW firewall baseline.
- **Zero-Trust Keyless CI/CD**:
  - No stored static credentials (no AWS keys, GCP JSON keys, or Azure secrets).
  - Built-in **OpenID Connect (OIDC)** authentication for AWS IAM STS, GCP Workload Identity Federation, and Azure Federated Credentials.
- **Shift-Left Automated Compliance Testing**:
  - In-instance verification with **Goss** runs before the image is finalized.
  - Builds automatically fail and terminate if any security test fails.
- **Disk & Image Encryption**:
  - AWS EBS KMS Customer-Managed Keys (CMK) and IMDSv2 strictly enforced (`http_tokens = "required"`).
  - GCP Customer-Managed Encryption Keys (CMEK) and Shielded VM configuration (vTPM, Secure Boot, Integrity Monitoring).
  - Azure Disk Encryption Set (DES) Customer-Managed Keys and Gen2 Secure Boot / vTPM.
- **Sanitization & De-provisioning**:
  - Machine-ID wiped (`/etc/machine-id`), cloud-init logs and seeds cleared, temporary SSH keys and accounts removed, and system logs truncated before sealing.
- **Automated Patch Management**:
  - Scheduled weekly GitHub Actions cron job automatically re-bakes base images with the latest security updates.

---

## 📂 Repository Structure

```
.
├── .github/
│   ├── workflows/
│   │   ├── packer-ci.yml             # PR linting, Packer validate, Checkov security scan
│   │   ├── packer-build.yml          # Multi-cloud release pipeline with OIDC auth
│   │   └── security-schedule.yml     # Weekly automated patching schedule
│   └── dependabot.yml                # Dependency update policy
├── packer/
│   ├── build.pkr.hcl                 # Packer build block & provisioners sequence
│   ├── sources.pkr.hcl               # Cloud builders (AWS EBS, GCP Compute, Azure ARM)
│   ├── variables.pkr.hcl             # Input variable definitions & validations
│   ├── locals.pkr.hcl                # Dynamic naming, timestamps & standardized tags
│   ├── versions.pkr.hcl              # Plugin pinning (amazon, googlecompute, azure, ansible)
│   └── vars/
│       ├── common.pkrvars.hcl        # Common OS and compliance settings
│       ├── aws.pkrvars.hcl           # AWS region, instance types, KMS, VPC settings
│       ├── gcp.pkrvars.hcl           # GCP project, zone, CMEK, storage location
│       └── azure.pkrvars.hcl         # Azure subscription, resource group, gallery
├── ansible/
│   ├── ansible.cfg                   # Local Ansible configuration
│   ├── playbook.yml                  # Hardening orchestrator playbook
│   ├── group_vars/
│   │   └── all.yml                   # Hardening variables, ciphers, timeouts
│   └── roles/
│       ├── base/                     # OS updates, unattended-upgrades, base tools
│       ├── cis_hardening/            # sysctl, sshd, auditd, ufw, pam, limits
│       └── cloud_agents/             # AWS SSM, GCP Guest Agent, Azure WALinuxAgent
├── scripts/
│   ├── bootstrap.sh                  # VM bootstrap (Python, Ansible, Goss)
│   ├── run-goss-tests.sh             # Goss automated compliance runner
│   └── cleanup.sh                    # Multi-cloud de-provisioning & sanitization
├── tests/
│   └── goss/
│       └── goss.yaml                 # Goss CIS validation test assertions
├── docs/
│   ├── ARCHITECTURE.md               # Architectural blueprint & pipeline lifecycle
│   ├── SECURITY.md                   # Detailed CIS & NIST security controls
│   └── OIDC_SETUP.md                 # Cloud OIDC federation configuration guide
├── Makefile                          # Developer command automation
└── README.md
```

---

## 🚀 Getting Started Locally

### Prerequisites
- [Packer](https://developer.hashicorp.com/packer/downloads) (>= 1.10.0)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) (>= 2.14)
- Shellcheck & Checkov (optional for linting)

### 1. Initialize & Validate
```bash
# Initialize required plugins
make init

# Format all Packer files
make fmt

# Validate configuration across all three clouds
make validate

# Run security checks
make checkov
make lint
```

### 2. Local Builds
Ensure cloud credentials or environment variables are configured in your local shell:
```bash
# Build AWS AMI
make build-aws

# Build GCP Compute Engine Image
make build-gcp

# Build Azure Managed Image
make build-azure
```

---

## 🔒 Cloud OIDC Configuration for CI/CD

Before running the GitHub Actions build pipeline, set up the OIDC federated trust in your clouds as described in **[docs/OIDC_SETUP.md](docs/OIDC_SETUP.md)**.

### Required GitHub Secrets & Variables

#### AWS (Secrets)
- `AWS_OIDC_ROLE_ARN`: IAM Role ARN configured with `sts:AssumeRoleWithWebIdentity`.

#### GCP (Secrets)
- `GCP_PROJECT_ID`: Target GCP Project ID.
- `GCP_SERVICE_ACCOUNT`: Service Account email with Compute Image Admin permissions.
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: Full resource path of the Workload Identity Provider.

#### Azure (Secrets)
- `AZURE_CLIENT_ID`: App Registration Application (Client) ID.
- `AZURE_TENANT_ID`: Azure Active Directory Directory (Tenant) ID.
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID.

---

## 🛡️ CIS Controls & Shift-Left Verification

During the Packer build, before the VM snapshot is created:
1. `ansible-local` executes the CIS benchmark hardening roles.
2. `scripts/run-goss-tests.sh` executes tests defined in `tests/goss/goss.yaml`.
3. If ANY assertion fails (e.g. root login allowed, martians unlogged, legacy packages installed), **the build exits with an error and the image is never created**.
4. Once verified, `scripts/cleanup.sh` removes all keys, accounts, logs, and resets machine IDs.

Refer to **[docs/SECURITY.md](docs/SECURITY.md)** for detailed compliance mappings.

---

## 📄 License
This repository is licensed under the MIT License.
