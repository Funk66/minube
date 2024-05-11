import { Construct } from "constructs";
import { App, TerraformStack, CloudBackend, NamedCloudWorkspace } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { VPC } from "./constructs/vpc";
import { S3 } from "./constructs/s3";
import { Role } from "./constructs/iam";
import { EC2 } from "./constructs/ec2";
import { DNS } from "./constructs/dns";

class Minube extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    new AwsProvider(this, "aws", { region: "eu-central-1" });

    const dns = new DNS(this, "dns");
    const s3 = new S3(this, "buckets");
    const role = new Role(this, "role", {
      backups: s3.buckets.backups,
      photos: s3.buckets.photos,
      hostedZone: dns.zone.arn,
    });
    const vpc = new VPC(this, "vpc");
    new EC2(this, "ec2", {
      vpc: vpc,
      role: role,
      backups: s3.buckets.backups,
      photos: s3.buckets.photos,
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
