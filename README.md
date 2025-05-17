# Deploy to AWS with Terraform Using GitHub Actions (Secure OIDC Setup)

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
  - Name: `my-secure-tf-state`
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

```json
{
  "Effect": "Allow",
  "Principal": {
    "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
  },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:ref:refs/heads/main"
    }
  }
}
```

**Attach a least-privilege policy** (allow only access to your bucket):

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
        "arn:aws:s3:::my-secure-tf-state",
        "arn:aws:s3:::my-secure-tf-state/*"
      ]
    }
  ]
}
```

---

## 2️⃣ Write the Terraform

**Example:**  
Create an SSM parameter, and configure the S3 backend.

```hcl
# main.tf
resource "aws_ssm_parameter" "example" {
  name  = "/demo/github-oidc"
  type  = "String"
  value = "deployed-from-oidc"
}

# backend.tf
terraform {
  backend "s3" {
    bucket = "my-secure-tf-state"
    key    = "github/oidc-demo.tfstate"
    region = "us-east-1"
  }
}
```

> **Tip:**  
> - Always enable S3 bucket versioning and encryption.
> - Add `provider "aws"` and region blocks as needed.

---

## 3️⃣ GitHub Actions Workflow

### a. Store Role ARN as a Secret

- Go to: **GitHub repo → Settings → Secrets and variables → Actions**
- New repository secret:  
  - **Name:** `AWS_ROLE_ARN`
  - **Value:** *(Paste your IAM role ARN from above)*

---

### b. Create Workflow File

Save as `.github/workflows/deploy.yml`:

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

      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan -no-color | tee plan.txt

      - name: Comment PR with Terraform Plan
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('plan.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `### Terraform Plan

\`\`\`${plan}\`\`\`
`
            });

      - name: Terraform Apply
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

---

## 4️⃣ Enable GitHub Branch Protection

- Go to: **Settings → Branches → Add rule**
  - Rule pattern: `main`
  - Enable:
    - ✔️ Require pull request reviews
    - ✔️ Require status checks
    - ✔️ Dismiss stale reviews

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
- Branch protection ensures no one (not even admins) can bypass PR review or the plan step.

---

## ⭐ Recap

- **Created**: Secure IAM role & OIDC setup
- **Built**: GitHub Actions workflow with OIDC authentication
- **Stored**: Terraform state in secure, private S3
- **Protected**: Your main branch with GitHub branch protection

---

## 📺 Like the flow? Star the repo!  
**Next:** Injecting secrets from SSM into GitHub Actions.
# SSH commit signing test
