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
  region = "us-east-1"
}


# Create a VPC
resource "aws_vpc" "ts_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "ts_public_subnet" {
  vpc_id     = aws_vpc.ts_vpc.id
  cidr_block        	= "${cidrsubnet(aws_vpc.ts_vpc.cidr_block, 3, 1)}"

  tags = {
    Name = "ts public subnet"
  }
}

resource "aws_subnet" "ts_private_subnet" {
  availability_zone = "us-east-1a"
  vpc_id     = aws_vpc.ts_vpc.id
  cidr_block        	= "${cidrsubnet(aws_vpc.ts_vpc.cidr_block, 5, 1)}"

  tags = {
    Name = "ts private subnet"
  }
}

resource "aws_subnet" "ts_database_subnet" {
  vpc_id     = aws_vpc.ts_vpc.id
  availability_zone = "us-east-1b"
  cidr_block        	= "${cidrsubnet(aws_vpc.ts_vpc.cidr_block, 7, 1)}"
 
  tags = {
    Name = "ts database subnet"
  }
}

resource "aws_internet_gateway" "ts_gw" {
  vpc_id = aws_vpc.ts_vpc.id

  tags = {
    Name = "ts igw"
  }
}

resource "aws_route_table" "ts_public_rt" {
  vpc_id = aws_vpc.ts_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ts_gw.id
  }


  tags = {
    Name = "ts public rt"
  }
}

resource "aws_route_table" "ts_private_rt" {
  vpc_id = aws_vpc.ts_vpc.id



  tags = {
    Name = "example"
  }
}

resource "aws_route_table" "ts_database_rt" {
  vpc_id = aws_vpc.ts_vpc.id


  tags = {
    Name = "database rt"
  }
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
  subnet_id      = aws_subnet.ts_database_subnet.id
  route_table_id = aws_route_table.ts_database_rt.id
}

resource "aws_eip" "example" {
  count  = 2
  domain = "vpc"
}

resource "aws_nat_gateway" "ts_ng" {
  subnet_id     = aws_subnet.ts_public_subnet.id
  allocation_id   = aws_eip.example[0].id

  tags = {
    Name = "gw NAT"
  }
  depends_on = [aws_internet_gateway.ts_gw]
}

resource "aws_default_security_group" "public_server" {
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

resource "aws_default_security_group" "private_server" {
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


resource "aws_default_security_group" "database_server" {
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


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ts_frontend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_default_security_group.public_server.id]
  tags = {
    Name = "frontend server"
  }
}

resource "aws_instance" "ts_backend_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_default_security_group.private_server.id]

  tags = {
    Name = "backend server"
  }
}

resource "aws_db_subnet_group" "ts_rds_subnet_group" {
  name       = "ts_subnet"
  subnet_ids = [aws_subnet.ts_private_subnet.id, aws_subnet.ts_database_subnet.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "ts_db" {
  allocated_storage    = 10
  db_name              = "my_ts_db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  username             =  "mytsuser"
  password             = "foobarbaz"
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
}
