# Multi-Cloud Golden Image Architecture

This document details the architectural blueprint, design principles, and operational lifecycle of the automated multi-cloud golden image pipeline powered by **HashiCorp Packer** and **GitHub Actions**.

---

## 1. High-Level Architecture Overview

```
                                      +------------------------+
                                      | Developer / Git Commit |
                                      +-----------+------------+
                                                  |
                                                  v
                                      +------------------------+
                                      |  GitHub Actions CI/CD  |
                                      +-----------+------------+
                                                  |
                  +-------------------------------+-------------------------------+
                  |                               |                               |
       (OIDC sts.amazonaws.com)       (OIDC Workload Identity)          (OIDC Federated Auth)
                  |                               |                               |
                  v                               v                               v
          +---------------+               +---------------+               +---------------+
          |  AWS Pipeline |               |  GCP Pipeline |               | Azure Pipeline|
          +-------+-------+               +-------+-------+               +-------+-------+
                  |                               |                               |
                  | [Packer amazon-ebs]           | [Packer googlecompute]        | [Packer azure-arm]
                  | - Launch t3.medium            | - Launch e2-medium            | - Launch Standard_B2s
                  | - IMDSv2 Required             | - Shielded VM (vTPM/SecBoot)  | - Gen2 Secure Boot
                  | - KMS CMK Encrypted           | - CMEK Encrypted Disk         | - Disk Encryption Set
                  +---------------+---------------+---------------+---------------+
                                                  |
                                                  v
                            +-------------------------------------------+
                            |       Provisioning Pipeline (In-VM)       |
                            |                                           |
                            | 1. Bootstrap (Python, Ansible, Goss)      |
                            | 2. Base Configuration & Patch Upgrades    |
                            | 3. CIS Benchmark Level 1 Hardening        |
                            |    - Kernel Sysctl Hardening              |
                            |    - OpenSSH Configuration & Ciphers      |
                            |    - Auditd Rules (Immutable)             |
                            |    - PAM Quality & Account Lockout        |
                            |    - UFW Firewall Baseline                |
                            | 4. Cloud Agent Orchestration              |
                            |    - AWS: amazon-ssm-agent                |
                            |    - GCP: google-guest-agent              |
                            |    - Azure: walinuxagent                  |
                            | 5. Automated Compliance Testing (Goss)    |
                            |    (Build FAILS if any test fails)        |
                            | 6. Image Sanitization & De-provisioning   |
                            |    - Reset /etc/machine-id                |
                            |    - Clean cloud-init logs & seeds        |
                            |    - Wipe temporary keys & user accounts  |
                            |    - Truncate all logs                    |
                            +---------------------+---------------------+
                                                  |
                  +-------------------------------+-------------------------------+
                  |                               |                               |
                  v                               v                               v
          +---------------+               +---------------+               +---------------+
          |  AWS Output   |               |  GCP Output   |               | Azure Output  |
          | Encrypted AMI |               | Encrypted GCE |               | Compute Gal.  |
          | + Cross-Reg   |               | Image Family  |               | Managed Img   |
          +---------------+               +---------------+               +---------------+
```

---

## 2. Core Design Principles

1. **Immutable Infrastructure**: Golden images are built from scratch, tested, sealed, and published. Instances spun up from these images never require in-place patching or manual configuration changes.
2. **Zero-Trust Identity (Keyless CI/CD)**: Long-lived static cloud API keys (e.g. AWS Access Keys, GCP JSON keys, Azure Client Secrets) are strictly prohibited. All CI/CD runners authenticate via **OpenID Connect (OIDC)** with least-privilege short-lived tokens.
3. **Defense-in-Depth & Shift-Left Compliance**: Security validation occurs inside the build runner *before* the image is baked. If any CIS requirement or compliance test fails, the image is discarded immediately.
4. **Cloud Neutral Core, Provider Native Edges**: Common base configuration and hardening policies are executed uniformly across all clouds using Ansible, while platform-specific builders optimize for cloud-native storage, encryption, and telemetry.
5. **Encryption Everywhere**: All builder block devices, temporary volumes, and resultant machine images must be encrypted using Customer-Managed Keys (CMK / CMEK / Disk Encryption Sets).

---

## 3. Provisioning Lifecycle Stages

| Step | Provisioner | Action | Failure Mode |
|---|---|---|---|
| **1. Bootstrap** | Shell (`scripts/bootstrap.sh`) | Installs Python 3, Ansible, and Goss binary. Releases apt locks. | Aborts build |
| **2. Base Patching** | Ansible (`base` role) | Runs `apt-get dist-upgrade`, installs `unattended-upgrades`, purges legacy packages (telnet, rsh). | Aborts build |
| **3. Hardening** | Ansible (`cis_hardening` role) | Applies CIS Level 1 controls: sysctl, sshd, auditd, pam, ufw. | Aborts build |
| **4. Cloud Agents** | Ansible (`cloud_agents` role) | Detects target cloud and configures SSM / Google Guest / WALinuxAgent. | Aborts build |
| **5. Verification** | Goss (`scripts/run-goss-tests.sh`) | Executes 20+ automated assertions against active kernel, services, and files. | **Aborts build & discards image** |
| **6. Sanitization** | Shell (`scripts/cleanup.sh`) | Clears machine-id, cloud-init, logs, shell history, and temporary packer keys. | Aborts build |
| **7. Manifest** | Post-Processor | Emits JSON manifest recording artifact ID, git commit, build ID, and timestamp. | Non-fatal |
