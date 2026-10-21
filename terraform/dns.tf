resource "aws_route53_zone" "zone" {
  name = "guirao.net"
}

resource "aws_route53_record" "caa_record" {
  name    = aws_route53_zone.zone.name
  zone_id = aws_route53_zone.zone.zone_id
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

data "aws_caller_identity" "current" {

}

data "aws_iam_policy_document" "dnssec_policy" {
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
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }
}

resource "aws_kms_key" "kms_key" {
  description              = "KMS key for DNSSEC in ${aws_route53_zone.zone.name}"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  policy                   = data.aws_iam_policy_document.dnssec_policy.json
  provider                 = aws.us-east-1
}

resource "aws_kms_alias" "kms_key_alias" {
  name          = "alias/dnssec"
  target_key_id = aws_kms_key.kms_key.key_id
  provider      = aws.us-east-1
}

resource "aws_route53_key_signing_key" "key_signing_key" {
  name                       = "guirao-net-dnssec"
  hosted_zone_id             = aws_route53_zone.zone.zone_id
  key_management_service_arn = aws_kms_key.kms_key.arn
}

resource "aws_route53_hosted_zone_dnssec" "dnssec" {
  hosted_zone_id = aws_route53_key_signing_key.key_signing_key.hosted_zone_id
}

resource "aws_route53_record" "funk66_cname" {
  name    = "guillermo.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.zone_id
  type    = "CNAME"
  ttl     = 300
  records = ["funk66.github.io"]
}

resource "aws_route53_record" "google_record" {
  name    = aws_route53_zone.zone.name
  zone_id = aws_route53_zone.zone.zone_id
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 mx -all",
    "google-site-verification=jm-wNSxSnrlZD5TeJzZMYOIsa8AdIDRNX9TKuAX0h5c"
  ]
}
