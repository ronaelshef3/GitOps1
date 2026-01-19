data "aws_ami" "ubuntu_search" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "k3s_node" {
  ami           = data.aws_ami.ubuntu_search.id
  instance_type = var.instance_type
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    # 1. הגדרת טוקן קבוע (מהמשתנים שלך)
    mkdir -p /etc/rancher/k3s
    echo "${var.k3s_token}" > /etc/rancher/k3s/cluster-token

    # 2. install  K3s
    # שים לב ל-write-kubeconfig-mode - זה קריטי כדי שה-PS1 יוכל למשוך את הקובץ
    curl -sfL https://get.k3s.io | K3S_TOKEN="${var.k3s_token}" sh -s - server \
      --write-kubeconfig-mode 644 \
      --disable traefik
  EOF
  provisioner "local-exec" {
    when    = destroy
    interpreter = ["PowerShell", "-Command"]
    command = <<EOT
    # if (!(Test-Path "../../local_backups/logs")) { New-Item -ItemType Directory -Path "../../local_backups/logs" -Force }
    # scp -o StrictHostKeyChecking=no -i C:/Users/USER/DevOps1808.pem ubuntu@${self.public_ip}:/var/log/syslog ../../local_backups/logs/syslog.log
  EOT

  }
  tags = {
    Name    = "K3s-${var.env_name}"
    KeyPath = var.private_key_path
  }

}

resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg1-${var.env_name}"
  tags = {
    Name = "K3s-sg1-${var.env_name}"
  }
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }# חור מאובטח רק אליך!  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30007
    to_port     = 30008
    protocol    = "tcp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  # Your Application UI (The port you requested)
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Grafana UI (NodePort)
ingress {
  from_port   = 32000 # נשתמש בפורט הזה עבור גרפאנה
  to_port     = 32000
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# Redis Access
ingress {
  from_port   = 30379 # נשתמש בפורט הזה עבור רדיס
  to_port     = 30379
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}