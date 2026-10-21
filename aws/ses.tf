resource "aws_ses_domain_identity" "domain_identity" {
  domain = aws_route53_zone.zone.name
}

resource "aws_ses_domain_mail_from" "domain_mail_from" {
  domain           = aws_route53_zone.zone.name
  mail_from_domain = "bounces.${aws_route53_zone.zone.name}"
}

resource "aws_ses_domain_dkim" "domain_dkim" {
  domain = aws_route53_zone.zone.name
}

resource "aws_route53_record" "verification_record" {
  name    = "_amazonses.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "TXT"
  ttl     = 300
  records = [
    aws_ses_domain_identity.domain_identity.verification_token
  ]
}

resource "aws_route53_record" "mail_from_mx" {
  name    = aws_ses_domain_mail_from.domain_mail_from.mail_from_domain
  zone_id = aws_route53_zone.zone.id
  type    = "MX"
  ttl     = 300
  records = [
    "10 feedback-smtp.${aws_ses_domain_identity.domain_identity.region}.amazonses.com"
  ]
}

resource "aws_route53_record" "mail_from_txt" {
  name    = aws_ses_domain_mail_from.domain_mail_from.mail_from_domain
  zone_id = aws_route53_zone.zone.id
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com -all"]
}

resource "aws_route53_record" "dkim_0" {
  name    = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, 0)}._domainkey.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "CNAME"
  ttl     = 300
  records = [
    "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, 0)}.dkim.amazonses.com"
  ]
}

resource "aws_route53_record" "dkim_1" {
  name    = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, 1)}._domainkey.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "CNAME"
  ttl     = 300
  records = [
    "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, 1)}.dkim.amazonses.com"
  ]
}

resource "aws_route53_record" "dkim_2" {
  name    = "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, 2)}._domainkey.${aws_route53_zone.zone.name}"
  zone_id = aws_route53_zone.zone.id
  type    = "CNAME"
  ttl     = 300
  records = [
    "${element(aws_ses_domain_dkim.domain_dkim.dkim_tokens, 2)}.dkim.amazonses.com"
  ]
}
