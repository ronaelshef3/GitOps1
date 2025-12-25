data "aws_ami" "ubuntu_search" {
  most_recent = true
  owners      = ["099720109477"] # המזהה הרשמי של Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "k3s_node" {
  ami           =data.aws_ami.ubuntu_search.id # Ubuntu 22.04 LTS
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  # Automation to prevent human error during installation [cite: 519]
  user_data = <<-EOF
            #!/bin/bash
            PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

            curl -sfL https://get.k3s.io | K3S_TOKEN="${var.k3s_token}" sh -s - server \
            --tls-san $PUBLIC_IP \
            --write-kubeconfig-mode 644 \
            --node-external-ip $PUBLIC_IP


            EOF
  tags = { Name = "QuakeWatch1-${var.env_name}" }
}

#  Networking and Security [cite: 195]
resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg1-${var.env_name}"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30007
    to_port     = 30007
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # מומלץ להחליף ב-IP שלך ליתר ביטחון
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# modules/argocd/main.tf

