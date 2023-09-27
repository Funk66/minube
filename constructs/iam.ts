import { Construct } from "constructs";
import { IamRole } from "@cdktf/provider-aws/lib/iam-role";
import { IamPolicy } from "@cdktf/provider-aws/lib/iam-policy";
import { IamPolicyAttachment } from "@cdktf/provider-aws/lib/iam-policy-attachment";

interface RoleConfig {
  backups: string;
}

export class Role extends Construct {
  public readonly id: string;

  constructor(scope: Construct, id: string, config: RoleConfig) {
    super(scope, id);

    this.id = new IamRole(this, "role", {
      name: "minube",
      assumeRolePolicy: JSON.stringify({
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
      }),
    }).id;

    const policy = new IamPolicy(this, "policy", {
      name: "backups",
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
            Resource: [`${config.backups}`],
            Action: ["s3:ListBucket"]
          },
        ],
      }),
    });

    new IamPolicyAttachment(this, "attachment", {
      name: "backups",
      roles: [this.id],
      policyArn: policy.arn,
    });
  }
}
