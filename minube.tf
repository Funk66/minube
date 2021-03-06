provider "aws" {
  region = "eu-central-1"
}

variable "home_ip" {}

resource "aws_kms_key" "master" {
  enable_key_rotation = true
}

terraform {
  backend "s3" {
    bucket  = "minube-terraform-state"
    key     = "tfstate"
    region  = "eu-central-1"
    encrypt = "true"
  }
}

resource "aws_vpc" "minube" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "minube" {
  cidr_block        = cidrsubnet(aws_vpc.minube.cidr_block, 3, 1)
  vpc_id            = aws_vpc.minube.id
  availability_zone = "eu-central-1a"
}

resource "aws_security_group" "minube" {
  name        = "minube"
  description = "SSH, DNS and HTTP"
  vpc_id      = aws_vpc.minube.id
  ingress {
    cidr_blocks = [var.home_ip]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = [var.home_ip]
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = [var.home_ip]
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
  }

  ingress {
    cidr_blocks = [var.home_ip]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "minube" {
  key_name   = "minube"
  public_key = file("minube.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "minube" {
  ami             = "ami-0cc0a36f626a4fdf5"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.minube.key_name
  security_groups = [aws_security_group.minube.id]
  subnet_id       = aws_subnet.minube.id
}

resource "aws_eip" "minube" {
  instance = aws_instance.minube.id
  vpc      = true
}

resource "aws_internet_gateway" "minube" {
  vpc_id = aws_vpc.minube.id
}

resource "aws_route_table" "minube" {
  vpc_id = aws_vpc.minube.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minube.id
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.minube.id
  route_table_id = aws_route_table.minube.id
}

output "public_ip" {
  value = aws_eip.minube.public_ip
}

resource "aws_s3_bucket" "minube" {
  bucket = "minube-terraform-state"
  region = "eu-central-1"

  versioning {
    enabled = true
  }

  policy = data.aws_iam_policy_document.minube_s3.json

  logging {
    target_bucket = "minube-terraform-state"
    target_prefix = "log/"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.master.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

data "aws_iam_policy_document" "minube_s3" {
  statement {
    sid       = "DenyIncorrectEncryptionHeader"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::minube-terraform-state/*"]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "StringNotEquals"
      values   = ["AES256"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }

  statement {
    sid       = "DenyUnEncryptedObjectUploads"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::minube-terraform-state/*"]

    principals {
      identifiers = ["*"]
      type        = "*"
    }

    condition {
      test     = "Null"
      values   = ["true"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }
}
