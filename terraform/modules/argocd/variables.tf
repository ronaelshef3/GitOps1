variable "host" {
  type        = string
  description = "The public IP of the k3s cluster"
  default     = ""  # <--- השורה הזו פותרת את השגיאה!
}
variable "k3s_node_id" {
  type        = string
  description = "The ID of the K3s server to ensure it is created before helm starts"
}