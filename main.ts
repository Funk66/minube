import { Construct } from "constructs";
import { App, TerraformStack, CloudBackend, NamedCloudWorkspace } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { VPC } from "./constructs/vpc";
import { Buckets } from "./constructs/s3";
import { EC2 } from "./constructs/ec2";
import { DNS } from "./constructs/dns";

class Minube extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    new AwsProvider(this, "aws", { region: "eu-central-1" });

    const buckets = new Buckets(this, "buckets");
    const vpc = new VPC(this, "vpc");
    const ec2 = new EC2(this, "ec2", { vpc: vpc, backups: buckets.backups });
    const dns = new DNS(this, "dns");
    dns.record("minube", ec2.ip);
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
