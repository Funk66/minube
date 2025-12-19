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
      ttl: 300,
      records: [
        '0 issue "amazon.com"',
        '0 issuewild "amazon.com"',
        '0 issue "letsencrypt.org"',
        '0 issuewild "letsencrypt.org"',
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

    new Route53Record(this, "mx-record", {
      name: this.zone.name,
      zoneId: this.zone.zoneId,
      type: "MX",
      ttl: 300,
      records: ["10 mail." + this.zone.name],
    });

    new Route53Record(this, "dkim-ecc-record", {
      name: "202512e._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "v=DKIM1; k=ed25519; h=sha256; p=ZYCK6R7Xca3xMOAq2lvIGchlqIAOKQwfgI3pRCW/Amk=",
      ],
    });

    new Route53Record(this, "dkim-rsa-record", {
      name: "202512e._domainkey." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        'v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4Yyq+OW6MdIQuVPP3+DQRTBBSNC4bu4FUj8i024+l1MCoLSNoftGbG6+N+zK41d16SY8zqmhkQn9J5IY6QY6TAPnp5os83dgXzpKNq2S1SyX5d5e1D554dAKaFN73QS/4JiFJNSTFLCt2M42sGoHcm2bA0EbWWHBxzhVuYU3ysJduSY3pwSwM0q" "1Hh3QVkVgvihMHwjvc0cwhuanEEHB4Kh2/i/595QpyQCQzrZ4xcVS781kfq2dvCm8+Z3QvxNR03sxuExn6ZbUvAOHCpkHLslx3yzN+5k4aDsVsPd3T+ADxfuq+VkYSaZ82dYJ8xBeEKAKfCY/BgIhjSwQWJAo9QIDAQAB',
      ],
    });

    new Route53Record(this, "srv-jmap-record", {
      name: "_jmap._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 443 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-caldavs-record", {
      name: "_caldavs._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 443 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-carddavs-record", {
      name: "_carddavs._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 443 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-imaps-record", {
      name: "_imaps._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 993 mail." + this.zone.name],
    });

    new Route53Record(this, "srv-submissions-record", {
      name: "_submissions._tcp." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "SRV",
      ttl: 300,
      records: ["0 1 465 mail." + this.zone.name],
    });

    new Route53Record(this, "cname-autoconfig-record", {
      name: "autoconfig." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["mail." + this.zone.name],
    });

    new Route53Record(this, "cname-autodiscover-record", {
      name: "autodiscover." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["mail." + this.zone.name],
    });

    new Route53Record(this, "cname-mta-sts-record", {
      name: "mta-sts." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "CNAME",
      ttl: 300,
      records: ["mail." + this.zone.name],
    });

    new Route53Record(this, "txt-mta-sts-record", {
      name: "_mta-sts." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=STSv1; id=20251219"],
    });

    new Route53Record(this, "txt-dmarc-record", {
      name: "_dmarc." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: [
        "v=DMARC1; p=reject; rua=mailto:postmaster@guirao.net; ruf=mailto:postmaster@guirao.net",
      ],
    });

    new Route53Record(this, "txt-smtp-record", {
      name: "_smtp._tls." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TXT",
      ttl: 300,
      records: ["v=TLSRPTv1; rua=mailto:postmaster@guirao.net"],
    });

    new Route53Record(this, "tlsa-25-record", {
      name: "_25._tcp.mail." + this.zone.name,
      zoneId: this.zone.zoneId,
      type: "TLSA",
      ttl: 300,
      records: [
        "3 0 1 5c58c5dfa04d72878f7e2df7834573e531cac422a0baee61c9d95fce7949d586",
        "3 0 2 b01b8ed87f2d6c2b9e63eb8295077d4a69552477fc8b12eb05c11ebb8b6e977eca9d53c3ff31ba2bc705b8df99f4c7042dca26bccefc93635e642c6736b36da1",
        "3 1 1 a76e9bd54df6589ac49591790a619fbdeaea807d256eb30aecd55aafe61ed175",
        "3 1 2 4cef54e6c1792eb6d51e25b9c99c430b65bb77df88603a2088ec277d9f174a5994156f3dbcec213b9bdb0842448ecc663fb7b33fb921d908db8e5e29a662a041",
        "2 0 1 83624fd338c8d9b023c18a67cb7a9c0519da43d11775b4c6cbdad45c3d997c52",
        "2 0 2 3565cd99fb0bccf03019e4d2276ca5d7c913a3af1ad58a95a8cad181699364f22fb6dc6cc01e071847db3336ae9a122b968d31c5be9a4443e145daba2a1782c6",
        "2 1 1 885bf0572252c6741dc9a52f5044487fef2a93b811cdedfad7624cc283b7cdd5",
        "2 1 2 89d8f1d26d16e94600405c8585e40ad1ecde0023cd447e8b39fd90bc8b482c7bd68d963156e5037023b144ec4caa03af8213296f3a498f69dee691a95a92d722",
      ],
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
