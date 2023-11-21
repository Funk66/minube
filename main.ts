import { Construct } from "constructs";
import { App, TerraformStack, CloudBackend, NamedCloudWorkspace } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { VPC } from "./constructs/vpc";
import { Buckets } from "./constructs/s3";
import { Role } from "./constructs/iam";
import { EC2 } from "./constructs/ec2";
import { DNS } from "./constructs/dns";

class Minube extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    new AwsProvider(this, "aws", { region: "eu-central-1" });

    const dns = new DNS(this, "dns");
    const buckets = new Buckets(this, "buckets");
    const role = new Role(this, "role", {
      backups: buckets.backups.arn,
      photos: buckets.photos.arn,
      hostedZone: dns.zone.arn,
    });
    const vpc = new VPC(this, "vpc");
    new EC2(this, "ec2", {
      vpc: vpc,
      role: role,
      backups: buckets.backups,
      photos: buckets.photos,
    });
  }
}

const app = new App();
const stack = new Minube(app, "minube");
new CloudBackend(stack, {
  hostname: "app.terraform.io",
  organization: "minube",
  workspaces: new NamedCloudWorkspace("minube"),
});
app.synth();
