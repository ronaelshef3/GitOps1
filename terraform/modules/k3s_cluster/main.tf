resource "aws_instance" "k3s_node" {
  ami           = "ami-0c55b159cbfafe1f0" # Ubuntu 22.04 LTS
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.k3s_sg.id]

  # Automation to prevent human error during installation [cite: 519]
  user_data = <<-EOF
              #!/bin/bash
              curl -sfL https://get.k3s.io | sh -
              export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
              kubectl create namespace argocd
              kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
              EOF

  tags = { Name = "QuakeWatch-${var.env_name}" }
}

#  Networking and Security [cite: 195]
resource "aws_security_group" "k3s_sg" {
  name = "k3s-sg-${var.env_name}"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}