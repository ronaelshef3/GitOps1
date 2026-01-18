variable "aws_region" {
  type = string
}
variable "instance_type" { type = string }
variable "env_name" { type = string }
variable "k3s_token" {
  type      = string
  sensitive = true
}
variable "key_name" {type = string}
variable "private_key_path" {
  type        = string
  description = "Path to the private key file (.pem) on your local machine"
}
# variable "env_name" {
#   type        = string
#   description = ""
# }