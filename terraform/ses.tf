resource "aws_ses_domain_identity" "ses_domain-identity_2AC0305F" {
  domain = aws_route53_zone.dns_zone_2E2729FB.name
}

resource "aws_ses_domain_mail_from" "ses_domain-mail-from_F87769A2" {
  domain           = aws_route53_zone.dns_zone_2E2729FB.name
  mail_from_domain = "bounces.${aws_route53_zone.dns_zone_2E2729FB.name}"
}

resource "aws_ses_domain_dkim" "ses_domain-dkim_A38858C1" {
  domain = aws_route53_zone.dns_zone_2E2729FB.name
}

resource "aws_route53_record" "ses_verification-record_8F3F9C54" {
  name    = "_amazonses.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "TXT"
  ttl     = 300
  records = [
    aws_ses_domain_identity.ses_domain-identity_2AC0305F.verification_token
  ]
}

resource "aws_route53_record" "ses_mail-from-mx_8F614BAA" {
  name    = aws_ses_domain_mail_from.ses_domain-mail-from_F87769A2.mail_from_domain
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "MX"
  ttl     = 300
  records = [
    "10 feedback-smtp.${aws_ses_domain_identity.ses_domain-identity_2AC0305F.region}.amazonses.com"
  ]
}

resource "aws_route53_record" "ses_mail-from-txt_04902770" {
  name    = aws_ses_domain_mail_from.ses_domain-mail-from_F87769A2.mail_from_domain
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "ses_dkim-record-0_DDADBEBD" {
  name    = "${element(aws_ses_domain_dkim.ses_domain-dkim_A38858C1.dkim_tokens, 0)}._domainkey.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "CNAME"
  ttl     = 300
  records = [
    "${element(aws_ses_domain_dkim.ses_domain-dkim_A38858C1.dkim_tokens, 0)}.dkim.amazonses.com"
  ]
}

resource "aws_route53_record" "ses_dkim-record-1_9FC8CF42" {
  name    = "${element(aws_ses_domain_dkim.ses_domain-dkim_A38858C1.dkim_tokens, 1)}._domainkey.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "CNAME"
  ttl     = 300
  records = [
    "${element(aws_ses_domain_dkim.ses_domain-dkim_A38858C1.dkim_tokens, 1)}.dkim.amazonses.com"
  ]
}

resource "aws_route53_record" "ses_dkim-record-2_5CCE1C1C" {
  name    = "${element(aws_ses_domain_dkim.ses_domain-dkim_A38858C1.dkim_tokens, 2)}._domainkey.${aws_route53_zone.dns_zone_2E2729FB.name}"
  zone_id = aws_route53_zone.dns_zone_2E2729FB.id
  type    = "CNAME"
  ttl     = 300
  records = [
    "${element(aws_ses_domain_dkim.ses_domain-dkim_A38858C1.dkim_tokens, 2)}.dkim.amazonses.com"
  ]
}
