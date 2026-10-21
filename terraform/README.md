# minube infrastructure (Terraform)

Hand-written Terraform for the minube server, mail, DNS, and storage.
Replaced the CDK for Terraform project in 2026-10; see `../MIGRATION-PLAN.md`
for the cutover history.

## Files

| File             | What it defines                                          |
| ---------------- | -------------------------------------------------------- |
| `versions.tf`    | Pinned AWS provider, HCP Terraform workspace             |
| `providers.tf`   | `eu-central-1` default, `us-east-1` alias (KMS)         |
| `dns.tf`         | Route 53 zone, records, DNSSEC                           |
| `s3.tf`          | Buckets (mail logs, storage)                             |
| `iam.tf`         | Users, roles, policies (grafana, office, stalwart, casa) |
| `vpc.tf`         | VPC, subnets, IGW, routes, EIP                           |
| `ec2.tf`         | Instance, SSH key, volume                                |
| `ses.tf`         | SES config, verified domains, KMS key (us-east-1)       |

`assets/userdata.sh` and `assets/key.pub` (repo root) are embedded via
`file()` — keep them in place.

## Day-2 usage

```sh
cd terraform
export TF_TOKEN_app_terraform_io=...   # or set in shell rc
terraform init      # once; talks to HCP workspace minube/minube
terraform plan
terraform apply
```

State and locking live in HCP Terraform (remote backend); there is no local
state file. All `plan`/`apply` must run from this directory — the old
`cdktf.out/` directory is gone and would not match the state.

## Naming

Resource names are the friendly short names (e.g. `aws_instance.instance`,
`aws_route53_zone.zone`). The rename from the original CDKTF ids happened in
one cutover apply on 2026-10-21 with zero churn (`moved` blocks); if you ever
rename a resource, re-add a `moved` block first so the state follows without
destroy/create.
