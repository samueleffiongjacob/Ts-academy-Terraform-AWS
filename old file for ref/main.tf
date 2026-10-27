# Start with provide
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-north-1"
}


# Create a VPC
resource "aws_vpc" "ts_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Ts Academy VPC"
  }
}

# Create A public Subnet Frontend Application
resource "aws_subnet" "ts_public_subnet" {
  availability_zone = "eu-north-1a"
  vpc_id     = aws_vpc.ts_vpc.id
  cidr_block        	= "${cidrsubnet(aws_vpc.ts_vpc.cidr_block, 3, 1)}"

  tags = {
    Name = "Ts Academy VPC Public Subnet Frontend Application"
  }
}

# Create A private Subnet Backend Application
resource "aws_subnet" "ts_private_subnet" {
  availability_zone = "eu-north-1b"
  vpc_id     = aws_vpc.ts_vpc.id
  cidr_block        	= "${cidrsubnet(aws_vpc.ts_vpc.cidr_block, 5, 1)}"

  tags = {
    Name = "Ts Academy VPC private subnet Backend Application"
  }
}

# Create A private Subnet Database Application
resource "aws_subnet" "ts_database_subnet" {
  vpc_id     = aws_vpc.ts_vpc.id
  availability_zone = "eu-north-1b"
  cidr_block        	= "${cidrsubnet(aws_vpc.ts_vpc.cidr_block, 7, 1)}"
 
  tags = {
    Name = "Ts Academy VPC Private subnet Database"
  }
}

# Ts Academy Internet Gateway
resource "aws_internet_gateway" "ts_igw" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = {
    Name = "Ts Academy Internet Gateway"
  }
}

# Create Route Tables Public Network
resource "aws_route_table" "ts_public_rt" {
  vpc_id = aws_vpc.ts_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ts_igw.id
  }

  tags = {
    Name = "Ts Academy Public Route Table"
  }
}

# Create Route Tables Private Network
resource "aws_route_table" "ts_private_rt" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = {
    Name = "Ts Academy Private Route Table"
  }
}

# Create Route Tables Database Network
resource "aws_route_table" "ts_database_rt" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = {
    Name = "Ts Academy Database Route Table"
  }
}
# Public Associate Route Tables with Subnets
resource "aws_route_table_association" "ts_public_association" {
  subnet_id      = aws_subnet.ts_public_subnet.id
  route_table_id = aws_route_table.ts_public_rt.id
}

# Private Associate Route Tables with Subnets
resource "aws_route_table_association" "ts_private_association" {
  subnet_id      = aws_subnet.ts_private_subnet.id
  route_table_id = aws_route_table.ts_private_rt.id
}

# Database Associate Route Tables with Subnets
resource "aws_route_table_association" "ts_database_association" {
  subnet_id      = aws_subnet.ts_database_subnet.id
  route_table_id = aws_route_table.ts_database_rt.id
}

# Create Elastic IP for Ts Academy NAT Gateway 
resource "aws_eip" "ts_academy_eip" {
  count  = 2 # number of NAT gateways to create
  domain = "vpc"
}

# Create Ts Academy NAT Gateway 
resource "aws_nat_gateway" "ts_ng" {
  subnet_id     = aws_subnet.ts_public_subnet.id
  # allocation_id   = aws_eip.ts_academy_eip[0].id # for single NAT gateway. when to use : when u have multiple private subnets that communicate with the public subnet.

  # for multiple NAT gateways
  # when to use : when u have only one private subnet that communicate with the public subnet.
  allocation_id   = aws_eip.ts_academy_eip[count.index].id 

  tags = {
    Name = "Ts Academy NAT Gateway ${count.index + 1}"
  }
  depends_on = [aws_internet_gateway.ts_igw]
}

# create a security group for the public server
resource "aws_default_security_group" "ts_academy_security_group_public_server" {
  vpc_id = aws_vpc.ts_vpc.id

  ingress {
    protocol  = "tcp"
    self      = true
    from_port = 80
    to_port   = 80
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create a security group for the private server
resource "aws_default_security_group" "ts_academy_security_group_private_server" {
  vpc_id = aws_vpc.ts_vpc.id

  ingress {
    protocol  = "tcp"
    self      = true
    from_port = 443
    to_port   = 443
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create a security group for the database server
resource "aws_default_security_group" "ts_academy_security_group_database_server" {
  vpc_id = aws_vpc.ts_vpc.id

  ingress {
    protocol  = "tcp"
    self      = true
    from_port = 3306
    to_port   = 3306
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create an AMI data source to get the latest Ubuntu 22.04 LTS image
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
    #values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["099720109477"] # Canonical
}

# create an EC2 instance for the frontend server
resource "aws_instance" "ts_frontend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  vpc_security_group_ids = [aws_default_security_group.ts_academy_security_group_public_server.id]
  tags = {
    Name = "Ts Academy frontend server"
  }
}

# create an EC2 instance for the backend server
resource "aws_instance" "ts_backend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "m7i-flex.large"
  vpc_security_group_ids = [aws_default_security_group.ts_academy_security_group_private_server.id]

  tags = {
    Name = "Ts Academy backend server"
  }
}

# create an subnet group for the database server
resource "aws_db_subnet_group" "ts_rds_subnet_group" {
  name       = "ts_subnet"
  subnet_ids = [aws_subnet.ts_private_subnet.id, aws_subnet.ts_database_subnet.id]

  tags = {
    Name = "Ts Academy DB subnet group"
  }
}

# create an RDS instance for the database server
resource "aws_db_instance" "ts_db" {
  allocated_storage    = 10
  db_name              = "my_ts_db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  db_subnet_group_name = aws_db_subnet_group.ts_rds_subnet_group.name
  username             =  "mytsuser"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
}
