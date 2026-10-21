# Maps the CDKTF-generated resource addresses (see MIGRATION-PLAN.md) to
# the new names so the Terraform state keeps track of the same resources.
# Delete this file once the rename has been applied.

moved {
  from = aws_route53_zone.dns_zone_2E2729FB
  to   = aws_route53_zone.zone
}

moved {
  from = aws_route53_record.dns_caa-record_487843A3
  to   = aws_route53_record.caa_record
}

moved {
  from = data.aws_caller_identity.dns_current_750979D0
  to   = data.aws_caller_identity.current
}

moved {
  from = data.aws_iam_policy_document.dns_dnssec-policy_FD420429
  to   = data.aws_iam_policy_document.dnssec_policy
}

moved {
  from = aws_kms_key.dns_kms-key_3A639EF6
  to   = aws_kms_key.kms_key
}

moved {
  from = aws_kms_alias.dns_kms-key-alias_C6B16ECE
  to   = aws_kms_alias.kms_key_alias
}

moved {
  from = aws_route53_key_signing_key.dns_key-signing-key_71FE8640
  to   = aws_route53_key_signing_key.key_signing_key
}

moved {
  from = aws_route53_hosted_zone_dnssec.dns_dnssec_B5444A19
  to   = aws_route53_hosted_zone_dnssec.dnssec
}

moved {
  from = aws_route53_record.dns_funk66-cname_1E1DFA2C
  to   = aws_route53_record.funk66_cname
}

moved {
  from = aws_route53_record.dns_google-record_BC4BA9C2
  to   = aws_route53_record.google_record
}

moved {
  from = aws_s3_bucket.buckets_minube-backups_0F1ACE02
  to   = aws_s3_bucket.backups
}

moved {
  from = aws_s3_bucket_versioning.buckets_backups-versioning_50248965
  to   = aws_s3_bucket_versioning.backups_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_backups-lifecycle_FA66DD08
  to   = aws_s3_bucket_lifecycle_configuration.backups_lifecycle
}

moved {
  from = aws_s3_bucket.buckets_minube-fs_5D278F8B
  to   = aws_s3_bucket.fs
}

moved {
  from = aws_s3_bucket_versioning.buckets_fs-versioning_069DB685
  to   = aws_s3_bucket_versioning.fs_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_fs-lifecycle_20D547F5
  to   = aws_s3_bucket_lifecycle_configuration.fs_lifecycle
}

moved {
  from = aws_s3_bucket.buckets_minube-files_0207517F
  to   = aws_s3_bucket.files
}

moved {
  from = aws_s3_bucket_versioning.buckets_files-versioning_DC55B346
  to   = aws_s3_bucket_versioning.files_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_files-lifecycle_7E91F0D4
  to   = aws_s3_bucket_lifecycle_configuration.files_lifecycle
}

moved {
  from = aws_s3_bucket.buckets_minube-storage_A1ADE638
  to   = aws_s3_bucket.storage
}

moved {
  from = aws_s3_bucket_versioning.buckets_storage-versioning_FA7AAE6C
  to   = aws_s3_bucket_versioning.storage_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_storage-lifecycle_12A6B5B2
  to   = aws_s3_bucket_lifecycle_configuration.storage_lifecycle
}

moved {
  from = aws_s3_bucket.buckets_minube-photos_3472E0E4
  to   = aws_s3_bucket.photos
}

moved {
  from = aws_s3_bucket_versioning.buckets_photos-versioning_42CA05AD
  to   = aws_s3_bucket_versioning.photos_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_photos-lifecycle_D1433BBC
  to   = aws_s3_bucket_lifecycle_configuration.photos_lifecycle
}

moved {
  from = aws_s3_bucket.buckets_minube-mail_2017F00D
  to   = aws_s3_bucket.mail
}

moved {
  from = aws_s3_bucket_versioning.buckets_mail-versioning_FB59FB1A
  to   = aws_s3_bucket_versioning.mail_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_mail-lifecycle_EC4CE7EE
  to   = aws_s3_bucket_lifecycle_configuration.mail_lifecycle
}

moved {
  from = aws_s3_bucket.buckets_minube-docs_08FE3C73
  to   = aws_s3_bucket.docs
}

moved {
  from = aws_s3_bucket_versioning.buckets_docs-versioning_4EC986D3
  to   = aws_s3_bucket_versioning.docs_versioning
}

moved {
  from = aws_s3_bucket_lifecycle_configuration.buckets_docs-lifecycle_BCB6FB67
  to   = aws_s3_bucket_lifecycle_configuration.docs_lifecycle
}

moved {
  from = aws_iam_policy.iam_grafana-policy_A0E9455B
  to   = aws_iam_policy.grafana_policy
}

moved {
  from = aws_iam_user.iam_grafana-user_9562E6EF
  to   = aws_iam_user.grafana
}

moved {
  from = aws_iam_user_policy_attachment.iam_grafana-user-attachment_F86353CE
  to   = aws_iam_user_policy_attachment.grafana_attachment
}

moved {
  from = aws_iam_access_key.iam_grafana-access-key_6F3C46DA
  to   = aws_iam_access_key.grafana_key
}

moved {
  from = aws_iam_policy.iam_office-policy_10853733
  to   = aws_iam_policy.office_policy
}

moved {
  from = aws_iam_user.iam_office-user_950D4586
  to   = aws_iam_user.office
}

moved {
  from = aws_iam_user_policy_attachment.iam_office-user-attachment_4480995A
  to   = aws_iam_user_policy_attachment.office_attachment
}

moved {
  from = aws_iam_access_key.iam_office-access-key_F94A3599
  to   = aws_iam_access_key.office_key
}

