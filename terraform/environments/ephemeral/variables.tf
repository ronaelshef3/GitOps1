variable "aws_region" {
  type        = string
  description = "The AWS region to deploy the K3s cluster"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the K3s server"
  default     = "t3.small"
}

variable "env_name" {
  type        = string
  description = "Environment name (e.g., ephemeral, dev, prod)"
  default     = "ephemeral"
}

variable "k3s_token" {
  type        = string
  sensitive   = true
  description = "K3s cluster token to join nodes"
}

variable "aws_pass" {
  type        = string
  sensitive   = true
  description = "Database password for Kubernetes secret"
  default     = "1234"
}

variable "k3s_ca_cert" {
  type        = string
  description = "CA certificate from K3s kubeconfig (PEM format)"
}

variable "k3s_client_cert" {
  type        = string
  description = "Client certificate from K3s kubeconfig (PEM format)"
}

variable "k3s_client_key" {
  type        = string
  description = "Client key from K3s kubeconfig (PEM format)"
}
variable "key_name" {
  type        = string
  description = "EC2 Key Pair name to use"
  default     = "DevOps1808"
}
variable "private_key_path" {
  type        = string
  description = "הנתיב לקובץ המפתח הפרטי במחשב שלך"
}