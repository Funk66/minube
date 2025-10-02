import { readFileSync } from "fs";
import { Construct } from "constructs";
import { IamInstanceProfile } from "@cdktf/provider-aws/lib/iam-instance-profile";
import { IamPolicy } from "@cdktf/provider-aws/lib/iam-policy";
import { IamPolicyAttachment } from "@cdktf/provider-aws/lib/iam-policy-attachment";
import { IamRole } from "@cdktf/provider-aws/lib/iam-role";
import { Instance } from "@cdktf/provider-aws/lib/instance";
import { KeyPair } from "@cdktf/provider-aws/lib/key-pair";
import { SecurityGroup } from "@cdktf/provider-aws/lib/security-group";
import { DataAwsAmi } from "@cdktf/provider-aws/lib/data-aws-ami";
import { Eip } from "@cdktf/provider-aws/lib/eip";
import { EbsVolume } from "@cdktf/provider-aws/lib/ebs-volume";
import { VolumeAttachment } from "@cdktf/provider-aws/lib/volume-attachment";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { Route53Zone } from "@cdktf/provider-aws/lib/route53-zone";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";

interface EC2Config {
  vpc: string;
  subnet: string;
  buckets: {
    backups: S3Bucket;
    photos: S3Bucket;
    docs: S3Bucket;
    fs: S3Bucket;
  };
  hostedZone: Route53Zone;
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
            Resource: [
              `${config.buckets.backups.arn}/*`,
              `${config.buckets.fs.arn}/*`,
            ],
            Action: ["s3:GetObject*", "s3:PutObject*"],
          },
          {
            Sid: "ListBackups",
            Effect: "Allow",
            Resource: [config.buckets.backups.arn, config.buckets.fs.arn],
            Action: ["s3:ListBucket"],
          },
          {
            Sid: "ReadWriteAssetBackups",
            Effect: "Allow",
            Resource: [
              `${config.buckets.photos.arn}/*`,
              `${config.buckets.docs.arn}/*`,
            ],
            Action: [
              "s3:DeleteObject",
              "s3:GetObject",
              "s3:GetObjectTagging",
              "s3:PutObject",
              "s3:PutObjectTagging",
              "s3:AbortMultipartUpload",
            ],
          },
          {
            Sid: "ListAssets",
            Effect: "Allow",
            Resource: [config.buckets.photos.arn, config.buckets.docs.arn],
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
            Resource: [config.hostedZone.arn],
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
      nameRegex: "ubuntu/images/hvm-ssd-gp3/ubuntu-plucky-25.04-arm64-server",
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

    const instance = new Instance(this, "instance", {
      ami: ami,
      instanceType: "t4g.small",
      keyName: key.keyName,
      userData: readFileSync("assets/userdata.sh", "utf-8"),
      subnetId: config.subnet,
      vpcSecurityGroupIds: [sg.id],
      iamInstanceProfile: profile.id,
      availabilityZone: "eu-central-1b",
      tags: {
        Name: id,
      },
      rootBlockDevice: {
        volumeSize: 24,
        volumeType: "gp3",
        encrypted: true,
      },
      metadataOptions: {
        httpTokens: "required",
      },
    });

    const eip = new Eip(this, "eip", {
      instance: instance.id,
      tags: {
        Name: id,
      },
    });

    const volume = new EbsVolume(this, "volume", {
      availabilityZone: "eu-central-1b",
      type: "gp3",
      size: 60,
      encrypted: true,
      tags: {
        Name: "data",
      },
    });

    new VolumeAttachment(this, "attachment", {
      deviceName: "/dev/sdf",
      volumeId: volume.id,
      instanceId: instance.id,
    });

    // TODO: configure IPv6 subnet for Wireguard
    new Route53Record(this, `minube-a-record`, {
      name: `minube.${config.hostedZone.name}`,
      zoneId: config.hostedZone.id,
      type: "A",
      ttl: 300,
      records: [eip.publicIp],
    });

    for (const subdomain of ["photos", "docs", "calendar", "mail"]) {
      new Route53Record(this, `${subdomain}-a-record`, {
        name: `${subdomain}.${config.hostedZone.name}`,
        zoneId: config.hostedZone.id,
        type: "A",
        ttl: 300,
        records: [eip.publicIp],
      });

      new Route53Record(this, `${subdomain}-aaaa-record`, {
        name: `${subdomain}.${config.hostedZone.name}`,
        zoneId: config.hostedZone.id,
        type: "AAAA",
        ttl: 300,
        records: instance.ipv6Addresses,
      });
    }
  }
}
