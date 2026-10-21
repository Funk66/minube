resource "aws_iam_policy" "iam_grafana-policy_A0E9455B" {
  name   = "grafana"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"AllowReadingMetricsFromCloudWatch\",\"Effect\":\"Allow\",\"Action\":[\"CloudWatch:DescribeAlarmsForMetric\",\"CloudWatch:DescribeAlarmHistory\",\"CloudWatch:DescribeAlarms\",\"CloudWatch:ListMetrics\",\"CloudWatch:GetMetricData\",\"CloudWatch:GetInsightRuleReport\"],\"Resource\":\"*\"},{\"Sid\":\"AllowReadingResourceMetricsFromPerformanceInsights\",\"Effect\":\"Allow\",\"Action\":\"pi:GetResourceMetrics\",\"Resource\":\"*\"},{\"Sid\":\"AllowReadingLogsFromCloudWatch\",\"Effect\":\"Allow\",\"Action\":[\"logs:DescribeLogGroups\",\"logs:GetLogGroupFields\",\"logs:StartQuery\",\"logs:StopQuery\",\"logs:GetQueryResults\",\"logs:GetLogEvents\"],\"Resource\":\"*\"},{\"Sid\":\"AllowReadingTagsInstancesRegionsFromEC2\",\"Effect\":\"Allow\",\"Action\":[\"ec2:DescribeTags\",\"ec2:DescribeInstances\",\"ec2:DescribeRegions\"],\"Resource\":\"*\"},{\"Sid\":\"AllowReadingResourcesForTags\",\"Effect\":\"Allow\",\"Action\":\"tag:GetResources\",\"Resource\":\"*\"},{\"Action\":[\"oam:ListSinks\",\"oam:ListAttachedLinks\"],\"Effect\":\"Allow\",\"Resource\":\"*\"}]}"
}

resource "aws_iam_user" "iam_grafana-user_9562E6EF" {
  name = "grafana"
}

resource "aws_iam_user_policy_attachment" "iam_grafana-user-attachment_F86353CE" {
  user       = aws_iam_user.iam_grafana-user_9562E6EF.name
  policy_arn = aws_iam_policy.iam_grafana-policy_A0E9455B.arn
}

resource "aws_iam_access_key" "iam_grafana-access-key_6F3C46DA" {
  user = aws_iam_user.iam_grafana-user_9562E6EF.name
}

resource "aws_iam_policy" "iam_office-policy_10853733" {
  name   = "office"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ListHostedZones\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"route53:ListHostedZones\"]},{\"Sid\":\"ChangeRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.dns_zone_2E2729FB.arn}\"],\"Action\":[\"route53:ListResourceRecordSets\",\"route53:ChangeResourceRecordSets\"]},{\"Sid\":\"GetChange\",\"Effect\":\"Allow\",\"Resource\":[\"arn:aws:route53:::change/*\"],\"Action\":[\"route53:GetChange\"]},{\"Sid\":\"AccessS3\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-docs_08FE3C73.arn}\"],\"Action\":[\"s3:*\"]},{\"Sid\":\"ListAssets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-photos_3472E0E4.arn}\",\"${aws_s3_bucket.buckets_minube-docs_08FE3C73.arn}\"],\"Action\":[\"s3:ListBucket\"]},{\"Sid\":\"ReadWriteAssetBackups\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-photos_3472E0E4.arn}/*\",\"${aws_s3_bucket.buckets_minube-docs_08FE3C73.arn}/*\"],\"Action\":[\"s3:DeleteObject\",\"s3:GetObject\",\"s3:GetObjectTagging\",\"s3:PutObject\",\"s3:PutObjectTagging\",\"s3:AbortMultipartUpload\"]},{\"Sid\":\"BackupDawarich\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-backups_0F1ACE02.arn}/dawarich/*\"],\"Action\":[\"s3:PutObject\",\"s3:GetObject\",\"s3:GetObjectVersion\"]},{\"Sid\":\"ListBackupsDawarich\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-backups_0F1ACE02.arn}\"],\"Action\":[\"s3:ListBucket\",\"s3:ListBucketVersions\"],\"Condition\":{\"StringLike\":{\"s3:prefix\":[\"dawarich/*\"]}}}]}"
}

resource "aws_iam_user" "iam_office-user_950D4586" {
  name = "office"
}

resource "aws_iam_user_policy_attachment" "iam_office-user-attachment_4480995A" {
  user       = aws_iam_user.iam_office-user_950D4586.name
  policy_arn = aws_iam_policy.iam_office-policy_10853733.arn
}

resource "aws_iam_access_key" "iam_office-access-key_F94A3599" {
  user = aws_iam_user.iam_office-user_950D4586.name
}

resource "aws_iam_policy" "iam_stalwart-policy_57E1BEF8" {
  name   = "stalwart"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ReadWriteMail\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_s3_bucket.buckets_minube-mail_2017F00D.arn}\",\"${aws_s3_bucket.buckets_minube-mail_2017F00D.arn}/*\"],\"Action\":[\"s3:*\"]},{\"Sid\":\"AmazonSesSendingAccess\",\"Effect\":\"Allow\",\"Resource\":[\"*\"],\"Action\":[\"ses:SendRawEmail\"]},{\"Sid\":\"Route53UpdateRecords\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.dns_zone_2E2729FB.arn}\"],\"Action\":[\"route53:ChangeResourceRecordSets\",\"route53:ListResourceRecordSets\"]},{\"Sid\":\"Route53GetChange\",\"Effect\":\"Allow\",\"Resource\":\"arn:aws:route53:::change/*\",\"Action\":[\"route53:GetChange\"]}]}"
}

resource "aws_iam_user" "iam_stalwart-user_3DE0D054" {
  name = "stalwart"
}

resource "aws_iam_user_policy_attachment" "iam_stalwart-user-attachment_621C0EDF" {
  user       = aws_iam_user.iam_stalwart-user_3DE0D054.name
  policy_arn = aws_iam_policy.iam_stalwart-policy_57E1BEF8.arn
}

resource "aws_iam_access_key" "iam_stalwart-access-key_A3106A35" {
  user = aws_iam_user.iam_stalwart-user_3DE0D054.name
}

resource "aws_iam_policy" "iam_casa-policy_9B2491A9" {
  name   = "casa"
  policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"ListRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.dns_zone_2E2729FB.arn}\"],\"Action\":[\"route53:ListResourceRecordSets\"]},{\"Sid\":\"WriteRecordSets\",\"Effect\":\"Allow\",\"Resource\":[\"${aws_route53_zone.dns_zone_2E2729FB.arn}\"],\"Action\":[\"route53:ChangeResourceRecordSets\"],\"Condition\":{\"StringEquals\":{\"route53:ChangeResourceRecordSetsNormalizedRecordNames\":\"casa.${aws_route53_zone.dns_zone_2E2729FB.name}\"}}}]}"
}

resource "aws_iam_user" "iam_casa-user_C5DCB003" {
  name = "casa"
}

resource "aws_iam_user_policy_attachment" "iam_casa-user-attachment_EF85C26C" {
  user       = aws_iam_user.iam_casa-user_C5DCB003.name
  policy_arn = aws_iam_policy.iam_casa-policy_9B2491A9.arn
}

resource "aws_iam_access_key" "iam_casa-access-key_38EAC682" {
  user = aws_iam_user.iam_casa-user_C5DCB003.name
}
