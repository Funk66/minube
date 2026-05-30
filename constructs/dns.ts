import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { Construct } from "constructs";
import { DataAwsCallerIdentity } from "@cdktf/provider-aws/lib/data-aws-caller-identity";
import { DataAwsIamPolicyDocument } from "@cdktf/provider-aws/lib/data-aws-iam-policy-document";
import { KmsAlias } from "@cdktf/provider-aws/lib/kms-alias";
import { KmsKey } from "@cdktf/provider-aws/lib/kms-key";
import { Route53HostedZoneDnssec } from "@cdktf/provider-aws/lib/route53-hosted-zone-dnssec";
import { Route53KeySigningKey } from "@cdktf/provider-aws/lib/route53-key-signing-key";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";
import { Route53Zone } from "@cdktf/provider-aws/lib/route53-zone";

export class DNS extends Construct {
  zone: Route53Zone;

  constructor(scope: Construct, name: string, provider: AwsProvider) {
    super(scope, name);

    this.zone = new Route53Zone(this, "zone", {
      name: "guirao.net",
    });

    new Route53Record(this, "caa-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CAA",
      ttl: 60,
      records: [
        '0 issue "amazon.com"',
        '0 issuewild "amazon.com"',
        '0 issue "letsencrypt.org"',
        '0 issuewild "letsencrypt.org"',
        '0 iodef "mailto:acme@guirao.net"',
      ],
    });

    const callerIdentity = new DataAwsCallerIdentity(this, "current");

    const dnssecKeyPolicy = new DataAwsIamPolicyDocument(
      this,
      "dnssec-policy",
      {
        statement: [
          {
            actions: [
              "kms:DescribeKey",
              "kms:GetPublicKey",
              "kms:Sign",
              "kms:Verify",
            ],
            effect: "Allow",
            principals: [
              {
                type: "Service",
                identifiers: ["dnssec-route53.amazonaws.com"],
              },
            ],
            resources: ["*"],
            sid: "Allow administration of the key",
          },
          {
            actions: ["kms:*"],
            effect: "Allow",
            principals: [
              {
                type: "AWS",
                identifiers: [`arn:aws:iam::${callerIdentity.accountId}:root`],
              },
            ],
            resources: ["*"],
            sid: "Allow IAM user permissions",
          },
        ],
      }
    );

    const kmsKey = new KmsKey(this, "kms-key", {
      provider: provider,
      description: `KMS key for DNSSEC in ${this.zone.name}`,
      customerMasterKeySpec: "ECC_NIST_P256",
      deletionWindowInDays: 7,
      keyUsage: "SIGN_VERIFY",
      policy: dnssecKeyPolicy.json,
    });

    new KmsAlias(this, "kms-key-alias", {
      provider: provider,
      name: "alias/dnssec",
      targetKeyId: kmsKey.keyId,
    });

    const keySigningKey = new Route53KeySigningKey(this, "key-signing-key", {
      hostedZoneId: this.zone.zoneId,
      keyManagementServiceArn: kmsKey.arn,
      name: "guirao-net-dnssec",
    });

    new Route53HostedZoneDnssec(this, "dnssec", {
      hostedZoneId: keySigningKey.hostedZoneId,
    });

    new Route53Record(this, "funk66-cname", {
      name: "guillermo." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["funk66.github.io"],
    });

    new Route53Record(this, "google-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "google-site-verification=jm-wNSxSnrlZD5TeJzZMYOIsa8AdIDRNX9TKuAX0h5c",
      ],
    });
  }
}
