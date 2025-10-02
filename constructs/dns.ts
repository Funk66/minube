import { Construct } from "constructs";
import { Route53Zone } from "@cdktf/provider-aws/lib/route53-zone";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";

export class DNS extends Construct {
  zone: Route53Zone;

  constructor(scope: Construct, name: string) {
    super(scope, name);

    this.zone = new Route53Zone(this, "zone", {
      name: "guirao.net",
    });

    new Route53Record(this, "caa-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CAA",
      ttl: 300,
      records: [
        '0 issue "amazon.com"',
        '0 issuewild "amazon.com"',
        '0 issue "letsencrypt.org"',
        '0 issuewild "letsencrypt.org"',
      ],
    });

    new Route53Record(this, "mx-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "MX",
      ttl: 300,
      records: ["10 mail." + this.zone.name],
    });

    new Route53Record(this, "dkim-ecc-record", {
      name: "202509e._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "v=DKIM1; k=ed25519; h=sha256; p=eGi8/tRKdMa6kjsJsxAcFpq1kLH1LeKzPaICcaT1cuc=",
      ],
    });

    new Route53Record(this, "dkim-rsa-record", {
      name: "202509r._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        'v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxpEUbVuE1DlmMXaAQMV8QdHU5ZsTfRaF5dObdJ7+f+2TGvZ4AorQIzmb2kM664Xkl2aJGhkz0YfPv7tRsuachbaRJbjGRCkAftkaP0YYF8LgVuT9zakCIKBzfxyE+uPMaW2dwB+""IrmriZCBSaGJ5cA/krxcfWAkvA6t9yaCG5wibfIL9X+iO9/p0KUcE20CT+8+hU7wjUEWxDF6ia4hLzOSGA8fd3pk6dSSDD2whrZpIIdQjVsBsQsSZ28tvd2zVpkOzWJx5i73YSw1MWV5+tW2uVPxqN65N/DRNimLhNRNSkSq/+F+LyG1M84ttR8ncU1i5hPBHIH9f3/m98ismsQIDAQAB',
      ],
    });

    new Route53Record(this, "srv-jmap-record", {
      name: "_jmap._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 443 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-caldavs-record", {
      name: "_caldavs._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 443 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-carddavs-record", {
      name: "_carddavs._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 443 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-imaps-record", {
      name: "_imaps._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 993 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-imap-record", {
      name: "_imap._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 143 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-pop3s-record", {
      name: "_pop3s._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 995 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-pop3-record", {
      name: "_pop3._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 110 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-submissions-record", {
      name: "_submissions._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 465 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-submission-record", {
      name: "_submission._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 587 mail." + this.zone.name],
    });

    new Route53Record(this, "cname-autoconfig-record", {
      name: "autoconfig." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["mail." + this.zone.name],
    });

    new Route53Record(this, "cname-autodiscover-record", {
      name: "autodiscover." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["mail." + this.zone.name],
    });

    new Route53Record(this, "cname-mta-sts-record", {
      name: "mta-sts." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["mail." + this.zone.name],
    });

    new Route53Record(this, "txt-mta-sts-record", {
      name: "_mta-sts." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=STSv1; id=8777202045385525987"],
    });

    new Route53Record(this, "txt-dmarc-record", {
      name: "_dmarc." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "v=DMARC1; p=reject; rua=mailto:postmaster@guirao.net; ruf=mailto:postmaster@guirao.net",
      ],
    });

    new Route53Record(this, "txt-smtp-record", {
      name: "_smtp._tls." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=TLSRPTv1; rua=mailto:postmaster@guirao.net"],
    });

    new Route53Record(this, "tlsa-25-record", {
      name: "_25._tcp.mail." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TLSA",
      ttl: 300,
      records: [
        "3 0 1 c430400ecd6a2cd960c42358915a8cbf590d448f390407a2c6518706427f5ee6",
        "3 0 2 5529d6de26a00bc98dd4dccb5b5724632a6278025dd2b948286910f01d33bfe90161b90e944466521b7e4b2869aa077c76cbdf002cd011f01ce702cff958d63a",
        "3 1 1 685a21cd2003f9860e3fec47dac66ff847ef1f578095b5ff51fc6da24ce342fd",
        "3 1 2 9ed125bd51c8f7cde85329214c8fa5e5689de2a09288adfb2429bdc9dd9d47bbcaf550393542de22f3812a57e368aa5b13e4150a1ef14e99d7a0cf02406d0ac0",
        "2 0 1 aeb1fd7410e83bc96f5da3c6a7c2c1bb836d1fa5cb86e708515890e428a8770b",
        "2 0 2 e18f3d6ccbc578f025c3c7c29ed7bffe1b8eef5b1f839c17298dcf218303d2a63e305f6c1f489691774a18bad836035e5af2de1fc42a3a26cfe9e530f92e3855",
        "2 1 1 cbbc559b44d524d6a132bdac672744da3407f12aae5d5f722c5f6c7913871c75",
        "2 1 2 7d779dd26d37ca5a72fd05f1b815a06078c8e09777697c651fbe012c8d2894e048fcfe24160ee1562602240b6bef44e00f2b7340c84546d6110842bbdeb484a7",
      ],
    });
  }
}
