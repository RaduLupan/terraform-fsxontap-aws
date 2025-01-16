provider "aws" {
  region = var.region
}

# Calculated local values.
locals {
  vpc_id = data.aws_subnet.ubuntu.vpc_id

  ubuntu_ami_id            = var.ubuntu_ami_id == null ? data.aws_ami.ubuntu[0].id : var.ubuntu_ami_id
  count_ubuntu_ami = var.ubuntu_ami_id == null ? 1 : 0

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

# Use this data source to retrieve details about a specific VPC subnet.
data "aws_subnet" "ubuntu" {
  id = var.ubuntu_subnet_id
}

# Use this data source to get the ID of a registered AMI for use in other resources.
data "aws_ami" "ubuntu" {
  count = local.count_ubuntu_ami

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"]
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

# Security group.
resource "aws_security_group" "ubuntu" {
  name   = "${var.ubuntu_name}-sg"
  vpc_id = local.vpc_id

  tags = {
    Name        = "${var.ubuntu_name}-sg"
    terraform   = true
    environment = var.environment
  }
}

# Ingress rule.
resource "aws_security_group_rule" "ingress" {
  type              = "ingress"
  description       = "Inbound SSH ${local.ssh_port}"
  security_group_id = aws_security_group.ubuntu.id

  from_port   = local.ssh_port
  to_port     = local.ssh_port
  protocol    = local.tcp_protocol
  cidr_blocks = [local.ssh_allowed_cidr]
}

# Egress rule: allow all outbound traffic.
resource "aws_security_group_rule" "allow_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.ubuntu.id

  from_port   = local.any_port
  to_port     = local.any_port
  protocol    = local.any_protocol
  cidr_blocks = local.all_ips
}

# Template file for the EC2 instance role trust policy.
data "template_file" "ec2_role_trust" {
  template = file("${path.module}/ec2-role-trust.json.tpl")
}

# Template file for the EC2 instance role IAM policy.
data "template_file" "ec2_role_policy" {
  template = file("${path.module}/ec2-role-policy.json.tpl")
}

# IAM instance role
resource "aws_iam_role" "main" {
  name = "fsxontap-client-role"
  path = "/"

  assume_role_policy = data.template_file.ec2_role_trust.rendered
  tags               = local.common_tags
}

# IAM instance policy.
resource "aws_iam_role_policy" "main" {
  name = "fsxontap-client-policy"
  role = aws_iam_role.main.id

  policy = data.template_file.ec2_role_policy.rendered
}

# Attach AWS SSM managed policy
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.main.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM instance profile.
resource "aws_iam_instance_profile" "main" {
  name = "fsxontap-client-profile"
  role = aws_iam_role.main.name
}

# EC2 instance for operations.
resource "aws_instance" "ubuntu" {
  ami           = local.ubuntu_ami_id
  instance_type = var.ubuntu_instance_type

  key_name               = var.key_name
  monitoring             = true
  subnet_id              = var.ubuntu_subnet_id
  vpc_security_group_ids = [aws_security_group.ubuntu.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = "50"
    encrypted   = "true"
  }

  #user_data = data.template_file.user_data.rendered

  iam_instance_profile = aws_iam_instance_profile.main.name

  tags = {
    Name        = var.ubuntu_name
    terraform   = true
    environment = var.environment
  }
}