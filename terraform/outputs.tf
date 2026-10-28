output "app_url" {
  description = "Open in a browser after the Ansible deployment finishes."
  value       = "http://${aws_instance.ts_frontend_server.public_ip}"
}

output "ssh_frontend" {
  description = "SSH into the frontend / k3s server."
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${aws_instance.ts_frontend_server.public_ip}"
}

output "ssh_backend" {
  description = "SSH into the private backend through the frontend (jump host)."
  value       = "ssh -i ${var.ssh_private_key_path} -J ${var.ssh_user}@${aws_instance.ts_frontend_server.public_ip} ${var.ssh_user}@${aws_instance.ts_backend_server.private_ip}"
}

output "ssh_shortcuts" {
  description = "Same thing with the generated ssh config (run from the project root)."
  value       = "ssh -F ssh_config.generated ts-frontend   |   ssh -F ssh_config.generated ts-backend"
}

output "ssh_database_tunnel" {
  description = "RDS has no SSH. Open a tunnel through the frontend, then: mysql -h 127.0.0.1 -u <user> -p"
  value       = "ssh -i ${var.ssh_private_key_path} -N -L 3306:${aws_db_instance.ts_db.address}:3306 ${var.ssh_user}@${aws_instance.ts_frontend_server.public_ip}"
}

output "check_cluster" {
  description = "Check the Kubernetes pods from the frontend server."
  value       = "ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${aws_instance.ts_frontend_server.public_ip} 'sudo k3s kubectl -n tsapp get pods -o wide'"
}

output "db_password" {
  description = "Generated DB password (terraform output -raw db_password)."
  value       = random_password.db.result
  sensitive   = true
}
output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.ts_vpc.id
}

output "public_subnet_id" {
  description = "Public (frontend) subnet ID."
  value       = aws_subnet.ts_public_subnet.id
}

output "private_subnet_id" {
  description = "Private (backend) subnet ID."
  value       = aws_subnet.ts_private_subnet.id
}

output "database_subnet_ids" {
  description = "Database subnet IDs."
  value       = aws_subnet.ts_database_subnet[*].id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT gateway (null if disabled)."
  value       = one(aws_eip.ts_nat_eip[*].public_ip)
}

output "security_group_ids" {
  description = "Security group IDs by tier."
  value = {
    frontend = aws_security_group.frontend.id
    backend  = aws_security_group.backend.id
     k8s_nodes = aws_security_group.k8s_nodes.id
    database = aws_security_group.database.id
  }
}

output "ami_id" {
  description = "Ubuntu AMI resolved by the data source."
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "Name of the resolved AMI."
  value       = data.aws_ami.ubuntu.name
}

output "frontend_instance_id" {
  description = "Frontend EC2 instance ID."
  value       = aws_instance.ts_frontend_server.id
}

output "frontend_public_ip" {
  description = "Frontend public IP."
  value       = aws_instance.ts_frontend_server.public_ip
}

output "frontend_public_dns" {
  description = "Frontend public DNS name."
  value       = aws_instance.ts_frontend_server.public_dns
}

output "backend_instance_id" {
  description = "Backend EC2 instance ID."
  value       = aws_instance.ts_backend_server.id
}

output "backend_private_ip" {
  description = "Backend private IP."
  value       = aws_instance.ts_backend_server.private_ip
}

output "db_endpoint" {
  description = "RDS endpoint (host:port)."
  value       = aws_db_instance.ts_db.endpoint
}

output "db_address" {
  description = "RDS hostname."
  value       = aws_db_instance.ts_db.address
}

output "db_port" {
  description = "RDS port."
  value       = aws_db_instance.ts_db.port
}

output "db_name" {
  description = "Initial database name."
  value       = aws_db_instance.ts_db.db_name
}

output "db_master_secret_arn" {
  description = "Secrets Manager ARN holding the generated DB master password."
  value       = aws_db_instance.ts_db.master_user_secret[0].secret_arn
}
