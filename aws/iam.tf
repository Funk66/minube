data "aws_iam_policy_document" "grafana" {
  statement {
    sid    = "AllowReadingMetricsFromCloudWatch"
    effect = "Allow"

    actions = [
      "CloudWatch:DescribeAlarmsForMetric",
      "CloudWatch:DescribeAlarmHistory",
      "CloudWatch:DescribeAlarms",
      "CloudWatch:ListMetrics",
      "CloudWatch:GetMetricData",
      "CloudWatch:GetInsightRuleReport",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowReadingResourceMetricsFromPerformanceInsights"
    effect = "Allow"

    actions = [
      "pi:GetResourceMetrics",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowReadingLogsFromCloudWatch"
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowReadingTagsInstancesRegionsFromEC2"
    effect = "Allow"

    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowReadingResourcesForTags"
    effect = "Allow"

    actions = [
      "tag:GetResources",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "oam:ListSinks",
      "oam:ListAttachedLinks",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "grafana_policy" {
  name   = "grafana"
  policy = data.aws_iam_policy_document.grafana.json
}

resource "aws_iam_user" "grafana" {
  name = "grafana"
}

resource "aws_iam_user_policy_attachment" "grafana_attachment" {
  user       = aws_iam_user.grafana.name
  policy_arn = aws_iam_policy.grafana_policy.arn
}

resource "aws_iam_access_key" "grafana_key" {
  user = aws_iam_user.grafana.name
}

data "aws_iam_policy_document" "office" {
  statement {
    sid    = "ListHostedZones"
    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "ChangeRecordSets"
    effect = "Allow"

    actions = [
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
    ]

    resources = [
      aws_route53_zone.zone.arn,
    ]
  }

  statement {
    sid    = "GetChange"
    effect = "Allow"

    actions = [
      "route53:GetChange",
    ]

    resources = [
      "arn:aws:route53:::change/*",
    ]
  }

  statement {
    sid    = "AccessS3"
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.docs.arn,
    ]
  }

  statement {
    sid    = "ListAssets"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.photos.arn,
      aws_s3_bucket.docs.arn,
    ]
  }

  statement {
    sid    = "ReadWriteAssetBackups"
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:AbortMultipartUpload",
    ]

    resources = [
      "${aws_s3_bucket.photos.arn}/*",
      "${aws_s3_bucket.docs.arn}/*",
    ]
  }

  statement {
    sid    = "BackupDawarich"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]

    resources = [
      "${aws_s3_bucket.backups.arn}/dawarich/*",
    ]
  }

  statement {
    sid    = "ListBackupsDawarich"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]

    resources = [
      aws_s3_bucket.backups.arn,
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        "dawarich/*",
      ]
    }
  }
}

resource "aws_iam_policy" "office_policy" {
  name   = "office"
  policy = data.aws_iam_policy_document.office.json
}

resource "aws_iam_user" "office" {
  name = "office"
}

resource "aws_iam_user_policy_attachment" "office_attachment" {
  user       = aws_iam_user.office.name
  policy_arn = aws_iam_policy.office_policy.arn
}

resource "aws_iam_access_key" "office_key" {
  user = aws_iam_user.office.name
}

data "aws_iam_policy_document" "stalwart" {
  statement {
    sid    = "ReadWriteMail"
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.mail.arn,
      "${aws_s3_bucket.mail.arn}/*",
    ]
  }

  statement {
    sid    = "AmazonSesSendingAccess"
    effect = "Allow"

    actions = [
      "ses:SendRawEmail",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "Route53UpdateRecords"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      aws_route53_zone.zone.arn,
    ]
  }

  statement {
    sid    = "Route53GetChange"
    effect = "Allow"

    actions = [
      "route53:GetChange",
    ]

    resources = [
      "arn:aws:route53:::change/*",
    ]
  }
}

resource "aws_iam_policy" "stalwart_policy" {
  name   = "stalwart"
  policy = data.aws_iam_policy_document.stalwart.json
}

resource "aws_iam_user" "stalwart" {
  name = "stalwart"
}

resource "aws_iam_user_policy_attachment" "stalwart_attachment" {
  user       = aws_iam_user.stalwart.name
  policy_arn = aws_iam_policy.stalwart_policy.arn
}

resource "aws_iam_access_key" "stalwart_key" {
  user = aws_iam_user.stalwart.name
}

data "aws_iam_policy_document" "casa" {
  statement {
    sid    = "ListRecordSets"
    effect = "Allow"

    actions = [
      "route53:ListResourceRecordSets",
    ]

    resources = [
      aws_route53_zone.zone.arn,
    ]
  }

  statement {
    sid    = "WriteRecordSets"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
    ]

    resources = [
      aws_route53_zone.zone.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "route53:ChangeResourceRecordSetsNormalizedRecordNames"
      values = [
        "casa.${aws_route53_zone.zone.name}",
      ]
    }
  }
}

resource "aws_iam_policy" "casa_policy" {
  name   = "casa"
  policy = data.aws_iam_policy_document.casa.json
}

resource "aws_iam_user" "casa" {
  name = "casa"
}

resource "aws_iam_user_policy_attachment" "casa_attachment" {
  user       = aws_iam_user.casa.name
  policy_arn = aws_iam_policy.casa_policy.arn
}

resource "aws_iam_access_key" "casa_key" {
  user = aws_iam_user.casa.name
}

data "aws_iam_policy_document" "fritz" {
  statement {
    sid    = "UpdateRecordSets"
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
    ]

    resources = [
      "arn:aws:route53:::hostedzone/Z08454293CYFNUE96599",
    ]
  }
}

resource "aws_iam_policy" "fritz_policy" {
  name   = "fritz"
  policy = data.aws_iam_policy_document.fritz.json
}

resource "aws_iam_user" "fritz" {
  name = "fritzr53"
}

resource "aws_iam_user_policy_attachment" "fritz_attachment" {
  user       = aws_iam_user.fritz.name
  policy_arn = aws_iam_policy.fritz_policy.arn
}

resource "aws_iam_access_key" "fritz_key" {
  user = aws_iam_user.fritz.name
}
