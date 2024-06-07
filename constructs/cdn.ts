import { Construct } from "constructs";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { AcmCertificate } from "@cdktf/provider-aws/lib/acm-certificate";
import { CloudfrontDistribution } from "@cdktf/provider-aws/lib/cloudfront-distribution";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { S3BucketLifecycleConfiguration } from "@cdktf/provider-aws/lib/s3-bucket-lifecycle-configuration";
import { S3BucketAcl } from "@cdktf/provider-aws/lib/s3-bucket-acl";
import { DataAwsCanonicalUserId } from "@cdktf/provider-aws/lib/data-aws-canonical-user-id";
import { DataAwsCloudfrontLogDeliveryCanonicalUserId } from "@cdktf/provider-aws/lib/data-aws-cloudfront-log-delivery-canonical-user-id";

export class CDN extends Construct {
  constructor(
    scope: Construct,
    name: string,
    zoneId: string,
    provider: AwsProvider
  ) {
    super(scope, name);

    const cert = new AcmCertificate(this, "cert", {
      provider: provider,
      domainName: "guirao.net",
      subjectAlternativeNames: ["*.guirao.net"],
      validationMethod: "DNS",
    });

    new Route53Record(this, "cert-validation", {
      name: cert.domainValidationOptions.get(0).resourceRecordName,
      zoneId: zoneId,
      type: cert.domainValidationOptions.get(0).resourceRecordType,
      ttl: 60,
      records: [cert.domainValidationOptions.get(0).resourceRecordValue],
    });

    const bucket = new S3Bucket(this, "logs-bucket", {
      bucket: "minube-logs",
    });

    const canonical_user = new DataAwsCanonicalUserId(this, "canonical-user");
    const cloudfront_user = new DataAwsCloudfrontLogDeliveryCanonicalUserId(
      this,
      "cloudfront-user"
    );

    new S3BucketLifecycleConfiguration(this, "logs-bucket-lifecycle", {
      bucket: bucket.bucket,
      rule: [
        {
          id: "Logs",
          status: "Enabled",
          expiration: { days: 90 },
          abortIncompleteMultipartUpload: { daysAfterInitiation: 7 },
        },
      ],
    });

    new S3BucketAcl(this, "logs-bucket-acl", {
      bucket: bucket.bucket,
      accessControlPolicy: {
        owner: canonical_user,
        grant: [
          {
            grantee: {
              id: canonical_user.id,
              type: "CanonicalUser",
            },
            permission: "FULL_CONTROL",
          },
          {
            grantee: {
              id: cloudfront_user.id,
              type: "CanonicalUser",
            },
            permission: "FULL_CONTROL",
          },
        ],
      },
    });

    const distribution = new CloudfrontDistribution(this, "cloudfront", {
      enabled: true,
      isIpv6Enabled: true,
      aliases: ["photos.guirao.net", "calendar.guirao.net"],
      viewerCertificate: {
        acmCertificateArn: cert.arn,
        sslSupportMethod: "sni-only",
      },
      restrictions: {
        geoRestriction: {
          locations: ["DE", "ES", "GB"],
          restrictionType: "whitelist",
        },
      },
      origin: [
        {
          domainName: "minube.guirao.net",
          originId: "minube",
          customOriginConfig: {
            httpPort: 80,
            httpsPort: 443,
            originProtocolPolicy: "https-only",
            originSslProtocols: ["TLSv1.2"],
          },
        },
      ],
      defaultCacheBehavior: {
        allowedMethods: [
          "GET",
          "HEAD",
          "OPTIONS",
          "PUT",
          "POST",
          "PATCH",
          "DELETE",
        ],
        cachedMethods: ["GET", "HEAD"],
        targetOriginId: "minube",
        viewerProtocolPolicy: "redirect-to-https",
        compress: true,
        defaultTtl: 3600,
        minTtl: 0,
        maxTtl: 86400,
        forwardedValues: {
          queryString: true,
          cookies: {
            forward: "all",
          },
          headers: ["*"],
          queryStringCacheKeys: ["*"],
        },
      },
      loggingConfig: {
        bucket: bucket.bucketDomainName,
        includeCookies: false,
        prefix: "cloudfront",
      },
    });

    const alias = {
      evaluateTargetHealth: true,
      name: distribution.domainName,
      zoneId: distribution.hostedZoneId,
    };

    new Route53Record(this, "photos-A", {
      name: "photos.guirao.net",
      zoneId: zoneId,
      type: "A",
      alias: alias,
    });

    new Route53Record(this, "photos-AAAA", {
      name: "photos.guirao.net",
      zoneId: zoneId,
      type: "AAAA",
      alias: alias,
    });

    new Route53Record(this, "calendar-A", {
      name: "calendar.guirao.net",
      zoneId: zoneId,
      type: "A",
      alias: alias,
    });

    new Route53Record(this, "calendar-AAAA", {
      name: "calendar.guirao.net",
      zoneId: zoneId,
      type: "AAAA",
      alias: alias,
    });
  }
}
