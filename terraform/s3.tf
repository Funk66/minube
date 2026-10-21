resource "aws_s3_bucket" "backups" {
  bucket = "minube-backups"
}

resource "aws_s3_bucket_versioning" "backups_versioning" {
  bucket = aws_s3_bucket.backups.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backups_lifecycle" {
  bucket = aws_s3_bucket.backups.bucket
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

resource "aws_s3_bucket" "fs" {
  bucket = "minube-fs"
}

resource "aws_s3_bucket_versioning" "fs_versioning" {
  bucket = aws_s3_bucket.fs.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "fs_lifecycle" {
  bucket = aws_s3_bucket.fs.bucket
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

resource "aws_s3_bucket" "files" {
  bucket = "minube-files"
}

resource "aws_s3_bucket_versioning" "files_versioning" {
  bucket = aws_s3_bucket.files.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "files_lifecycle" {
  bucket = aws_s3_bucket.files.bucket
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

resource "aws_s3_bucket" "storage" {
  bucket = "minube-storage"
}

resource "aws_s3_bucket_versioning" "storage_versioning" {
  bucket = aws_s3_bucket.storage.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "storage_lifecycle" {
  bucket = aws_s3_bucket.storage.bucket
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

resource "aws_s3_bucket" "photos" {
  bucket = "minube-photos"
}

resource "aws_s3_bucket_versioning" "photos_versioning" {
  bucket = aws_s3_bucket.photos.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "photos_lifecycle" {
  bucket = aws_s3_bucket.photos.bucket
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

resource "aws_s3_bucket" "mail" {
  bucket = "minube-mail"
}

resource "aws_s3_bucket_versioning" "mail_versioning" {
  bucket = aws_s3_bucket.mail.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "mail_lifecycle" {
  bucket = aws_s3_bucket.mail.bucket
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

resource "aws_s3_bucket" "docs" {
  bucket = "minube-docs"
}

resource "aws_s3_bucket_versioning" "docs_versioning" {
  bucket = aws_s3_bucket.docs.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "docs_lifecycle" {
  bucket = aws_s3_bucket.docs.bucket
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
