provider "aws" {
  region = "eu-central-1"
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
  name   = "minube"
  vpc_id = aws_vpc.minube.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
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

data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "minube" {
  ami             = data.aws_ami.amazon-linux-2.id
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
