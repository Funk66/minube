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
  }

  record(name: string, target: string) {
    new Route53Record(this, name, {
      name: name,
      zoneId: this.zone.zoneId,
      type: "A",
      ttl: 300,
      records: [target],
    });
  }
}
