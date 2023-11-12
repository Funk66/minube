import * as path from "path";
import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { S3Object } from "@cdktf/provider-aws/lib/s3-object";
import { S3BucketVersioningA } from "@cdktf/provider-aws/lib/s3-bucket-versioning";
import { S3BucketLifecycleConfiguration } from "@cdktf/provider-aws/lib/s3-bucket-lifecycle-configuration";
import { S3BucketServerSideEncryptionConfigurationA } from "@cdktf/provider-aws/lib/s3-bucket-server-side-encryption-configuration";

const assets = path.resolve(__dirname, "../assets");

export class Buckets extends Construct {
  public readonly backups: S3Bucket;
  public readonly storage: S3Bucket;
  public readonly photos: S3Bucket;

  constructor(scope: Construct, id: string) {
    super(scope, id);

    this.backups = new S3Bucket(this, "minube-backups", {
      bucket: "minube-backups",
    });

    this.storage = new S3Bucket(this, "minube-storage", {
      bucket: "minube-storage",
    });

    this.photos = new S3Bucket(this, "minube-photos", {
      bucket: "minube-photos",
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

    new S3BucketServerSideEncryptionConfigurationA(this, "backups-encryption", {
      bucket: this.photos.bucket,
      rule: [
        {
          applyServerSideEncryptionByDefault: {
            sseAlgorithm: "AES256",
          },
        },
      ],
    });

    this.backupFile(scope, "/etc/pihole/backup");
    this.backupFile(scope, "/etc/systemd/system/backup.service");
    this.backupFile(scope, "/etc/hosts");
  }

  private backupFile(scope: Construct, filepath: string) {
    const filename = path.basename(filepath);
    return new S3Object(scope, filename, {
      bucket: this.backups.bucket,
      key: filepath,
      source: `${assets}/${filename}`,
      storageClass: "GLACIER_IR",
    });
  }
}
