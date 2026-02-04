# QuakeWatch Infrastructure

This project automates the deployment of the QuakeWatch system using Terraform and AWS. It features a Zero-Cleartext security model, ensuring AWS secrets are never stored on disk in plain text or committed to Git.

## The Vault Logic

---

## Security Rationale: Identity vs. Secret
To protect our infrastructure, we use a session-based security approach:
1. **At Rest:** The AWS Secret Key is stored encrypted within the **Windows Credential Manager**.
2. **In Motion:** Secrets are injected directly into the volatile memory (**RAM**) of the current terminal session.
3. **Identity Partitioning:** We distinguish between **Public Identity** (Access Key ID) and **Private Signature** (Secret Key) to minimize the attack surface.

---

## 🛠 Setup Guide (One-Time)

To prepare your machine for deployment without exposing keys in plain text:

### 1. Generate AWS Keys
- Log in to **AWS Console** -> **IAM** -> **Security Credentials**.
- Create a new **Access Key** for CLI usage.

### 2. Run the Secure Setup Script
Run the `Setup-AWS.ps1` script. It will prompt you for your keys via a masked input and configure the Windows Vault automatically:
```powershell
.\Setup-AWS.ps1

```

### 4  Restart Environment
Critical: Restart your IDE (PyCharm) or Terminal to ensure Windows 
refreshes and recognizes the new Environment Variables.



### 5. Daily Workflow (In PyCharm)
Every time you open your IDE, run the unified unlock script:

. .\Unlock-AWS.ps1

The script will:
- Extract Secret Key from Vault.
- Validate Public Key.
- Perform 'aws sts get-caller-identity' test.

---

## Project Structure and Deployment

### Directory Layout
- /terrform1: Infrastructure as Code (Modularized with modules and environments).
- /app-manifests: Kubernetes deployment charts.
  - /quakewatch-chart: Main application Helm chart.
- /infrastructure: Supporting services.
  - /redis: Redis configuration.
  - /monitoring: Monitoring stack.

### Helm Values Management
We use a layered Values approach:
1. Base values.yaml: Common configurations.
2. Environment-specific: (e.g., values-prod.yaml) for scaling/limits.
3. Secrets: Injected via Kubernetes Secrets (not stored in values files).

---

## TODO List for Implementation

### Infrastructure (Terraform)
- [ ] TODO: Define VPC and Subnet structure in modules.
- [ ] TODO: Configure EC2 instance type and AMI ID.
- [ ] 
- [ ] TODO: Add Security Group rules for Port 80, 22, and ArgoCD (30007).

### Application Deployment (Helm)
- [ ] TODO: Define resource limits (CPU/Memory) in quakewatch-chart/values.yaml.
- [ ] TODO: Map environment variables for Database and Redis connections.
- [ ] 

### GitOps (ArgoCD)
- [ ] TODO: Define the Application manifest to track the /app-manifests directory.
- [ ] TODO: Set up automated sync policy in ArgoCD.

---

## Deployment Flow
1. Run . .\Unlock-AWS.ps1
2. cd terrform1
3. terraform apply
4. TODO: Verify Kubernetes node status (kubectl get nodes).
5. TODO: Access ArgoCD UI to monitor application sync.