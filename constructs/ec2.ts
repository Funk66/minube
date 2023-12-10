import { Construct } from "constructs";
import { IamInstanceProfile } from "@cdktf/provider-aws/lib/iam-instance-profile";
import { AutoscalingGroup } from "@cdktf/provider-aws/lib/autoscaling-group";
import { LaunchTemplate } from "@cdktf/provider-aws/lib/launch-template";
import { readFileSync } from "fs";
import { DataAwsSsmParameter } from "@cdktf/provider-aws/lib/data-aws-ssm-parameter";
import { SecurityGroup } from "@cdktf/provider-aws/lib/security-group";
import { KeyPair } from "@cdktf/provider-aws/lib/key-pair";
import { VPC } from "./vpc";
import { Role } from "./iam";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";

interface EC2Config {
  vpc: VPC;
  role: Role;
  backups: S3Bucket;
  photos: S3Bucket;
}

export class EC2 extends Construct {
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
        {
          fromPort: 80,
          toPort: 80,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "TCP",
        },
        {
          fromPort: 80,
          toPort: 80,
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
      ],
      tags: {
        Name: "minube",
      },
    });

    const key = new KeyPair(this, "key", {
      keyName: "ggaguilar",
      publicKey: readFileSync("./assets/key.pub", "utf8"),
    });

    const profile = new IamInstanceProfile(this, "profile", {
      name: config.role.id,
      role: config.role.id,
    });

    const template = new LaunchTemplate(this, "launch-template", {
      name: "minube",
      imageId: ami,
      blockDeviceMappings: [
        {
          deviceName: "/dev/sda1",
          ebs: {
            volumeSize: 16,
            volumeType: "gp2",
            encrypted: "true",
          },
        },
      ],
      instanceType: "t4g.micro",
      keyName: key.id,
      userData: readFileSync("assets/userdata.sh", "base64"),
      networkInterfaces: [
        {
          associatePublicIpAddress: "true",
          subnetId: config.vpc.subnets[0].id,
          securityGroups: [sg.id],
        },
      ],
      iamInstanceProfile: {
        arn: profile.arn,
      },
      tags: {
        Name: "minube",
      },
      metadataOptions: {
        httpTokens: "required",
      },
      tagSpecifications: [
        {
          resourceType: "instance",
          tags: {
            Name: "minube",
          },
        },
      ],
    });

    new AutoscalingGroup(this, "asg", {
      name: "minube",
      maxSize: 1,
      minSize: 1,
      desiredCapacity: 1,
      launchTemplate: {
        id: template.id,
        version: "$Latest",
      },
      vpcZoneIdentifier: [config.vpc.subnets[0].id],
    });
  }
}
