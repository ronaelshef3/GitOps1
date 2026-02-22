resource "aws_security_group" "k3s_sg" {
  vpc_id      = var.vpc_id
  name        = "sg_k3s_${var.env_name}"
  description = "Security group for K3s cluster with Ingress support"

  # ---  (Ingress) ---

  # 1.  (HTTP)
  #
  # -Ingress Controller
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 2. (HTTPS)
  #  SSL
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # מאפשר לכל העולם (לצורך הניסוי)
  }
# K3s API - אם תרצה להריץ kubectl מהמחשב האישי
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # 3. ArgoCD UI (NodePort)
  #
  # ArgoCD UI (NodePort) - חייב להיות תואם לסקריפט ה-Bash!
  ingress {
    from_port   = 30007
    to_port     = 30007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 4.
  #
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
# 2. Grafana - לוחות בקרה
  ingress {
    from_port   = 30001
    to_port     = 30001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 3. Prometheus - ממשק המטריקות
  ingress {
    from_port   = 30002
    to_port     = 30002
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 4. QuakeWatch - האפליקציה שלך
  ingress {
    from_port   = 30085
    to_port     = 30085
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ---(Egress) ---

  # DockerHub -S3
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-k3s-${var.env_name}"
  }
}

output "k3s_sg_id" {
  value       = aws_security_group.k3s_sg.id
  description = "The ID of the security group for use in the compute module"
}