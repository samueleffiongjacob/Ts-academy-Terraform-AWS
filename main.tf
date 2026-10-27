terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "ts_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

# Public subnet: frontend
resource "aws_subnet" "ts_public_subnet" {
  vpc_id                  = aws_vpc.ts_vpc.id
  availability_zone       = var.availability_zones[0]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-frontend" }
}

# Private subnet: backend
resource "aws_subnet" "ts_private_subnet" {
  vpc_id            = aws_vpc.ts_vpc.id
  availability_zone = var.availability_zones[0]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)

  tags = { Name = "${local.name_prefix}-private-backend" }
}

# Private subnets: database (RDS needs subnets in at least 2 AZs)
resource "aws_subnet" "ts_database_subnet" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.ts_vpc.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + count.index)

  tags = { Name = "${local.name_prefix}-private-database-${count.index + 1}" }
}

# ---------------------------------------------------------------------------
# Internet gateway, NAT gateway, routing
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "ts_igw" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = { Name = "${local.name_prefix}-igw" }
}

resource "aws_eip" "ts_nat_eip" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags       = { Name = "${local.name_prefix}-nat-eip" }
  depends_on = [aws_internet_gateway.ts_igw]
}

# One NAT gateway in the public subnet, shared by the private subnets.
resource "aws_nat_gateway" "ts_ng" {
  count         = var.enable_nat_gateway ? 1 : 0
  subnet_id     = aws_subnet.ts_public_subnet.id
  allocation_id = aws_eip.ts_nat_eip[0].id

  tags       = { Name = "${local.name_prefix}-nat" }
  depends_on = [aws_internet_gateway.ts_igw]
}

resource "aws_route_table" "ts_public_rt" {
  vpc_id = aws_vpc.ts_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ts_igw.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table" "ts_private_rt" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route" "ts_private_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.ts_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.ts_ng[0].id
}

resource "aws_route_table" "ts_database_rt" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = { Name = "${local.name_prefix}-database-rt" }
}

resource "aws_route_table_association" "ts_public_association" {
  subnet_id      = aws_subnet.ts_public_subnet.id
  route_table_id = aws_route_table.ts_public_rt.id
}

resource "aws_route_table_association" "ts_private_association" {
  subnet_id      = aws_subnet.ts_private_subnet.id
  route_table_id = aws_route_table.ts_private_rt.id
}

resource "aws_route_table_association" "ts_database_association" {
  count          = length(aws_subnet.ts_database_subnet)
  subnet_id      = aws_subnet.ts_database_subnet[count.index].id
  route_table_id = aws_route_table.ts_database_rt.id
}

# ---------------------------------------------------------------------------
# Security groups (chained: internet -> frontend -> backend -> database)
# ---------------------------------------------------------------------------
resource "aws_security_group" "frontend" {
  name        = "${local.name_prefix}-frontend-sg"
  description = "Frontend: HTTP/HTTPS from the internet"
  vpc_id      = aws_vpc.ts_vpc.id

  ingress {
    description = "HTTP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      description = "SSH from allowed CIDRs"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      cidr_blocks = var.ssh_allowed_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-frontend-sg" }
}

resource "aws_security_group" "backend" {
  name        = "${local.name_prefix}-backend-sg"
  description = "Backend: SSH and app port from the frontend (jump host) only"
  vpc_id      = aws_vpc.ts_vpc.id

  ingress {
    description     = "SSH via the frontend jump host"
    protocol        = "tcp"
    from_port       = 22
    to_port         = 22
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description     = "App port from frontend"
    protocol        = "tcp"
    from_port       = var.backend_port
    to_port         = var.backend_port
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-backend-sg" }
}

# Attached to both EC2 instances: lets k3s API (6443), flannel VXLAN (8472/udp),
# kubelet (10250) and pod traffic flow between the two nodes.
resource "aws_security_group" "k8s_nodes" {
  name        = "${local.name_prefix}-k8s-nodes-sg"
  description = "k3s node-to-node traffic"
  vpc_id      = aws_vpc.ts_vpc.id

  ingress {
    description = "All traffic between k3s nodes"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name_prefix}-k8s-nodes-sg" }
}
resource "aws_security_group" "database" {
  name        = "${local.name_prefix}-database-sg"
  description = "Database: MySQL from the backend only"
  vpc_id      = aws_vpc.ts_vpc.id

  ingress {
    description     = "MySQL from backend"
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [aws_security_group.backend.id]
  }

  tags = { Name = "${local.name_prefix}-database-sg" }
}

# ===========================================================================
# SSH KEY PAIR  <-- this is what lets you SSH into the servers
#
# The values come from terraform.tfvars, section "SSH KEY - EDIT HERE":
#   key_name             name of the key pair in AWS (devop-aws-ssh, no .pem)
#   ssh_private_key_path where devop-aws-ssh.pem is on YOUR machine (WSL)
#   create_key_pair      false = the key pair already exists in AWS (default)
#                        true  = Terraform uploads ssh_public_key_path to AWS
# ===========================================================================
resource "aws_key_pair" "ssh" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

locals {
  ssh_key_name = var.create_key_pair ? aws_key_pair.ssh[0].key_name : var.key_name
}
# ---------------------------------------------------------------------------
# AMI + EC2
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "ts_frontend_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.frontend_instance_type
  subnet_id                   = aws_subnet.ts_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true
  key_name                    = local.ssh_key_name # <-- your devop-aws-ssh key pair is attached HERE

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
  }

  tags = { Name = "${local.name_prefix}-frontend-server" }
}

resource "aws_instance" "ts_backend_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.ts_private_subnet.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = local.ssh_key_name # <-- your devop-aws-ssh key pair is attached HERE

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size
  }

  tags = { Name = "${local.name_prefix}-backend-server" }
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------
# A plain generated password (not RDS-managed) because the app reads it from a
# Kubernetes Secret; RDS-managed passwords auto-rotate and would break the app.
resource "random_password" "db" {
  length  = 24
  special = false
}
resource "aws_db_subnet_group" "ts_rds_subnet_group" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = aws_subnet.ts_database_subnet[*].id

  tags = { Name = "${local.name_prefix}-db-subnet-group" }
}

resource "aws_db_instance" "ts_db" {
  identifier        = "${local.name_prefix}-db"
  allocated_storage = var.db_allocated_storage
  storage_encrypted = true
  db_name           = var.db_name
  engine            = "mysql"
  engine_version    = var.db_engine_version
  instance_class    = var.db_instance_class

  username                    = var.db_username
  password = random_password.db.result
  # manage_master_user_password = true # password generated and stored in Secrets Manager

  parameter_group_name   = "default.mysql${var.db_engine_version}"
  db_subnet_group_name   = aws_db_subnet_group.ts_rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period   = var.db_backup_retention_days
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = var.db_skip_final_snapshot
  final_snapshot_identifier = var.db_skip_final_snapshot ? null : "${local.name_prefix}-db-final"

  tags = { Name = "${local.name_prefix}-db" }
}
