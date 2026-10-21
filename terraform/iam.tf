resource "aws_iam_policy" "grafana_policy" {
  name   = "grafana"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AllowReadingMetricsFromCloudWatch\",\"Effect\":\"Allow\",\"Action\":[\"CloudWatch:DescribeAlarmsForMetric\",\"CloudWatch:DescribeAlarmHistory\",\"CloudWatch:DescribeAlarms\",\"CloudWatch:ListMetrics\",\"CloudWatch:GetMetricData\",\"CloudWatch:GetInsightRuleReport\"],\"Resource\":\"*\"},{\"Sid\":\"AllowReadingResourceMetricsFromPerformanceInsights\",\"Effect\":\"Allow\",\"Action\":\"pi:GetResourceMetrics\",\"Resource\":\"*\"},{\"Sid\":\"AllowReadingLogsFromCloudWatch\",\"Effect\":\"Allow\",\"Action\":[\"logs:DescribeLogGroups\",\"logs:GetLogGroupFields\",\"logs:StartQuery\",\"logs:StopQuery\",\"logs:GetQueryResults\",\"logs:GetLogEvents\"],\"Resource\":\"*\"},{\"Sid\":\"AllowReadingTagsInstancesRegionsFromEC2\",\"Effect\":\"Allow\",\"Action\":[\"ec2:DescribeTags\",\"ec2:DescribeInstances\",\"ec2:DescribeRegions\"],\"Resource\":\"*\"},{\"Sid\":\"AllowReadingResourcesForTags\",\"Effect\":\"Allow\",\"Action\":\"tag:GetResources\",\"Resource\":\"*\"},{\"Action\":[\"oam:ListSinks\",\"oam:ListAttachedLinks\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
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

resource "aws_iam_policy" "office_policy" {
  name   = "office"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ListHostedZones\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"route53:ListHostedZones\"]},{\"Sid\":\"ChangeRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.zone.arn}\"],\"Action\":[\"route53:ListResourceRecordSets\",\"route53:ChangeResourceRecordSets\"]},{\"Sid\":\"GetChange\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:route53:::change/*\"],\"Action\":[\"route53:GetChange\"]},{\"Sid\":\"AccessS3\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.docs.arn}\"],\"Action\":[\"s3:*\"]},{\"Sid\":\"ListAssets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.photos.arn}\",\"${aws_s3_bucket.docs.arn}\"],\"Action\":[\"s3:ListBucket\"]},{\"Sid\":\"ReadWriteAssetBackups\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.photos.arn}/*\",\"${aws_s3_bucket.docs.arn}/*\"],\"Action\":[\"s3:DeleteObject\",\"s3:GetObject\",\"s3:GetObjectTagging\",\"s3:PutObject\",\"s3:PutObjectTagging\",\"s3:AbortMultipartUpload\"]},{\"Sid\":\"BackupDawarich\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.backups.arn}/dawarich/*\"],\"Action\":[\"s3:PutObject\",\"s3:GetObject\",\"s3:GetObjectVersion\"]},{\"Sid\":\"ListBackupsDawarich\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.backups.arn}\"],\"Action\":[\"s3:ListBucket\",\"s3:ListBucketVersions\"],\"Condition\":{\"StringLike\":{\"s3:prefix\":[\"dawarich/*\"]}}}]}"
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

resource "aws_iam_policy" "stalwart_policy" {
  name   = "stalwart"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ReadWriteMail\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.mail.arn}\",\"${aws_s3_bucket.mail.arn}/*\"],\"Action\":[\"s3:*\"]},{\"Sid\":\"AmazonSesSendingAccess\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"ses:SendRawEmail\"]},{\"Sid\":\"Route53UpdateRecords\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.zone.arn}\"],\"Action\":[\"route53:ChangeResourceRecordSets\",\"route53:ListResourceRecordSets\"]},{\"Sid\":\"Route53GetChange\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:route53:::change/*\",\"Action\":[\"route53:GetChange\"]}]}"
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

resource "aws_iam_policy" "casa_policy" {
  name   = "casa"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ListRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.zone.arn}\"],\"Action\":[\"route53:ListResourceRecordSets\"]},{\"Sid\":\"WriteRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.zone.arn}\"],\"Action\":[\"route53:ChangeResourceRecordSets\"],\"Condition\":{\"StringEquals\":{\"route53:ChangeResourceRecordSetsNormalizedRecordNames\":\"casa.${aws_route53_zone.zone.name}\"}}}]}"
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
