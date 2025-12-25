variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "k3s_token" {
  type      = string
  sensitive = true
}