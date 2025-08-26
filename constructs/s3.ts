import * as path from "path";
import * as fs from "fs";
import { Fn } from "cdktf";
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

    for (const name of ["backups", "fs", "storage", "photos", "mail", "docs"]) {
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

    this.backupFile(scope, "/etc/pihole/backup");
    this.backupFile(scope, "/etc/systemd/system/backup.service");
    this.backupFile(scope, "/etc/hosts");
    // this.backupFile(scope, "/etc/nginx/nginx.conf");
    this.backupFile(scope, "/etc/fail2ban/jail.local");
    this.backupFile(scope, "/etc/fail2ban/filter.d/nginx-default.conf");
    this.backupFile(scope, "/etc/systemd/system/fail2ban_exporter.service");

    this.uploadDirectory("fs", path.join(assets, "fs"));
  }

  private backupFile(scope: Construct, filepath: string) {
    const filename = path.basename(filepath);
    const source = `${assets}/${filename}`;
    return new S3Object(scope, filename, {
      bucket: this.buckets["backups"].bucket,
      key: filepath,
      source: source,
      storageClass: "GLACIER_IR",
      etag: Fn.filemd5(source),
    });
  }

  private uploadDirectory(bucketName: string, sourcePath: string) {
    const files = this.getAllFiles(sourcePath);
    for (const file of files) {
      const relativePath = path.relative(sourcePath, file);
      const key = relativePath.replace(/\\/g, "/"); // Ensure forward slashes for S3 key
      new S3Object(this, `s3-fs-object-${key.replace(/[\/.]/g, "-")}`, {
        bucket: this.buckets[bucketName].bucket,
        key: key,
        source: file,
        storageClass: "GLACIER_IR",
        etag: Fn.filemd5(file),
      });
    }
  }

  private getAllFiles(dirPath: string, arrayOfFiles: string[] = []): string[] {
    const files = fs.readdirSync(dirPath);

    files.forEach((file) => {
      const fullPath = path.join(dirPath, file);
      if (fs.statSync(fullPath).isDirectory()) {
        this.getAllFiles(fullPath, arrayOfFiles);
      } else {
        arrayOfFiles.push(fullPath);
      }
    });

    return arrayOfFiles;
  }
}
