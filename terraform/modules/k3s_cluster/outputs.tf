output "public_ip" { value = aws_instance.k3s_node.public_ip }
output "k3s_node_id" {
  value = aws_instance.k3s_node.id
}