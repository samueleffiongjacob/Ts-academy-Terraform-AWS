# Default / dev values. Loaded automatically by `terraform plan|apply`.
# =============================================================================
#  SSH KEY - EDIT HERE  (this is the only place you need to touch to SSH in)
# =============================================================================
#  1. Put your key in WSL and lock it down:
#       cp /mnt/c/<where-you-saved>/devop-aws-ssh.pem ~/.ssh/
#       chmod 400 ~/.ssh/devop-aws-ssh.pem
#  2. Set the three values below.
key_name             = "devop-aws-ssh"                 # key pair name in AWS (no .pem)
ssh_private_key_path = "~/.ssh/devop-aws-ssh.pem"      # where the .pem is on your machine
create_key_pair      = false                           # false = key pair already exists in AWS (eu-north-1)
#                                                        true  = Terraform uploads the public key below
# ssh_public_key_path = "~/.ssh/devop-aws-ssh.pub"     # only used when create_key_pair = true
#                                                        make it: ssh-keygen -y -f ~/.ssh/devop-aws-ssh.pem > ~/.ssh/devop-aws-ssh.pub
ssh_user             = "ubuntu"
ssh_allowed_cidrs    = ["0.0.0.0/0"]                   # SSH open to everyone, as requested (tighten later)
# =============================================================================

aws_region   = "eu-north-1"
project_name = "ts-academy"
environment  = "dev"

# Network
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-north-1a", "eu-north-1b"]
enable_nat_gateway = true
# ssh_allowed_cidrs  = []   # e.g. ["203.0.113.10/32"]
backend_port       = 8080 #443 <---- before

# Automatic deployment
run_ansible = true            # runs ../ansible/playbook.yml once the servers exist

# Compute
ami_name_filter        = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"
frontend_instance_type = "m7i-flex.large"
backend_instance_type  = "m7i-flex.large"
root_volume_size       = 20
# key_name             = "my-key-pair"

# Database (no password here: RDS generates it and keeps it in Secrets Manager)
db_name                  = "my_ts_db"
db_username              = "mytsuser"
db_engine_version        = "8.4"
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false
db_skip_final_snapshot   = true
