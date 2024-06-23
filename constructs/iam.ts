import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { IamRole } from "@cdktf/provider-aws/lib/iam-role";
import { IamUser } from "@cdktf/provider-aws/lib/iam-user";
import { IamPolicy } from "@cdktf/provider-aws/lib/iam-policy";
import { IamPolicyAttachment } from "@cdktf/provider-aws/lib/iam-policy-attachment";
import { IamUserPolicyAttachment } from "@cdktf/provider-aws/lib/iam-user-policy-attachment";
import { IamAccessKey } from "@cdktf/provider-aws/lib/iam-access-key";

interface RoleConfig {
  backups: S3Bucket;
  photos: S3Bucket;
  hostedZone: string;
}

export class Role extends Construct {
  public readonly id: string;

  constructor(scope: Construct, id: string, config: RoleConfig) {
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
      name: "backups",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ReadWriteBackups",
            Effect: "Allow",
            Resource: [`${config.backups.arn}/*`],
            Action: ["s3:GetObject*", "s3:PutObject*"],
          },
          {
            Sid: "ListBackups",
            Effect: "Allow",
            Resource: [config.backups.arn],
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
            Resource: [config.hostedZone],
            Action: [
              "route53:ListResourceRecordSets",
              "route53:ChangeResourceRecordSets",
            ],
          },
        ],
      }),
    });

    const ec2Role = new IamRole(this, "ec2-role", {
      name: "minube",
      assumeRolePolicy: assumeRolePolicy,
    });

    this.id = ec2Role.id;

    new IamPolicyAttachment(this, "ec2-role-attachment", {
      name: ec2Policy.name,
      roles: [ec2Role.id],
      policyArn: ec2Policy.arn,
    });

    const officePolicy = new IamPolicy(this, "office-policy", {
      name: "office",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ReadWriteBackups",
            Effect: "Allow",
            Resource: [`${config.photos.arn}/*`],
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
            Sid: "ListBackups",
            Effect: "Allow",
            Resource: [config.photos.arn],
            Action: ["s3:ListBucket"],
          },
        ],
      }),
    });

    const officeUser = new IamUser(this, "office-user", {
      name: "office",
    });

    new IamUserPolicyAttachment(this, "office-user-attachment", {
      user: officeUser.name,
      policyArn: officePolicy.arn,
    });

    new IamAccessKey(this, "office-access-key", {
      user: officeUser.name,
    });

    const casaPolicy = new IamPolicy(this, "casa-policy", {
      name: "casa",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "WriteRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone],
            Action: [
              "route53:ListResourceRecordSets",
              "route53:ChangeResourceRecordSets",
            ],
          },
        ],
      }),
    });

    const casaUser = new IamUser(this, "casa-user", {
      name: "casa",
    });

    new IamUserPolicyAttachment(this, "casa-user-attachment", {
      user: casaUser.name,
      policyArn: casaPolicy.arn,
    });

    new IamAccessKey(this, "casa-access-key", {
      user: casaUser.name,
    });
  }
}
