import { Construct } from "constructs";
import { AwsProvider } from "@cdktf/provider-aws/lib/provider";
import { AcmCertificate } from "@cdktf/provider-aws/lib/acm-certificate";
import { CloudfrontDistribution } from "@cdktf/provider-aws/lib/cloudfront-distribution";
import { Route53Record } from "@cdktf/provider-aws/lib/route53-record";

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
