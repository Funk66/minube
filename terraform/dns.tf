resource "aws_route53_zone" "dns_zone_2E2729FB" {
  name = "guirao.net"
}

resource "aws_route53_record" "dns_caa-record_487843A3" {
  name    = aws_route53_zone.dns_zone_2E2729FB.name
  zone_id = aws_route53_zone.dns_zone_2E2729FB.zone_id
  type    = "CAA"
  ttl     = 60
  records = [
    "0 issue \"amazon.com\"",
    "0 issuewild \"amazon.com\"",
    "0 issue \"letsencrypt.org\"",
    "0 issuewild \"letsencrypt.org\"",
    "0 iodef \"mailto:acme@guirao.net\""
  ]
}

data "aws_caller_identity" "dns_current_750979D0" {

}

data "aws_iam_policy_document" "dns_dnssec-policy_FD420429" {
  statement {
    sid    = "Allow administration of the key"
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
      "kms:GetPublicKey",
      "kms:Sign",
      "kms:Verify"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["dnssec-route53.amazonaws.com"]
    }
  }
  statement {
    sid       = "Allow IAM user permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.dns_current_750979D0.account_id}:root"
      ]
    }
  }
}

resource "aws_kms_key" "dns_kms-key_3A639EF6" {
  description              = "KMS key for DNSSEC in ${aws_route53_zone.dns_zone_2E2729FB.name}"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  policy                   = data.aws_iam_policy_document.dns_dnssec-policy_FD420429.json
  provider                 = aws.us-east-1
}

resource "aws_kms_alias" "dns_kms-key-alias_C6B16ECE" {
  name          = "alias/dnssec"
  target_key_id = aws_kms_key.dns_kms-key_3A639EF6.key_id
  provider      = aws.us-east-1
}

resource "aws_route53_key_signing_key" "dns_key-signing-key_71FE8640" {
  name                       = "guirao-net-dnssec"
  hosted_zone_id             = aws_route53_zone.dns_zone_2E2729FB.zone_id
  key_management_service_arn = aws_kms_key.dns_kms-key_3A639EF6.arn
}

resource "aws_route53_hosted_zone_dnssec" "dns_dnssec_B5444A19" {
  hosted_zone_id = aws_route53_key_signing_key.dns_key-signing-key_71FE8640.hosted_zone_id
}

resource "aws_route53_record" "dns_funk66-cname_1E1DFA2C" {
  name    = "guillermo.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.zone_id
  type    = "CNAME"
  ttl     = 300
  records = ["funk66.github.io"]
}

resource "aws_route53_record" "dns_google-record_BC4BA9C2" {
  name    = aws_route53_zone.dns_zone_2E2729FB.name
  zone_id = aws_route53_zone.dns_zone_2E2729FB.zone_id
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 mx -all",
    "google-site-verification=jm-wNSxSnrlZD5TeJzZMYOIsa8AdIDRNX9TKuAX0h5c"
  ]
}
