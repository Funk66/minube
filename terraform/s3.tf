resource "aws_s3_bucket" "buckets_minube-backups_0F1ACE02" {
  bucket = "minube-backups"
}

resource "aws_s3_bucket_versioning" "buckets_backups-versioning_50248965" {
  bucket = aws_s3_bucket.buckets_minube-backups_0F1ACE02.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_backups-lifecycle_FA66DD08" {
  bucket = aws_s3_bucket.buckets_minube-backups_0F1ACE02.bucket
  rule {
    id     = "Stalwart"
    status = "Enabled"
    filter {
      prefix = "stalwart/"
    }
    expiration {
      days = 30
    }
  }
  rule {
    id     = "Dawarich"
    status = "Enabled"
    filter {
      prefix = "dawarich/"
    }
    expiration {
      days = 30
    }
  }
  rule {
    id     = "Immich"
    status = "Enabled"
    filter {
      prefix = "immich/"
    }
    expiration {
      days = 30
    }
  }
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = "/"
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
    noncurrent_version_expiration {
      noncurrent_days = 10
    }
  }
}

resource "aws_s3_bucket" "buckets_minube-fs_5D278F8B" {
  bucket = "minube-fs"
}

resource "aws_s3_bucket_versioning" "buckets_fs-versioning_069DB685" {
  bucket = aws_s3_bucket.buckets_minube-fs_5D278F8B.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_fs-lifecycle_20D547F5" {
  bucket = aws_s3_bucket.buckets_minube-fs_5D278F8B.bucket
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket" "buckets_minube-files_0207517F" {
  bucket = "minube-files"
}

resource "aws_s3_bucket_versioning" "buckets_files-versioning_DC55B346" {
  bucket = aws_s3_bucket.buckets_minube-files_0207517F.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_files-lifecycle_7E91F0D4" {
  bucket = aws_s3_bucket.buckets_minube-files_0207517F.bucket
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket" "buckets_minube-storage_A1ADE638" {
  bucket = "minube-storage"
}

resource "aws_s3_bucket_versioning" "buckets_storage-versioning_FA7AAE6C" {
  bucket = aws_s3_bucket.buckets_minube-storage_A1ADE638.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_storage-lifecycle_12A6B5B2" {
  bucket = aws_s3_bucket.buckets_minube-storage_A1ADE638.bucket
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket" "buckets_minube-photos_3472E0E4" {
  bucket = "minube-photos"
}

resource "aws_s3_bucket_versioning" "buckets_photos-versioning_42CA05AD" {
  bucket = aws_s3_bucket.buckets_minube-photos_3472E0E4.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_photos-lifecycle_D1433BBC" {
  bucket = aws_s3_bucket.buckets_minube-photos_3472E0E4.bucket
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket" "buckets_minube-mail_2017F00D" {
  bucket = "minube-mail"
}

resource "aws_s3_bucket_versioning" "buckets_mail-versioning_FB59FB1A" {
  bucket = aws_s3_bucket.buckets_minube-mail_2017F00D.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_mail-lifecycle_EC4CE7EE" {
  bucket = aws_s3_bucket.buckets_minube-mail_2017F00D.bucket
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

resource "aws_s3_bucket" "buckets_minube-docs_08FE3C73" {
  bucket = "minube-docs"
}

resource "aws_s3_bucket_versioning" "buckets_docs-versioning_4EC986D3" {
  bucket = aws_s3_bucket.buckets_minube-docs_08FE3C73.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "buckets_docs-lifecycle_BCB6FB67" {
  bucket = aws_s3_bucket.buckets_minube-docs_08FE3C73.bucket
  rule {
    id     = "Trashcan"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
