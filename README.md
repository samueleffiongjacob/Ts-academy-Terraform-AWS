# Ts Academy test project

```
ts-academy/
  terraform/   AWS: VPC, 2 EC2 servers, RDS MySQL  (+ starts Ansible when ready)
  ansible/     installs Docker + k3s on both servers, builds images, deploys the app
  frontend/    Next.js app (Dockerfile included)
  backend/     Java 21 / Spring Boot API (Dockerfile included)
```

## Where to put the SSH key
`terraform/terraform.tfvars` -> section **SSH KEY - EDIT HERE**
(`key_name`, `ssh_private_key_path`, `create_key_pair`).

## Run
```bash
sudo apt install -y ansible          # once
cp /mnt/c/<path>/devop-aws-ssh.pem ~/.ssh/ && chmod 400 ~/.ssh/devop-aws-ssh.pem
cd terraform
terraform init -upgrade
terraform apply                      # builds AWS, then runs ansible automatically
```

## Log in and check
```bash
cd ..                                              # project root
ssh -F ssh_config.generated ts-frontend            # frontend / k3s server
ssh -F ssh_config.generated ts-backend             # backend (via the frontend)
ssh -F ssh_config.generated ts-frontend 'sudo k3s kubectl -n tsapp get pods -o wide'
```

## Re-deploy after changing code
`terraform apply` again, or, from `ansible/`:
`ansible-playbook playbook.yml -e @vars.generated.yml`
