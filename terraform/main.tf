variable "aws_region" {}

variable "profile" {}
variable "server_port" {}

variable "key_name" {}
variable "public_key" {}
variable "private_key" {}
variable "aws_access_key_id" {}
variable "aws_secret_access_key" {} 
variable "aws_availability_zone" {}


# instance
variable "aws_ami_id" {}


provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = var.public_key
}

resource "aws_vpc" "ejbca_vpc" {

  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames  = true

  tags = {
    Name = "ejbca_vpc"
  }
}

resource "aws_eip" "ejbca_elastic_ip" {
  vpc = true
}

resource "aws_subnet" "ejbca_public_subnet" {
  vpc_id     = aws_vpc.ejbca_vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "ejbca_public_subnet"
  }
}

resource "aws_subnet" "ejbca_private_subnet" {
  vpc_id     = aws_vpc.ejbca_vpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "ejbca_private_subnet"
  }
}

resource "aws_internet_gateway" "ejbca_internet_gateway" {
  vpc_id = aws_vpc.ejbca_vpc.id

  tags = {
    Name = "ejbca_internet_gateway"
  }
}

resource "aws_default_route_table" "ejbca_main_route_table" {
  default_route_table_id = aws_vpc.ejbca_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ejbca_internet_gateway.id
  }

  tags = {
    Name = "ejbca_main_route_table"
  }
}

resource "aws_nat_gateway" "ejbca_nat_gateway" {
  allocation_id = aws_eip.ejbca_elastic_ip.id
  subnet_id     = aws_subnet.ejbca_public_subnet.id

  tags = {
    Name = "ejbca gateway NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.ejbca_internet_gateway]
}

resource "aws_route_table" "ejbca_private_route_table" {
  vpc_id = aws_vpc.ejbca_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ejbca_nat_gateway.id
  }

  tags = {
    Name = "ejbca_route_table"
  }
}

resource "aws_route_table_association" "assign_route_table_to_private" {
  subnet_id      = aws_subnet.ejbca_private_subnet.id
  route_table_id = aws_route_table.ejbca_private_route_table.id
}

resource "aws_security_group" "ejbca_security_group" {
  name = "ejbca_security_group"  
  description = "Allow ssh and http(s) for ejbca"
  vpc_id      = aws_vpc.ejbca_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ejbca_security_group"
  }
}

resource "aws_ebs_volume" "tmp" {
  availability_zone = aws_instance.ejbca_core.availability_zone
  size              = 10
  tags = {
    Name = "tmp"
  }
}

resource "aws_instance" "ejbca_core" {
  ami = var.aws_ami_id
  instance_type = "t3.small"
  key_name = var.key_name
  associate_public_ip_address = true
  subnet_id = aws_subnet.ejbca_public_subnet.id
  vpc_security_group_ids = [aws_security_group.ejbca_security_group.id]
  private_ip = "192.168.1.5"
  tags = {
    Name = "terraform-ejbca-aws"
  }
  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_instance" "ejbca_db" {
  ami = var.aws_ami_id
  instance_type = "t3.micro"
  key_name = var.key_name
  subnet_id = aws_subnet.ejbca_private_subnet.id
  vpc_security_group_ids = [aws_security_group.ejbca_security_group.id]
  private_ip = "192.168.2.5"
  tags = {
    Name = "terraform-ejbca-aws"
  }

  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_volume_attachment" "tmp_attachement" {
  device_name  = "/dev/xvdb"
  instance_id  = aws_instance.ejbca_core.id
  volume_id    = aws_ebs_volume.tmp.id
  # skip_destroy = "true"
}


output "public_ip_ejbca" {
  value       = aws_instance.ejbca_core.public_ip
  description = "The public IP of the ejbca server"
}

output "name_ejbca" {
  value       = aws_instance.ejbca_core.tags.Name
  description = "The Name of the web server"
}

output "state_ejbca" {
  value       = aws_instance.ejbca_core.instance_state
  description = "The state of the web server"
}


output "public_ip_db" {
  value       = aws_instance.ejbca_db.public_ip
  description = "The public IP of the db server"
}

output "private_ip_db" {
  value       = aws_instance.ejbca_db.private_ip
  description = "The public IP of the db server"
}

output "name_db" {
  value       = aws_instance.ejbca_db.tags.Name
  description = "The Name of the db server"
}

output "state_db" {
  value       = aws_instance.ejbca_db.instance_state
  description = "The state of the db server"
}