moved {
  from = aws_iam_policy.iam_stalwart-policy_57E1BEF8
  to   = aws_iam_policy.stalwart_policy
}

moved {
  from = aws_iam_user.iam_stalwart-user_3DE0D054
  to   = aws_iam_user.stalwart
}

moved {
  from = aws_iam_user_policy_attachment.iam_stalwart-user-attachment_621C0EDF
  to   = aws_iam_user_policy_attachment.stalwart_attachment
}

moved {
  from = aws_iam_access_key.iam_stalwart-access-key_A3106A35
  to   = aws_iam_access_key.stalwart_key
}

moved {
  from = aws_iam_policy.iam_casa-policy_9B2491A9
  to   = aws_iam_policy.casa_policy
}

moved {
  from = aws_iam_user.iam_casa-user_C5DCB003
  to   = aws_iam_user.casa
}

moved {
  from = aws_iam_user_policy_attachment.iam_casa-user-attachment_EF85C26C
  to   = aws_iam_user_policy_attachment.casa_attachment
}

moved {
  from = aws_iam_access_key.iam_casa-access-key_38EAC682
  to   = aws_iam_access_key.casa_key
}

moved {
  from = aws_vpc.vpc_6776A399
  to   = aws_vpc.vpc
}

moved {
  from = aws_internet_gateway.vpc_igw_E5E304CC
  to   = aws_internet_gateway.igw
}

moved {
  from = aws_route_table.vpc_routeTable_FC8D1E91
  to   = aws_route_table.route_table
}

moved {
  from = aws_route.vpc_route4_93D95A3C
  to   = aws_route.route_ipv4
}

moved {
  from = aws_route.vpc_route6_BC6C2BF8
  to   = aws_route.route_ipv6
}

moved {
  from = aws_subnet.vpc_subnet_376FC355
  to   = aws_subnet.subnet
}

moved {
  from = aws_route_table_association.vpc_routeTableAssociation_B59F732F
  to   = aws_route_table_association.route_table_association
}

moved {
  from = aws_vpc_endpoint.vpc_s3Endpoint_8F340651
  to   = aws_vpc_endpoint.s3_endpoint
}

moved {
  from = data.aws_ami.minube_ubuntu_DBD887C0
  to   = data.aws_ami.ubuntu
}

moved {
  from = aws_iam_policy.minube_ec2-policy_1589FCF6
  to   = aws_iam_policy.ec2_policy
}

moved {
  from = aws_iam_role.minube_ec2-role_7EBD8617
  to   = aws_iam_role.ec2_role
}

moved {
  from = aws_iam_policy_attachment.minube_ec2-role-attachment_79AAE2A7
  to   = aws_iam_policy_attachment.ec2_role_attachment
}

moved {
  from = aws_iam_instance_profile.minube_profile_DA0BE098
  to   = aws_iam_instance_profile.instance_profile
}

moved {
  from = aws_security_group.minube_sg_FD4FC769
  to   = aws_security_group.security_group
}

moved {
  from = aws_key_pair.minube_key_C5C91068
  to   = aws_key_pair.ssh_key
}

moved {
  from = aws_instance.minube_instance_DC8B55B2
  to   = aws_instance.instance
}

moved {
  from = aws_eip.minube_eip_ABBEFAB8
  to   = aws_eip.eip
}

moved {
  from = aws_ebs_volume.minube_volume_7905D60F
  to   = aws_ebs_volume.data_volume
}

moved {
  from = aws_volume_attachment.minube_attachment_5CBBB29D
  to   = aws_volume_attachment.data_attachment
}

moved {
  from = aws_route53_record.minube_main-a-record_C6633991
  to   = aws_route53_record.main_a
}

moved {
  from = aws_route53_record.minube_main-aaaa-record_6A1C442D
  to   = aws_route53_record.main_aaaa
}

moved {
  from = aws_route53_record.minube_minube-a-record_BF1F97B8
  to   = aws_route53_record.minube_a
}

moved {
  from = aws_route53_record.minube_minube-aaaa-record_DD7D00D9
  to   = aws_route53_record.minube_aaaa
}

moved {
  from = aws_route53_record.minube_mail-a-record_3EE44DA1
  to   = aws_route53_record.mail_a
}

moved {
  from = aws_route53_record.minube_mail-aaaa-record_D2746EED
  to   = aws_route53_record.mail_aaaa
}

moved {
  from = aws_ses_domain_identity.ses_domain-identity_2AC0305F
  to   = aws_ses_domain_identity.domain_identity
}

moved {
  from = aws_ses_domain_mail_from.ses_domain-mail-from_F87769A2
  to   = aws_ses_domain_mail_from.domain_mail_from
}

moved {
  from = aws_ses_domain_dkim.ses_domain-dkim_A38858C1
  to   = aws_ses_domain_dkim.domain_dkim
}

moved {
  from = aws_route53_record.ses_verification-record_8F3F9C54
  to   = aws_route53_record.verification_record
}

moved {
  from = aws_route53_record.ses_mail-from-mx_8F614BAA
  to   = aws_route53_record.mail_from_mx
}

moved {
  from = aws_route53_record.ses_mail-from-txt_04902770
  to   = aws_route53_record.mail_from_txt
}

moved {
  from = aws_route53_record.ses_dkim-record-0_DDADBEBD
  to   = aws_route53_record.dkim_0
}

moved {
  from = aws_route53_record.ses_dkim-record-1_9FC8CF42
  to   = aws_route53_record.dkim_1
}

moved {
  from = aws_route53_record.ses_dkim-record-2_5CCE1C1C
  to   = aws_route53_record.dkim_2
}
