import { Construct } from "constructs";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";
import { Route53Zone } from "@cdktf/provider-aws/lib/route53-zone";

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
      records: ['0 issue "amazon.com"', '0 issuewild "amazon.com"'],
    });
  }

  record(name: string, rtype: string, target: string) {
    new Route53Record(this, `${name}-${rtype}`, {
      name: name,
      zoneId: this.zone.zoneId,
      type: rtype,
      ttl: 300,
      records: [target],
    });
  }
}
