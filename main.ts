import { Construct } from "constructs";
import { App, TerraformStack, CloudBackend, NamedCloudWorkspace } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { VPC } from "./constructs/vpc";
import { S3 } from "./constructs/s3";
import { EC2 } from "./constructs/ec2";
import { DNS } from "./constructs/dns";
import { CDN } from "./constructs/cdn";
import { IAM } from "./constructs/iam";

class Minube extends TerraformStack {
  constructor(scope: Construct, id: string) {
    super(scope, id);

    new AwsProvider(this, "aws-eu", {
      region: "eu-central-1",
    });
    const provider = new AwsProvider(this, "aws-us", {
      region: "us-east-1",
      alias: "us-east-1",
    });

    const dns = new DNS(this, "dns");
    new CDN(this, "cdn", dns.zone.id, provider);
    const s3 = new S3(this, "buckets");
    new IAM(this, "iam", {
      photos: s3.buckets.photos,
      docs: s3.buckets.docs,
      mail: s3.buckets.mail,
      domain: dns.zone.name,
      hostedZone: dns.zone.arn,
    });
    const vpc = new VPC(this, "vpc");

    new EC2(this, "minube", {
      vpc: vpc.id,
      subnet: vpc.subnets[0].id,
      backups: s3.buckets.backups.arn,
      hostedZone: dns.zone.arn,
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
