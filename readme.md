# QuakeWatch Infrastructure

This project automates the deployment of the QuakeWatch system using Terraform and AWS. It features a Zero-Cleartext security model, ensuring AWS secrets are never stored on disk in plain text or committed to Git.

## The Vault Logic
To protect our infrastructure, we use a hybrid Vault approach:
1. At Rest: The AWS Secret Key is stored encrypted within the Windows Credential Manager.
2. In Motion: Secrets are injected directly into the volatile memory (RAM) of the current terminal session.
3. Verification: Every session start includes a live handshake test with AWS to ensure connectivity.

---

## Security Rationale: Identity vs. Secret

The project distinguishes between the AWS Access Key ID and the AWS Secret Access Key for specific security reasons:

### 1. Access Key ID (Public Identity)
- Storage: Set as a standard System Environment Variable.
- Risk Level: Low. This is equivalent to a "username." It identifies the account but cannot perform actions on its own.
- Reason: Keeping it as a system variable allows IDEs and the AWS CLI to identify the context immediately.

### 2. Secret Access Key (Private Signature)
- Storage: Encrypted within the Windows Credential Manager (Vault).
- Risk Level: Critical. This is equivalent to a "password." Anyone with this key has full control over the account.
- Reason: By fetching it only via the Unlock-Vault.ps1 script, we ensure the secret exists only in the Volatile Memory (RAM) of the current terminal session and vanishes when the window is closed.

---

## Prerequisites

1. Terraform and AWS CLI installed.
2. BetterCredentials PowerShell module:
   Install-Module -Name BetterCredentials -Scope CurrentUser -Force

---

## Setup and Usage

### 1. First-Time Setup (Per Machine)
1. Vault Storage: Add a Generic Credential in Windows Credential Manager:
   - Internet Address: AWS_SECRET_ACCESS_KEY
   - Password: Your_AWS_Secret_Access_Key
2. Public Key: Set your AWS_ACCESS_KEY_ID as a standard System Environment Variable.

### 2. Daily Workflow (In PyCharm)
Every time you open your IDE, run the unified unlock script:

. .\Unlock-Vault.ps1

The script will:
- Extract Secret Key from Vault.
- Validate Public Key.
- Perform 'aws sts get-caller-identity' test.

---

## Project Structure and Deployment

### Directory Layout
- /terraform: Infrastructure as Code (VPC, EC2, Security Groups).
- /helm: Kubernetes deployment charts.
  - /app-chart: Main application manifests.
  - /infrastructure-chart: Supporting services (Redis, DB).
- /k8s: ArgoCD Application manifests (GitOps).

### Helm Values Management
We use a layered Values approach:
1. Base values.yaml: Common configurations.
2. Environment-specific: (e.g., values-prod.yaml) for scaling/limits.
3. Secrets: Injected via Kubernetes Secrets (not stored in values files).

---

## TODO List for Implementation

### Infrastructure (Terraform)
- [ ] TODO: Define VPC and Subnet structure in main.tf.
- [ ] TODO: Configure EC2 instance type and AMI ID.
- [ ] 
- [ ] TODO: Add Security Group rules for Port 80, 22, and ArgoCD (30007).

### Application Deployment (Helm)
- [ ] TODO: Define resource limits (CPU/Memory) in app-chart/values.yaml.
- [ ] TODO: Map environment variables for Database and Redis connections.
- [ ] 

### GitOps (ArgoCD)
- [ ] TODO: Define the Application manifest in /k8s to track the /helm directory.
- [ ] TODO: Set up automated sync policy in ArgoCD.

---

## Deployment Flow
1. Run . .\Unlock-Vault.ps1
2. cd terraform
3. terraform apply
4. TODO: Verify Kubernetes node status (kubectl get nodes).
5. TODO: Access ArgoCD UI to monitor application sync.