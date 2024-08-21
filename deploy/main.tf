provider "aws" {
  region = var.region
}

# Calculated local values.
locals {
  vpc_id = data.aws_subnet.selected.vpc_id
  vpc_cidr     = data.aws_vpc.selected.cidr_block

  security_group_id = var.security_group_ids == null ? aws_security_group.main[0].id : var.security_group_ids[0]

  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
  
}

# Use this data source to retrieve details about a specific VPC subnet.
data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

# Use this data source to retrieve details about a specific VPC.
data "aws_vpc" "selected" {
  id = local.vpc_id
}

# Deploy security group if var.security_group_ids == null.
resource "aws_security_group" "main" {
  count = var.security_group_ids == null ? 1 : 0

  name   = "fsx-ontap-sg"
  vpc_id = local.vpc_id

  tags = {
    Name        = "fsx-ontap-sg"
    terraform   = true
    environment = var.environment
  }
}

# Ingress rules.
resource "aws_security_group_rule" "ingress" {
    count = var.security_group_ids == null ? 1 : 0
    
    type              = "ingress"
    from_port         = local.any_port
    to_port           = local.any_port
    protocol          = local.any_protocol
    security_group_id = aws_security_group.main[0].id
    cidr_blocks       = [local.vpc_cidr]
}

# Egress rule: allow all outbound traffic.
resource "aws_security_group_rule" "allow_all_outbound" {
  count = var.security_group_ids == null ? 1 : 0

  type              = "egress"
  from_port         = local.any_port
  to_port           = local.any_port
  protocol          = local.any_protocol
  security_group_id = aws_security_group.main[0].id
  cidr_blocks       = local.all_ips
}

# FSX Ontap File System
resource "aws_fsx_ontap_file_system" "main" {
    
  storage_capacity                = var.storage_capacity
  subnet_ids                      = var.subnet_ids
  
  security_group_ids              = [local.security_group_id] 

  deployment_type                 = var.deployment_type
  
  throughput_capacity             = var.throughput_capacity
  preferred_subnet_id             = var.preferred_subnet_id
}