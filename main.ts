import { readFileSync } from "fs";
import { Construct } from "constructs";
import { App, TerraformStack, CloudBackend, NamedCloudWorkspace } from "cdktf";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { KeyPair } from "@cdktf/provider-aws/lib/key-pair";
import { VPC } from "./constructs/vpc";
import { S3 } from "./constructs/s3";
import { EC2 } from "./constructs/ec2";
import { DNS } from "./constructs/dns";
import { CDN } from "./constructs/cdn";
import { IAM } from "./constructs/iam";
import { DataAwsEc2ManagedPrefixList } from "@cdktf/provider-aws/lib/data-aws-ec2-managed-prefix-list";

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
      hostedZone: dns.zone.id,
    });
    const vpc = new VPC(this, "vpc");

    const prefixList = new DataAwsEc2ManagedPrefixList(this, "prefix-list", {
      name: "com.amazonaws.global.cloudfront.origin-facing",
    });

    const key = new KeyPair(this, "key", {
      keyName: "ggaguilar",
      publicKey: readFileSync("./assets/key.pub", "utf8"),
    });

    new EC2(this, "gateway", {
      vpc: vpc.id,
      subnet: vpc.subnets[0].id,
      key: key.keyName,
      permissions: [
        {
          Sid: "ReadWriteBackups",
          Effect: "Allow",
          Resource: [`${s3.buckets.backups.arn}/gateway/*`],
          Action: ["s3:GetObject*", "s3:PutObject*"],
        },
        {
          Sid: "ListBackups",
          Effect: "Allow",
          Resource: [s3.buckets.backups.arn],
          Action: ["s3:ListBucket"],
        },
        {
          Sid: "ListHostedZones",
          Effect: "Allow",
          Resource: ["*"],
          Action: ["route53:ListHostedZones"],
        },
        {
          Sid: "WriteRecordSets",
          Effect: "Allow",
          Resource: [dns.zone.arn],
          Action: [
            "route53:ListResourceRecordSets",
            "route53:ChangeResourceRecordSets",
          ],
        },
      ],
      ports: [
        {
          fromPort: 51820,
          toPort: 51821,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "UDP",
        },
        {
          fromPort: 51820,
          toPort: 51821,
          ipv6CidrBlocks: ["::/0"],
          protocol: "UDP",
        },
        {
          fromPort: 443,
          toPort: 443,
          prefixListIds: [prefixList.id],
          protocol: "TCP",
        },
      ],
    });

    new EC2(this, "mail", {
      vpc: vpc.id,
      subnet: vpc.subnets[0].id,
      key: key.keyName,
      permissions: [
        {
          Sid: "ReadWriteBackups",
          Effect: "Allow",
          Resource: [`${s3.buckets.backups.arn}/mail/*`],
          Action: ["s3:GetObject*", "s3:PutObject*", "s3:DeleteObject"],
        },
        {
          Sid: "ListBackups",
          Effect: "Allow",
          Resource: [s3.buckets.backups.arn],
          Action: ["s3:ListBucket"],
        },
        {
          Sid: "ListHostedZones",
          Effect: "Allow",
          Resource: ["*"],
          Action: ["route53:ListHostedZones"],
        },
        {
          Sid: "ListRecordSets",
          Effect: "Allow",
          Resource: [dns.zone.arn],
          Action: ["route53:ListResourceRecordSets"],
        },
        {
          Sid: "WriteRecordSets",
          Effect: "Allow",
          Resource: [dns.zone.arn],
          Action: ["route53:ChangeResourceRecordSets"],
          Condition: {
            StringEquals: {
              "route53:ChangeResourceRecordSetsNormalizedRecordNames": `mail.${dns.zone.name}`,
            },
          },
        },
      ],
      ports: [
        {
          fromPort: 25,
          toPort: 25,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 25,
          toPort: 25,
          ipv6CidrBlocks: ["::/0"],
          protocol: "TCP",
        },
        {
          fromPort: 443,
          toPort: 443,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 443,
          toPort: 443,
          ipv6CidrBlocks: ["::/0"],
          protocol: "TCP",
        },
        {
          fromPort: 465,
          toPort: 465,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 465,
          toPort: 465,
          ipv6CidrBlocks: ["::/0"],
          protocol: "TCP",
        },
        {
          fromPort: 993,
          toPort: 993,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 993,
          toPort: 993,
          ipv6CidrBlocks: ["::/0"],
          protocol: "TCP",
        },
      ],
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
