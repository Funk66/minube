import * as path from "path";
import { Construct } from "constructs";
import { S3Bucket } from "@cdktf/provider-aws/lib/s3-bucket";
import { S3Object } from "@cdktf/provider-aws/lib/s3-object";
import { S3BucketVersioningA } from "@cdktf/provider-aws/lib/s3-bucket-versioning";
import { S3BucketLifecycleConfiguration } from "@cdktf/provider-aws/lib/s3-bucket-lifecycle-configuration";

const assets = path.resolve(__dirname, "../assets");

export class S3 extends Construct {
  public readonly buckets: Record<string, S3Bucket> = {};

  constructor(scope: Construct, id: string) {
    super(scope, id);

    for (const name of ["backups", "storage", "photos", "mail"]) {
      this.buckets[name] = new S3Bucket(this, `minube-${name}`, {
        bucket: `minube-${name}`,
      });

      new S3BucketVersioningA(this, `${name}-versioning`, {
        bucket: this.buckets[name].bucket,
        versioningConfiguration: {
          status: "Enabled",
        },
      });

      new S3BucketLifecycleConfiguration(this, `${name}-lifecycle`, {
        bucket: this.buckets[name].bucket,
        rule: [
          {
            id: "Trashcan",
            status: "Enabled",
            abortIncompleteMultipartUpload: { daysAfterInitiation: 7 },
            noncurrentVersionExpiration: { noncurrentDays: 90 },
          },
        ],
      });
    }

    this.backupFile(scope, "/gateway/etc/pihole/backup");
    this.backupFile(scope, "/gateway/etc/systemd/system/backup.service");
    this.backupFile(scope, "/gateway/etc/hosts");
    this.backupFile(scope, "/gateway/etc/caddy/Caddyfile");
    this.backupFile(scope, "/mail/etc/backup");
    this.backupFile(scope, "/mail/etc/systemd/system/backup.service");
  }

  private backupFile(scope: Construct, filepath: string) {
    const filename = path.basename(filepath);
    const service = path.dirname(filepath).split("/")[1];
    return new S3Object(scope, `${service}-${filename}`, {
      bucket: this.buckets["backups"].bucket,
      key: filepath,
      source: `${assets}/${service}/${filename}`,
      storageClass: "GLACIER_IR",
    });
  }
}
