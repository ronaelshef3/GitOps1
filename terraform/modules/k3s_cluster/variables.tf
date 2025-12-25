variable "aws_region" { type = string }
variable "instance_type" { type = string }
variable "env_name" { type = string }
variable "k3s_token" {
  type      = string
  sensitive = true
}