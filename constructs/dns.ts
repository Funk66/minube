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
      name: "202406e._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "v=DKIM1; k=ed25519; h=sha256; p=Zl8i7Oh2t73cP2aMJzh2mIPgF/Eqv3fgWChf6L4k4g4=",
      ],
    });

    new Route53Record(this, "dkim-rsa-record", {
      name: "202406r._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        'v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAui5IGvQl8J9SuUUGh/c/KHD7PH6fUm5lsNqilzBW0qHUzojCwSgA2tTYwbhYwI/eJ7hk8Z+2p1ShYVdTjaTHPSxODupDeuvB/""ecWs4XP8SUJYhTNc81h9IvFyliiFwyYqIF8SrvbTxwApOnRSjxbtxJNldpknnehosrrn5i314dpw5LcwY/13r48b6niHGyn2SkvCN5FMdosayOPvZ/wBSvuxvT1mk1FuT/fQQ3TIrvmHxy0N8ZQV4V+8HvjHcY17H7i02l9iqCZPIiVGeyLVGG10n/ePLbBzwp9Vudz40rs+pkvepblHcAtXH4UiIg5gYsXDMDVC6ZCZORnZTY2WwIDAQAB',
      ],
    });

    new Route53Record(this, "spf-mx-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=spf1 mx ra=postmaster -all"],
    });

    new Route53Record(this, "spf-a-record", {
      name: "mail." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=spf1 a ra=postmaster -all"],
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
