# Deploy to AWS with Terraform Using GitHub Actions (Secure OIDC Setup)

![Architecture Diagram](diagram)

## Overview 

This project demonstrates how to securely deploy AWS infrastructure with Terraform, using **GitHub Actions** and **OpenID Connect (OIDC)** — **no static AWS keys needed**.  
Follow these steps to set up secure CI/CD, get temporary AWS credentials, and protect your Terraform state.

---

## 🗺️ Architecture

1. **GitHub Actions** requests a short-lived OIDC token.
2. **AWS IAM** trusts that OIDC token (configured as an Identity Provider).
3. The workflow **assumes an IAM role** and gets temporary credentials.
4. **Terraform** runs and manages infrastructure securely.

> **Key tech:** Terraform, GitHub Actions, OIDC, No static AWS keys

---

## 1️⃣ AWS Setup

### a. Create a Secure S3 Bucket (for Terraform state)

- Go to the AWS Console → S3 → Create bucket  
  - Name: `my-secure-tf-state-235423434`
  - Enable **encryption** (default SSE)
  - Block **all public access**

---

### b. Add an OIDC Identity Provider in IAM

- AWS Console → IAM → Identity providers → **Add provider**
  - **Provider type:** OIDC
  - **Provider URL:** `https://token.actions.githubusercontent.com`
  - **Audience:** `sts.amazonaws.com`

---

### c. Create an IAM Role for GitHub Actions

Replace `<ACCOUNT_ID>`, `<OWNER>`, `<REPO>` below:

<details>
<summary>Trust Policy Example</summary>

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>/*"
    }
  }
}
```
</details>

**Attach a least-privilege policy** (allow only access to your bucket):

<details>
<summary>Example Policy</summary>

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::my-secure-tf-state-235423434",
                "arn:aws:s3:::my-secure-tf-state-235423434/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::amr-terraform-test-bucket-3412432535",
                "arn:aws:s3:::amr-terraform-test-bucket-3412432535/*"
            ]
        }
    ]
}
```
</details>

---

## 2️⃣ Write the Terraform

See [`main.tf`](./main.tf), [`backend.tf`](./backend.tf), and [`provider.tf`](./provider.tf) for the full Terraform configuration.

**Example:**

<details>
<summary>S3 bucket (Excerpt from <code>main.tf</code>)</summary>

```hcl
resource "aws_s3_bucket" "test_bucket" {
  bucket = "amr-terraform-test-bucket-3412432535"
  force_destroy = true
}
```
</details>

<details>
<summary>S3 Backend (Excerpt from <code>backend.tf</code>)</summary>

```hcl
terraform {
  backend "s3" {
    bucket = "my-secure-tf-state"
    key    = "github/oidc-demo.tfstate"
    region = "us-east-1"
  }
}
```
</details>

> **Tip:**  
> - Always enable S3 bucket versioning and encryption.  
> - Add `provider "aws"` and region blocks as needed (see [`provider.tf`](./provider.tf)).

---

## 3️⃣ GitHub Actions Workflow

The complete workflow is in [`.github/workflows/plan-apply.yml`](.github/workflows/plan-apply.yml).

### a. Store Role ARN as a Secret

- Go to: **GitHub repo → Settings → Secrets and variables → Actions**
- New repository secret:  
  - **Name:** `AWS_ROLE_ARN`
  - **Value:** *(Paste your IAM role ARN from above)*

---

### b. Create Workflow File

See the full workflow in [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).

<details>
<summary>Excerpt from workflow</summary>

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]
  pull_request:

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      # ...existing steps...
```
</details>

---

## 4️⃣ Enable GitHub Branch Protection

- Go to: **Settings → Branches → Add rule**
  - Rule pattern: `main`
  - Enable:
    - ✔️ Require a pull request before merging
    - ✔️ Require approvals
    - ✔️ Dismiss stale pull request approvals when new commits are pushed
    - ✔️ Require approval of the most recent reviewable push
    - ✔️ Require status checks to pass before merging
    - ✔️ Require branches to be up to date before merging
    - ✔️ Require conversation resolution before merging
    - ✔️ Require signed commits
    - ✔️ Require linear history

---

## 🚀 Demo (How This Works)

- Open a PR → Workflow runs `terraform plan` and comments the plan
- Merge to `main` → Workflow runs `terraform apply`
- Check AWS Console → Resource appears (e.g., SSM parameter)

---

## 🔒 Security Notes

- **No static AWS keys** anywhere.
- OIDC tokens are short-lived.
- S3 state is private, encrypted, and versioned.
- Branch protection enforces a secure and collaborative workflow by requiring code reviews, status checks, and other safeguards before changes reach your main branch.
- **Note:** In this demo, admins are allowed to bypass branch protection for demonstration purposes. In a real production environment, you should disable this option to maximize security.

---

## ⭐ Recap

- **Created**: Secure IAM role & OIDC setup
- **Built**: GitHub Actions workflow with OIDC authentication
- **Stored**: Terraform state in secure, private S3
- **Protected**: Your main branch with GitHub branch protection
