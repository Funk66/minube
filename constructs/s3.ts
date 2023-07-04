import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { S3BucketVersioningA } from "@cdktf/provider-aws/lib/s3-bucket-versioning";
import { S3BucketLifecycleConfiguration } from "@cdktf/provider-aws/lib/s3-bucket-lifecycle-configuration";

export class Buckets extends Construct {
  public readonly backups: S3Bucket;
  public readonly storage: S3Bucket;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.backups = new S3Bucket(this, "minube-backups", {
      bucket: "minube-backups",
    });

    this.storage = new S3Bucket(this, "minube-storage", {
      bucket: "minube-storage",
    });

    new S3BucketVersioningA(this, "backups-versioning", {
      bucket: this.backups.bucket,
      versioningConfiguration: {
        status: "Enabled",
      },
    });

    new S3BucketLifecycleConfiguration(this, "backups-lifecycle", {
      bucket: this.backups.bucket,
      rule: [
        {
          id: "Trashcan",
          status: "Enabled",
          abortIncompleteMultipartUpload: { daysAfterInitiation: 7 },
          noncurrentVersionExpiration: { noncurrentDays: 30 },
        },
      ],
    });
  }
}
