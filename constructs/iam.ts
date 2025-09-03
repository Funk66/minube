import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { IamUser } from "@cdktf/provider-aws/lib/iam-user";
import { IamPolicy } from "@cdktf/provider-aws/lib/iam-policy";
import { IamUserPolicyAttachment } from "@cdktf/provider-aws/lib/iam-user-policy-attachment";
import { IamAccessKey } from "@cdktf/provider-aws/lib/iam-access-key";

interface RoleConfig {
  photos: S3Bucket;
  docs: S3Bucket;
  mail: S3Bucket;
  fs: S3Bucket;
  domain: string;
  hostedZone: string;
}

export class IAM extends Construct {
  constructor(scope: Construct, id: string, config: RoleConfig) {
    super(scope, id);

    const officePolicy = new IamPolicy(this, "office-policy", {
      name: "office",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ReadWriteAssetBackups",
            Effect: "Allow",
            Resource: [`${config.docs.arn}/*`],
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
            Resource: [config.photos.arn, config.docs.arn],
            Action: ["s3:ListBucket"],
          },
          {
            Sid: "ReadWriteMail",
            Effect: "Allow",
            Resource: [config.mail.arn, `${config.mail.arn}/*`],
            Action: ["s3:*"],
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
            Resource: [config.hostedZone],
            Action: ["route53:ListResourceRecordSets"],
          },
          {
            Sid: "GetChange",
            Effect: "Allow",
            Resource: ["arn:aws:route53:::change/*"],
            Action: ["route53:GetChange"],
          },
          {
            Sid: "WriteRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone],
            Action: ["route53:ChangeResourceRecordSets"],
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
            Sid: "ListRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone],
            Action: ["route53:ListResourceRecordSets"],
          },
          {
            Sid: "WriteRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone],
            Action: ["route53:ChangeResourceRecordSets"],
            Condition: {
              StringEquals: {
                "route53:ChangeResourceRecordSetsNormalizedRecordNames": `casa.${config.domain}`,
              },
            },
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
