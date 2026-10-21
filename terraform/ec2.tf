data "aws_ami" "ubuntu" {
  most_recent = true
  name_regex  = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-arm64-server"
  owners      = ["amazon"]
}

resource "aws_iam_policy" "ec2_policy" {
  name   = "minube"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ReadWriteBackups\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.backups.arn}/*\",\"${aws_s3_bucket.fs.arn}/*\",\"${aws_s3_bucket.files.arn}/*\"],\"Action\":[\"s3:GetObject*\",\"s3:PutObject*\",\"s3:AbortMultipartUpload\"]},{\"Sid\":\"ListBackups\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.backups.arn}\",\"${aws_s3_bucket.fs.arn}\",\"${aws_s3_bucket.files.arn}\"],\"Action\":[\"s3:ListBucket\"]},{\"Sid\":\"SendNotificationEmails\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"ses:SendEmail\",\"ses:SendRawEmail\"]},{\"Sid\":\"ListHostedZones\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"route53:ListHostedZones\",\"route53:ListHostedZonesByName\"]},{\"Sid\":\"WriteRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.zone.arn}\"],\"Action\":[\"route53:ListResourceRecordSets\",\"route53:ChangeResourceRecordSets\"]},{\"Sid\":\"GetChange\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:route53:::change/*\"],\"Action\":[\"route53:GetChange\"]}]}"
}

resource "aws_iam_role" "ec2_role" {
  name               = "minube"
  assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"EC2\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
}

resource "aws_iam_policy_attachment" "ec2_role_attachment" {
  name       = aws_iam_policy.ec2_policy.name
  policy_arn = aws_iam_policy.ec2_policy.arn
  roles      = [aws_iam_role.ec2_role.id]
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = aws_iam_role.ec2_role.id
  role = aws_iam_role.ec2_role.id
}

resource "aws_security_group" "security_group" {
  name   = "minube"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
  }
  ingress {
    from_port        = 22
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    to_port          = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 25
    protocol    = "TCP"
    to_port     = 25
  }
  ingress {
    from_port        = 25
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    to_port          = 25
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 465
    protocol    = "TCP"
    to_port     = 465
  }
  ingress {
    from_port        = 465
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    to_port          = 465
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 993
    protocol    = "TCP"
    to_port     = 993
  }
  ingress {
    from_port        = 993
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    to_port          = 993
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = -1
    protocol    = "ICMP"
    to_port     = -1
  }
  ingress {
    from_port        = -1
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "ICMPV6"
    to_port          = -1
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 51820
    protocol    = "UDP"
    to_port     = 51821
  }
  ingress {
    from_port        = 51820
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "UDP"
    to_port          = 51821
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "TCP"
    to_port     = 80
  }
  ingress {
    from_port        = 80
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    to_port          = 80
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    protocol    = "TCP"
    to_port     = 443
  }
  ingress {
    from_port        = 443
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "TCP"
    to_port          = 443
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
  egress {
    from_port        = 0
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "-1"
    to_port          = 0
  }
  tags = {
    Name = "minube"
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "ggaguilar"
  public_key = file("${path.root}/../assets/key.pub")
}

resource "aws_instance" "instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t4g.micro"
  key_name               = aws_key_pair.ssh_key.key_name
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = [aws_security_group.security_group.id]
  iam_instance_profile   = aws_iam_instance_profile.instance_profile.id
  availability_zone      = "eu-central-1b"
  user_data              = file("${path.root}/../assets/userdata.sh")
  root_block_device {
    encrypted   = true
    volume_size = 16
    volume_type = "gp3"
  }
  metadata_options {
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }
  tags = {
    Name = "minube"
  }
  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_eip" "eip" {
  instance = aws_instance.instance.id
  tags = {
    Name = "minube"
  }
}

resource "aws_ebs_volume" "data_volume" {
  availability_zone = "eu-central-1b"
  type              = "gp3"
  size              = 2
  encrypted         = true
  tags = {
    Name = "data"
  }
}

resource "aws_volume_attachment" "data_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data_volume.id
  instance_id = aws_instance.instance.id
}

resource "aws_route53_record" "main_a" {
  name    = aws_route53_zone.zone.name
  zone_id = aws_route53_zone.zone.id
  type    = "A"
  ttl     = 300
  records = [aws_eip.eip.public_ip]
}

resource "aws_route53_record" "main_aaaa" {
  name    = aws_route53_zone.zone.name
  zone_id = aws_route53_zone.zone.id
  type    = "AAAA"
  ttl     = 300
  records = aws_instance.instance.ipv6_addresses
}

resource "aws_route53_record" "minube_a" {
  name    = "minube.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "A"
  ttl     = 300
  records = [aws_eip.eip.public_ip]
}

resource "aws_route53_record" "minube_aaaa" {
  name    = "minube.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "AAAA"
  ttl     = 300
  records = aws_instance.instance.ipv6_addresses
}

resource "aws_route53_record" "mail_a" {
  name    = "mail.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "A"
  ttl     = 300
  records = [aws_eip.eip.public_ip]
}

resource "aws_route53_record" "mail_aaaa" {
  name    = "mail.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "AAAA"
  ttl     = 300
  records = aws_instance.instance.ipv6_addresses
}
