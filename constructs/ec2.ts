import { Construct } from "constructs";
import { readFileSync } from "fs";
import { DataAwsSsmParameter } from "@cdktf/provider-aws/lib/data-aws-ssm-parameter";
import { SecurityGroup } from "@cdktf/provider-aws/lib/security-group";
import { KeyPair } from "@cdktf/provider-aws/lib/key-pair";
import { Instance } from "@cdktf/provider-aws/lib/instance";
import { Eip } from "@cdktf/provider-aws/lib/eip";
import { EipAssociation } from "@cdktf/provider-aws/lib/eip-association";
import { VPC } from "./vpc";
import { Role } from "./iam";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";

interface EC2Config {
  vpc: VPC;
  backups: S3Bucket;
}

export class EC2 extends Construct {
  public readonly ip: string;
  public readonly ipv6: string;

  constructor(scope: Construct, id: string, config: EC2Config) {
    super(scope, id);

    const ami = new DataAwsSsmParameter(this, "ubuntu", {
      name: "/aws/service/canonical/ubuntu/server/22.04/stable/current/arm64/hvm/ebs-gp2/ami-id",
    }).value;

    const sg = new SecurityGroup(this, "sg", {
      name: "minube",
      vpcId: config.vpc.id,
      egress: [
        {
          fromPort: 0,
          toPort: 0,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "-1",
        },
        {
          fromPort: 0,
          toPort: 0,
          ipv6CidrBlocks: ["::/0"],
          protocol: "-1",
        },
      ],
      ingress: [
        {
          fromPort: 22,
          toPort: 22,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 51820,
          toPort: 51820,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "UDP",
        },
        {
          fromPort: 22,
          toPort: 22,
          ipv6CidrBlocks: ["::/0"],
          protocol: "TCP",
        },
        {
          fromPort: 51820,
          toPort: 51820,
          ipv6CidrBlocks: ["::/0"],
          protocol: "UDP",
        },
      ],
    });

    const key = new KeyPair(this, "key", {
      keyName: "ggaguilar",
      publicKey: readFileSync("./assets/key.pub", "utf8"),
    });

    const role = new Role(this, "role", { backups: config.backups.arn });

    const ec2 = new Instance(this, "ec2", {
      ami: ami,
      instanceType: "t4g.nano",
      securityGroups: [sg.id],
      subnetId: config.vpc.subnets[0].id,
      keyName: key.id,
      iamInstanceProfile: role.id,
      userData: readFileSync("assets/userdata.sh", "utf8"),
      // associatePublicIpAddress: false,
      tags: {
        Name: "minube",
      },
    });

    const eip = new Eip(this, "eip");

    new EipAssociation(this, "eip-association", {
      instanceId: ec2.id,
      allocationId: eip.id,
    });

    this.ip = eip.publicIp;
    this.ipv6 = ec2.ipv6Addresses[0];
  }
}
