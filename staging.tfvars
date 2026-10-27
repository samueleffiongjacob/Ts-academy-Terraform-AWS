# Staging values. Use with: terraform plan -var-file=staging.tfvars
# -var-file is applied after terraform.tfvars, so these values override it.
# Use a separate workspace/state: terraform workspace new staging

# ============================ SSH KEY - EDIT HERE ============================
key_name             = "devop-aws-ssh"
ssh_private_key_path = "~/.ssh/devop-aws-ssh.pem"
create_key_pair      = false
ssh_user             = "ubuntu"
ssh_allowed_cidrs    = ["0.0.0.0/0"]
# =============================================================================

aws_region   = "eu-north-1"
project_name = "ts-academy"
environment  = "staging"

# Network (separate CIDR so it can be peered with dev later)
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["eu-north-1a", "eu-north-1b"]
enable_nat_gateway = true
# ssh_allowed_cidrs  = []
# backend_port       = 443
backend_port       = 8080 # below the 2 files are not present

run_ansible = true

# Compute
ami_name_filter        = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"
frontend_instance_type = "m7i-flex.large"
backend_instance_type  = "m7i-flex.large"
root_volume_size       = 30

# Database: closer to production behaviour
db_name                  = "my_ts_db"
db_username              = "mytsuser"
db_engine_version        = "8.4"
db_instance_class        = "db.t3.small"
db_allocated_storage     = 20
db_multi_az              = true
db_backup_retention_days = 7
db_deletion_protection   = true
db_skip_final_snapshot   = false
