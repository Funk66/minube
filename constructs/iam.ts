import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { IamUser } from "@cdktf/provider-aws/lib/iam-user";
import { IamPolicy } from "@cdktf/provider-aws/lib/iam-policy";
import { IamUserPolicyAttachment } from "@cdktf/provider-aws/lib/iam-user-policy-attachment";
import { IamAccessKey } from "@cdktf/provider-aws/lib/iam-access-key";
import { Route53Zone } from "@cdktf/provider-aws/lib/route53-zone";

interface RoleConfig {
  photos: S3Bucket;
  docs: S3Bucket;
  mail: S3Bucket;
  fs: S3Bucket;
  domain: string;
  hostedZone: Route53Zone;
}

export class IAM extends Construct {
  constructor(scope: Construct, id: string, config: RoleConfig) {
    super(scope, id);

    const grafanaPolicy = new IamPolicy(this, "grafana-policy", {
      name: "grafana",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "AllowReadingMetricsFromCloudWatch",
            Effect: "Allow",
            Action: [
              "CloudWatch:DescribeAlarmsForMetric",
              "CloudWatch:DescribeAlarmHistory",
              "CloudWatch:DescribeAlarms",
              "CloudWatch:ListMetrics",
              "CloudWatch:GetMetricData",
              "CloudWatch:GetInsightRuleReport",
            ],
            Resource: "*",
          },
          {
            Sid: "AllowReadingResourceMetricsFromPerformanceInsights",
            Effect: "Allow",
            Action: "pi:GetResourceMetrics",
            Resource: "*",
          },
          {
            Sid: "AllowReadingLogsFromCloudWatch",
            Effect: "Allow",
            Action: [
              "logs:DescribeLogGroups",
              "logs:GetLogGroupFields",
              "logs:StartQuery",
              "logs:StopQuery",
              "logs:GetQueryResults",
              "logs:GetLogEvents",
            ],
            Resource: "*",
          },
          {
            Sid: "AllowReadingTagsInstancesRegionsFromEC2",
            Effect: "Allow",
            Action: [
              "ec2:DescribeTags",
              "ec2:DescribeInstances",
              "ec2:DescribeRegions",
            ],
            Resource: "*",
          },
          {
            Sid: "AllowReadingResourcesForTags",
            Effect: "Allow",
            Action: "tag:GetResources",
            Resource: "*",
          },
          {
            Action: ["oam:ListSinks", "oam:ListAttachedLinks"],
            Effect: "Allow",
            Resource: "*",
          },
        ],
      }),
    });

    const grafanaUser = new IamUser(this, "grafana-user", {
      name: "grafana",
    });

    new IamUserPolicyAttachment(this, "grafana-user-attachment", {
      user: grafanaUser.name,
      policyArn: grafanaPolicy.arn,
    });

    new IamAccessKey(this, "grafana-access-key", {
      user: grafanaUser.name,
    });

    const officePolicy = new IamPolicy(this, "office-policy", {
      name: "office",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ListHostedZones",
            Effect: "Allow",
            Resource: ["*"],
            Action: ["route53:ListHostedZones"],
          },
          {
            Sid: "ChangeRecordSets",
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

    const stalwartPolicy = new IamPolicy(this, "stalwart-policy", {
      name: "stalwart",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ReadWriteMail",
            Effect: "Allow",
            Resource: [config.mail.arn, `${config.mail.arn}/*`],
            Action: ["s3:*"],
          },
          {
            Sid: "AmazonSesSendingAccess",
            Effect: "Allow",
            Resource: ["*"],
            Action: ["ses:SendRawEmail"],
          },
        ],
      }),
    });

    const stalwartUser = new IamUser(this, "stalwart-user", {
      name: "stalwart",
    });

    new IamUserPolicyAttachment(this, "stalwart-user-attachment", {
      user: stalwartUser.name,
      policyArn: stalwartPolicy.arn,
    });

    new IamAccessKey(this, "stalwart-access-key", {
      user: stalwartUser.name,
    });

    const casaPolicy = new IamPolicy(this, "casa-policy", {
      name: "casa",
      policy: JSON.stringify({
        Version: "2012-10-17",
        Statement: [
          {
            Sid: "ListRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone.arn],
            Action: ["route53:ListResourceRecordSets"],
          },
          {
            Sid: "WriteRecordSets",
            Effect: "Allow",
            Resource: [config.hostedZone.arn],
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
