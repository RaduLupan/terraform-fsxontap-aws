provider "aws" {
  region = var.region
}

# Calculated local values.
locals {
  vpc_id = data.aws_subnet.selected.vpc_id

  ubuntu_ami_id            = var.ubuntu_ami_id == null ? data.aws_ami.amazon_linux[0].id : var.ubuntu_ami_id
  count_ami_amazon_linux = var.ubuntu_ami_id == null ? 1 : 0

  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]

  ssh_port = 22

  ssh_allowed_cidr = var.ssh_allowed_cidr == null ? local.all_ips[0] : var.ssh_allowed_cidr

  common_tags = {
    terraform   = true
    environment = var.environment
  }
}