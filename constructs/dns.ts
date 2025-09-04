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
      name: "202410e._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "v=DKIM1; k=ed25519; h=sha256; p=vEk1THcUadgUtHrdPacNtfxGkGyLA9fQaJr2lfRbJNE=",
      ],
    });

    new Route53Record(this, "dkim-rsa-record", {
      name: "202410r._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        'v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0My9m8t0q/k4Tz8I36Jmcn8H1vULiH+ORxPUrRKfELj2AecV9oWyEpZBGK72JJwhFzsZ/emXcmIzQaNAgdJ4w0dNWneExw/12GodfVq1pQb1Aazw6ZDvrSlRPfC50u7vqbBkVxWUuns873BYDWFQQR9n9mv3rWHMq/0mzoK9Ge+n3zWPCE/N+nA""DzHT9KHRwL/pMVsdTtqtJp55+up/elQ3I/QdJJWZdmNab50TVgK3DTg2qaYm12aiLZUv/gxjpQqrcQCBSHPf1at5xlUcTfpxigYoyKdf9+kzUTNeuO9+4pW8TN/uHiSfvm5q5JT4v8ebHGWAlnnp1QN+MB06C6QIDAQAB',
      ],
    });

    new Route53Record(this, "spf-mx-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=spf1 a:office.guirao.net ra=postmaster ~all"],
    });

    new Route53Record(this, "srv-jmap-record", {
      name: "_jmap._tcp." + this.zone.name,
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
  }
}
