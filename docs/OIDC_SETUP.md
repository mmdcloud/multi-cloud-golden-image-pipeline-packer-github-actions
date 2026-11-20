# Zero-Trust OIDC Cloud Authentication Setup Guide

This guide details how to configure **OpenID Connect (OIDC)** authentication between **GitHub Actions** and the three major cloud providers (AWS, GCP, and Azure). 

Using OIDC eliminates static credentials (like AWS Access Keys or Service Account JSON keys) and uses cryptographically signed JWT tokens issued by GitHub Actions for short-lived, least-privileged access.

---

## 1. Amazon Web Services (AWS) Setup

### Step 1.1: Create the OpenID Connect Provider in AWS IAM
1. Open IAM Console -> **Identity providers** -> **Add provider**.
2. Select **OpenID Connect**.
3. **Provider URL**: `https://token.actions.githubusercontent.com`
4. **Audience**: `sts.amazonaws.com`
5. Save the provider.

### Step 1.2: Create the IAM Role with Trust Policy
Create an IAM Role (e.g. `GitHubActions-Packer-GoldenImageRole`) with this trust relationship:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG_OR_USER>/multi-cloud-golden-image-pipeline-packer-github-actions:*"
        }
      }
    }
  ]
}
```

### Step 1.3: Attach Permissions to the Role
Attach an IAM policy granting EC2 AMI creation, KMS encryption, and EBS volume attachment permissions.

### Step 1.4: Configure GitHub Repository Secrets
- `AWS_OIDC_ROLE_ARN`: `arn:aws:iam::<ACCOUNT_ID>:role/GitHubActions-Packer-GoldenImageRole`

---

## 2. Google Cloud Platform (GCP) Setup

### Step 2.1: Enable Required APIs
```bash
gcloud services enable iamcredentials.googleapis.com compute.googleapis.com
```

### Step 2.2: Create Workload Identity Pool & Provider
```bash
# Create Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
    --project="<PROJECT_ID>" \
    --location="global" \
    --display-name="GitHub Actions Pool"

# Create Provider inside the Pool
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
    --project="<PROJECT_ID>" \
    --location="global" \
    --workload-identity-pool="github-pool" \
    --display-name="GitHub Actions Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"
```

### Step 2.3: Create Service Account and Bind IAM
```bash
# Create Service Account
gcloud iam service-accounts create "sa-packer-builder" \
    --project="<PROJECT_ID>" \
    --display-name="Packer Image Builder Service Account"

# Allow GitHub Actions to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding "sa-packer-builder@<PROJECT_ID>.iam.gserviceaccount.com" \
    --project="<PROJECT_ID>" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/attribute.repository/<GITHUB_ORG_OR_USER>/multi-cloud-golden-image-pipeline-packer-github-actions"

# Grant Compute Image Admin permissions
gcloud projects add-iam-policy-binding "<PROJECT_ID>" \
    --member="serviceAccount:sa-packer-builder@<PROJECT_ID>.iam.gserviceaccount.com" \
    --role="roles/compute.instanceAdmin.v1"
```

### Step 2.4: Configure GitHub Repository Secrets
- `GCP_PROJECT_ID`: `<PROJECT_ID>`
- `GCP_SERVICE_ACCOUNT`: `sa-packer-builder@<PROJECT_ID>.iam.gserviceaccount.com`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: `projects/<PROJECT_NUMBER>/locations/global/workloadIdentityPools/github-pool/providers/github-provider`

---

## 3. Microsoft Azure Setup

### Step 3.1: Register Azure AD Application
```bash
az ad app create --display-name "github-actions-packer"
APPLICATION_CLIENT_ID=$(az ad app list --display-name "github-actions-packer" --query "[0].appId" -o tsv)
az ad sp create --id "${APPLICATION_CLIENT_ID}"
```

### Step 3.2: Configure Federated Identity Credential
```bash
cat << 'EOF' > credential.json
{
  "name": "github-actions-branch-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<GITHUB_ORG_OR_USER>/multi-cloud-golden-image-pipeline-packer-github-actions:ref:refs/heads/main",
  "description": "GitHub Actions main branch deployment",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF

az ad app federated-credential create --id "${APPLICATION_CLIENT_ID}" --parameters credential.json
```

### Step 3.3: Assign Role Permissions
```bash
az role assignment create \
    --role "Contributor" \
    --assignee "${APPLICATION_CLIENT_ID}" \
    --scope "/subscriptions/<AZURE_SUBSCRIPTION_ID>/resourceGroups/rg-golden-images-prod"
```

### Step 3.4: Configure GitHub Repository Secrets
- `AZURE_CLIENT_ID`: `<APPLICATION_CLIENT_ID>`
- `AZURE_TENANT_ID`: `<AZURE_TENANT_ID>`
- `AZURE_SUBSCRIPTION_ID`: `<AZURE_SUBSCRIPTION_ID>`
