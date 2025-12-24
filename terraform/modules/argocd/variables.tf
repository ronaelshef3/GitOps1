variable "host" {
  type        = string
  description = "The public IP of the k3s cluster"
  default     = ""  # <--- השורה הזו פותרת את השגיאה!
}