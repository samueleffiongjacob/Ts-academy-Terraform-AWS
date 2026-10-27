# ---------------------------------------------------------------------------
# Hands the new servers over to Ansible.
#   1. writes ansible/inventory.ini and ansible/vars.generated.yml
#   2. writes ssh_config.generated  (so you can: ssh -F ssh_config.generated ts-frontend)
#   3. runs ansible-playbook, which waits until the servers accept SSH and then
#      installs Docker + k3s, builds the images and deploys the app.
# Needs ansible on the machine running terraform:  sudo apt install -y ansible
# ---------------------------------------------------------------------------

resource "random_password" "k3s_token" {
  length  = 40
  special = false
}

locals {
  repo_dir    = abspath("${path.module}/..")
  ansible_dir = "${local.repo_dir}/ansible"
  key_path    = pathexpand(var.ssh_private_key_path)

  frontend_files = setunion(
    fileset("${local.repo_dir}/frontend", "*"),
    fileset("${local.repo_dir}/frontend", "app/**"),
    fileset("${local.repo_dir}/frontend", "public/**"),
  )
  backend_files = setunion(
    fileset("${local.repo_dir}/backend", "*"),
    fileset("${local.repo_dir}/backend", "src/**"),
  )
  ansible_files = setunion(
    fileset(local.ansible_dir, "playbook.yml"),
    fileset(local.ansible_dir, "ansible.cfg"),
    fileset(local.ansible_dir, "tasks/**"),
    fileset(local.ansible_dir, "templates/**"),
  )

  frontend_hash = sha1(join("", [for f in sort(tolist(local.frontend_files)) : filesha1("${local.repo_dir}/frontend/${f}")]))
  backend_hash  = sha1(join("", [for f in sort(tolist(local.backend_files)) : filesha1("${local.repo_dir}/backend/${f}")]))
  ansible_hash  = sha1(join("", [for f in sort(tolist(local.ansible_files)) : filesha1("${local.ansible_dir}/${f}")]))
}

resource "local_file" "ansible_inventory" {
  filename = "${local.ansible_dir}/inventory.ini"
  content = templatefile("${path.module}/templates/inventory.ini.tpl", {
    frontend_public_ip = aws_instance.ts_frontend_server.public_ip
    backend_private_ip = aws_instance.ts_backend_server.private_ip
    ssh_user           = var.ssh_user
    key_path           = local.key_path
  })
}

resource "local_sensitive_file" "ansible_vars" {
  filename        = "${local.ansible_dir}/vars.generated.yml"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/ansible_vars.yml.tpl", {
    k3s_token           = random_password.k3s_token.result
    frontend_public_ip  = aws_instance.ts_frontend_server.public_ip
    frontend_private_ip = aws_instance.ts_frontend_server.private_ip
    backend_port        = var.backend_port
    db_host             = aws_db_instance.ts_db.address
    db_port             = aws_db_instance.ts_db.port
    db_name             = var.db_name
    db_user             = var.db_username
    db_password         = random_password.db.result
  })
}

resource "local_file" "ssh_config" {
  filename = "${local.repo_dir}/ssh_config.generated"
  content = templatefile("${path.module}/templates/ssh_config.tpl", {
    frontend_public_ip = aws_instance.ts_frontend_server.public_ip
    backend_private_ip = aws_instance.ts_backend_server.private_ip
    ssh_user           = var.ssh_user
    key_path           = local.key_path
  })
}

resource "terraform_data" "ansible_deploy" {
  count = var.run_ansible ? 1 : 0

  # Re-runs whenever a server is replaced or any app / ansible file changes.
  triggers_replace = [
    aws_instance.ts_frontend_server.id,
    aws_instance.ts_backend_server.id,
    aws_db_instance.ts_db.address,
    local.frontend_hash,
    local.backend_hash,
    local.ansible_hash,
  ]

  provisioner "local-exec" {
    working_dir = local.ansible_dir
    command     = "ansible-playbook playbook.yml -e @vars.generated.yml"
    environment = {
      ANSIBLE_CONFIG = "${local.ansible_dir}/ansible.cfg"
    }
  }

  depends_on = [
    local_file.ansible_inventory,
    local_sensitive_file.ansible_vars,
    aws_route.ts_private_nat, # the private backend needs the NAT to download packages
    aws_db_instance.ts_db,
  ]
}
