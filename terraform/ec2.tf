data "aws_ami" "minube_ubuntu_DBD887C0" {
  most_recent = true
  name_regex  = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-arm64-server"
  owners      = ["amazon"]
}

resource "aws_iam_policy" "minube_ec2-policy_1589FCF6" {
  name   = "minube"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ReadWriteBackups\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-backups_0F1ACE02.arn}/*\",\"${aws_s3_bucket.buckets_minube-fs_5D278F8B.arn}/*\",\"${aws_s3_bucket.buckets_minube-files_0207517F.arn}/*\"],\"Action\":[\"s3:GetObject*\",\"s3:PutObject*\",\"s3:AbortMultipartUpload\"]},{\"Sid\":\"ListBackups\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-backups_0F1ACE02.arn}\",\"${aws_s3_bucket.buckets_minube-fs_5D278F8B.arn}\",\"${aws_s3_bucket.buckets_minube-files_0207517F.arn}\"],\"Action\":[\"s3:ListBucket\"]},{\"Sid\":\"SendNotificationEmails\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"ses:SendEmail\",\"ses:SendRawEmail\"]},{\"Sid\":\"ListHostedZones\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"route53:ListHostedZones\",\"route53:ListHostedZonesByName\"]},{\"Sid\":\"WriteRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.dns_zone_2E2729FB.arn}\"],\"Action\":[\"route53:ListResourceRecordSets\",\"route53:ChangeResourceRecordSets\"]},{\"Sid\":\"GetChange\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:route53:::change/*\"],\"Action\":[\"route53:GetChange\"]}]}"
}

resource "aws_iam_role" "minube_ec2-role_7EBD8617" {
  name               = "minube"
  assume_role_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"EC2\",\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
}

resource "aws_iam_policy_attachment" "minube_ec2-role-attachment_79AAE2A7" {
  name       = aws_iam_policy.minube_ec2-policy_1589FCF6.name
  policy_arn = aws_iam_policy.minube_ec2-policy_1589FCF6.arn
  roles      = [aws_iam_role.minube_ec2-role_7EBD8617.id]
}

resource "aws_iam_instance_profile" "minube_profile_DA0BE098" {
  name = aws_iam_role.minube_ec2-role_7EBD8617.id
  role = aws_iam_role.minube_ec2-role_7EBD8617.id
}

resource "aws_security_group" "minube_sg_FD4FC769" {
  name   = "minube"
  vpc_id = aws_vpc.vpc_6776A399.id
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

resource "aws_key_pair" "minube_key_C5C91068" {
  key_name   = "ggaguilar"
  public_key = file("${path.root}/../assets/key.pub")
}

resource "aws_instance" "minube_instance_DC8B55B2" {
  ami                    = data.aws_ami.minube_ubuntu_DBD887C0.id
  instance_type          = "t4g.micro"
  key_name               = aws_key_pair.minube_key_C5C91068.key_name
  subnet_id              = aws_subnet.vpc_subnet_376FC355.id
  vpc_security_group_ids = [aws_security_group.minube_sg_FD4FC769.id]
  iam_instance_profile   = aws_iam_instance_profile.minube_profile_DA0BE098.id
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

resource "aws_eip" "minube_eip_ABBEFAB8" {
  instance = aws_instance.minube_instance_DC8B55B2.id
  tags = {
    Name = "minube"
  }
}

resource "aws_ebs_volume" "minube_volume_7905D60F" {
  availability_zone = "eu-central-1b"
  type              = "gp3"
  size              = 2
  encrypted         = true
  tags = {
    Name = "data"
  }
}

resource "aws_volume_attachment" "minube_attachment_5CBBB29D" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.minube_volume_7905D60F.id
  instance_id = aws_instance.minube_instance_DC8B55B2.id
}

resource "aws_route53_record" "minube_main-a-record_C6633991" {
  name    = aws_route53_zone.dns_zone_2E2729FB.name
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "A"
  ttl     = 300
  records = [aws_eip.minube_eip_ABBEFAB8.public_ip]
}

resource "aws_route53_record" "minube_main-aaaa-record_6A1C442D" {
  name    = aws_route53_zone.dns_zone_2E2729FB.name
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "AAAA"
  ttl     = 300
  records = aws_instance.minube_instance_DC8B55B2.ipv6_addresses
}

resource "aws_route53_record" "minube_minube-a-record_BF1F97B8" {
  name    = "minube.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "A"
  ttl     = 300
  records = [aws_eip.minube_eip_ABBEFAB8.public_ip]
}

resource "aws_route53_record" "minube_minube-aaaa-record_DD7D00D9" {
  name    = "minube.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "AAAA"
  ttl     = 300
  records = aws_instance.minube_instance_DC8B55B2.ipv6_addresses
}

resource "aws_route53_record" "minube_mail-a-record_3EE44DA1" {
  name    = "mail.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "A"
  ttl     = 300
  records = [aws_eip.minube_eip_ABBEFAB8.public_ip]
}

resource "aws_route53_record" "minube_mail-aaaa-record_D2746EED" {
  name    = "mail.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "AAAA"
  ttl     = 300
  records = aws_instance.minube_instance_DC8B55B2.ipv6_addresses
}
