import { readFileSync } from "fs";
import { Construct } from "constructs";
import { AutoscalingGroup } from "@cdktf/provider-aws/lib/autoscaling-group";
import { IamInstanceProfile } from "@cdktf/provider-aws/lib/iam-instance-profile";
import { IamPolicy } from "@cdktf/provider-aws/lib/iam-policy";
import { IamPolicyAttachment } from "@cdktf/provider-aws/lib/iam-policy-attachment";
import { IamRole } from "@cdktf/provider-aws/lib/iam-role";
import { KeyPair } from "@cdktf/provider-aws/lib/key-pair";
import { LaunchTemplate } from "@cdktf/provider-aws/lib/launch-template";
import { SecurityGroup } from "@cdktf/provider-aws/lib/security-group";
import { DataAwsAmi } from "@cdktf/provider-aws/lib/data-aws-ami";

interface EC2Config {
  vpc: string;
  subnet: string;
  backups: string;
  hostedZone: string;
}

export class EC2 extends Construct {
  constructor(scope: Construct, id: string, config: EC2Config) {
    super(scope, id);

    const assumeRolePolicy = JSON.stringify({
      Version: "2012-10-17",
      Statement: [
        {
          Sid: "EC2",
          Effect: "Allow",
          Principal: {
            Service: "ec2.amazonaws.com",
          },
          Action: "sts:AssumeRole",
        },
      ],
    });

    const ec2Policy = new IamPolicy(this, "ec2-policy", {
      name: id,
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ReadWriteBackups",
            Effect: "Allow",
            Resource: [`${config.backups}/*`],
            Action: ["s3:GetObject*", "s3:PutObject*"],
          },
          {
            Sid: "ListBackups",
            Effect: "Allow",
            Resource: [config.backups],
            Action: ["s3:ListBucket"],
          },
          {
            Sid: "ListHostedZones",
            Effect: "Allow",
            Resource: ["*"],
            Action: [
              "route53:ListHostedZones",
              "route53:ListHostedZonesByName",
            ],
          },
          {
            Sid: "WriteRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone],
            Action: [
              "route53:ListResourceRecordSets",
              "route53:ChangeResourceRecordSets",
            ],
          },
          {
            Sid: "GetChange",
            Effect: "Allow",
            Resource: ["arn:aws:route53:::change/*"],
            Action: ["route53:GetChange"],
          },
        ],
      }),
    });

    const ec2Role = new IamRole(this, "ec2-role", {
      name: id,
      assumeRolePolicy: assumeRolePolicy,
    });

    new IamPolicyAttachment(this, "ec2-role-attachment", {
      name: ec2Policy.name,
      roles: [ec2Role.id],
      policyArn: ec2Policy.arn,
    });

    const ami = new DataAwsAmi(this, "ubuntu", {
      mostRecent: true,
      owners: ["amazon"],
      nameRegex: "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server",
    }).id;

    const sg = new SecurityGroup(this, "sg", {
      name: id,
      vpcId: config.vpc,
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
          fromPort: 22,
          toPort: 22,
          ipv6CidrBlocks: ["::/0"],
          protocol: "TCP",
        },
        {
          fromPort: -1,
          toPort: -1,
          cidrBlocks: ["0.0.0.0/0"],
          protocol: "ICMP",
        },
        {
          fromPort: -1,
          toPort: -1,
          ipv6CidrBlocks: ["::/0"],
          protocol: "ICMPV6",
        },
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
        Name: id,
      },
    });

    const profile = new IamInstanceProfile(this, "profile", {
      name: ec2Role.id,
      role: ec2Role.id,
    });

    const key = new KeyPair(this, "key", {
      keyName: "ggaguilar",
      publicKey: readFileSync("./assets/key.pub", "utf8"),
    });

    const template = new LaunchTemplate(this, "launch-template", {
      name: id,
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
      instanceType: "t4g.nano",
      keyName: key.keyName,
      userData: readFileSync(`assets/userdata.sh`, "base64"),
      networkInterfaces: [
        {
          associatePublicIpAddress: "true",
          subnetId: config.subnet,
          securityGroups: [sg.id],
        },
      ],
      iamInstanceProfile: {
        arn: profile.arn,
      },
      tags: {
        Name: id,
      },
      metadataOptions: {
        httpTokens: "required",
      },
      tagSpecifications: [
        {
          resourceType: "instance",
          tags: {
            Name: id,
          },
        },
      ],
    });

    new AutoscalingGroup(this, "asg", {
      name: id,
      maxSize: 1,
      minSize: 1,
      desiredCapacity: 1,
      launchTemplate: {
        id: template.id,
        version: "$Latest",
      },
      vpcZoneIdentifier: [config.subnet],
    });
  }
}
