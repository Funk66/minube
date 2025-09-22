import { Construct } from "constructs";
import { SesDomainIdentity } from "@cdktf/provider-aws/lib/ses-domain-identity";
import { Route53Zone } from "@cdktf/provider-aws/lib/route53-zone";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";
import { SesDomainMailFrom } from "@cdktf/provider-aws/lib/ses-domain-mail-from";
// import { SesDomainDkim } from "@cdktf/provider-aws/lib/ses-domain-dkim";

interface SesConfig {
  hostedZone: Route53Zone;
}

export class SES extends Construct {
  constructor(scope: Construct, id: string, config: SesConfig) {
    super(scope, id);

    const domainIdentity = new SesDomainIdentity(this, "domain-identity", {
      domain: config.hostedZone.name,
    });

    const mailFrom = new SesDomainMailFrom(this, "domain-mail-from", {
      domain: config.hostedZone.name,
      mailFromDomain: `bounces.${config.hostedZone.name}`,
    });

    new Route53Record(this, "verification-record", {
      zoneId: config.hostedZone.id,
      name: `_amazonses.${config.hostedZone.name}`,
      type: "TXT",
      ttl: 300,
      records: [domainIdentity.verificationToken],
    });

    new Route53Record(this, "mail-from-mx", {
      zoneId: config.hostedZone.id,
      name: mailFrom.mailFromDomain,
      type: "MX",
      ttl: 300,
      records: [`10 feedback-smtp.${domainIdentity.region}.amazonses.com`],
    });

    new Route53Record(this, "mail-from-txt", {
      zoneId: config.hostedZone.id,
      name: mailFrom.mailFromDomain,
      type: "TXT",
      ttl: 300,
      records: [`v=spf1 include:amazonses.com -all`],
    });
  }
}
