import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { S3BucketVersioningA } from "@cdktf/provider-aws/lib/s3-bucket-versioning";
import {
  S3BucketLifecycleConfiguration,
  S3BucketLifecycleConfigurationRule,
} from "@cdktf/provider-aws/lib/s3-bucket-lifecycle-configuration";

export class S3 extends Construct {
  public readonly buckets: Record<string, S3Bucket> = {};

  constructor(scope: Construct, id: string) {
    super(scope, id);

    for (const name of [
      "backups",
      "fs",
      "files",
      "storage",
      "photos",
      "mail",
      "docs",
    ]) {
      this.buckets[name] = new S3Bucket(this, `minube-${name}`, {
        bucket: `minube-${name}`,
      });

      new S3BucketVersioningA(this, `${name}-versioning`, {
        bucket: this.buckets[name].bucket,
        versioningConfiguration: {
          status: "Enabled",
        },
      });

      let lifecycleRules: S3BucketLifecycleConfigurationRule[] = [];
      if (name == "backups") {
        lifecycleRules = lifecycleRules.concat([
          {
            id: "Stalwart",
            status: "Enabled",
            expiration: [{ days: 30 }],
            filter: [{ prefix: "stalwart/" }],
          },
          {
            id: "Dawarich",
            status: "Enabled",
            expiration: [{ days: 30 }],
            filter: [{ prefix: "dawarich/" }],
          },
          {
            id: "Immich",
            status: "Enabled",
            expiration: [{ days: 30 }],
            filter: [{ prefix: "immich/" }],
          },
          {
            id: "Trashcan",
            status: "Enabled",
            abortIncompleteMultipartUpload: [{ daysAfterInitiation: 1 }],
            noncurrentVersionExpiration: [{ noncurrentDays: 10 }],
            filter: [{ prefix: "/" }],
          },
        ]);
      } else {
        lifecycleRules = lifecycleRules.concat([
          {
            id: "Trashcan",
            status: "Enabled",
            abortIncompleteMultipartUpload: [{ daysAfterInitiation: 7 }],
            noncurrentVersionExpiration: [{ noncurrentDays: 90 }],
            filter: [{ prefix: "" }],
          },
        ]);
      }

      new S3BucketLifecycleConfiguration(this, `${name}-lifecycle`, {
        bucket: this.buckets[name].bucket,
        rule: lifecycleRules,
      });
    }
  }
}
