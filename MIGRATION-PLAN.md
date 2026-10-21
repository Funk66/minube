# Migration plan: CDK for Terraform → hand-written HCL

Goal: replace the TypeScript/CDKTF code (`main.ts`, `constructs/*.ts`, `cdktf.json`,
TS tooling) with a tidy, hand-maintained Terraform HCL directory, while keeping:

1. **Zero infrastructure churn** — `terraform plan` must show *no changes* at every
   cutover gate. No destroys, no replaces, no in-place updates.
2. **An intuitive structure** — one `.tf` file per concern, mirroring the constructs
   (`vpc.tf`, `s3.tf`, `ec2.ts→ec2.tf`, …) with friendly resource names.
3. **Trivial rollback** — every stage is one commit; nothing is ever in a state where
   config and state disagree.

---

## 1. Baseline (recon results, verified 2026-10-21)

- **Backend**: HCP Terraform, org `minube`, workspace `minube`, named via a `cloud`
  block. The workspace has **no VCS repo** and **auto-apply off** — code is uploaded
  from the local CLI on every run. So a "cutover" is simply: run
  `terraform plan/apply` from the new `terraform/` directory.
- **Inventory**: **78 resources + 3 data sources** (81 addresses) in the live state,
  all with CDKTF-generated names like `dns_zone_2E2729FB` (construct path + hex hash).
  Full list in §4.
- **Baseline gate PASSED**: `cdktf synth` (→ `cdktf.out/stacks/minube/cdk.tf.json`) +
  `terraform init && terraform plan` against the cloud state → **"No changes. Your
  infrastructure matches the configuration."**
- **Provider**: `aws 6.25.0` (pinned exactly by the synth), two provider blocks
  (default `eu-central-1`, alias `us-east-1` for the DNSSEC KMS key/alias).

### ⚠️ `cdktf synth --hcl` is NOT a trustworthy source

The cdktf 0.21 HCL emitter **corrupts the output**: it mangles every string that
contains spaces or `${…}` (e.g. `"{" Version ":" 2012 - 10 - 17 "`,
`chmod + x / etc /` inside the user-data heredoc) and `terraform validate` on the
result fails. It is only useful for *reading values* (which are correct); the
**authoritative sources are the TypeScript source (intent) and `cdk.tf.json`
(exact deployed values, verified by the plan)**. We hand-write the HCL and use the
plan as the oracle.

---

## 2. The core risk and the fix: state continuity

Terraform tracks resources by **address** (`resource_type.name`), not by
infrastructure identity. Renaming `aws_route53_zone.dns_zone_2E2729FB` to
`aws_route53_zone.zone` in the config — without anything else — makes Terraform see
"a zone that no longer exists (destroy!) + a new zone to create (collision:
guirao.net already exists!)". Multiply by 81 → the "hundreds of simultaneous
changes" disaster.

**Fix: `moved` blocks** (Terraform ≥ 1.5). One per address, in a dedicated
`terraform/moved.tf`:

```hcl
moved {
  from = aws_route53_zone.dns_zone_2E2729FB
  to   = aws_route53_zone.zone
}
```

A `moved` block never creates/destroys anything: it tells Terraform the state entry
at `from` *is* the config entry at `to`. Consequences:

- **plan** with new names + moved blocks → "No changes" (the move is resolved
  before diffing; plan output may *mention* the moves, that is informational).
- **apply** rewrites only the state addresses — zero infrastructure API calls that
  change anything. If the run is interrupted, a re-run simply finishes the renames;
  it cannot damage infrastructure.
- The moved blocks are safe to keep forever, but we delete them after the first
  clean apply (§5, stage 3) so the code stays honest.

Because of this, the whole migration is: *reorganize config → rename addresses with
moved → one no-op apply that rewrites state addresses → clean up*. There is no
intermediate stage where the config and state disagree in any risky way.

---

## 3. Target layout

New `terraform/` directory at the repo root, mirroring the constructs. Everything
else in the repo (`assets/`, `office/`, `scripts/`) is untouched.

```
terraform/
├── versions.tf    # terraform {} : required_providers (aws = 6.25.0, pinned) + cloud {}
├── providers.tf   # provider "aws" (eu-central-1) + alias "us-east-1"
├── dns.tf         # hosted zone, CAA/TXT/CNAME records, DNSSEC (KMS key+alias, KSK, zone DNSSEC)
├── s3.tf          # 7 buckets, each with versioning + lifecycle configuration
├── iam.tf         # grafana / office / stalwart / casa: policy, user, attachment, access key
├── vpc.tf         # vpc, igw, route table, 2 routes, subnet, association, S3 endpoint
├── ec2.tf         # instance, role, policy, profile, key pair, SG, EIP, data volume, records
├── ses.tf         # identity, mail-from, DKIM + 6 Route 53 records
└── moved.tf       # 81 moved blocks (stage 2; deleted in stage 3)
```

### Naming rules

- Drop the construct-path prefix and the `_<8-hex>` hash; keep the construct-internal
  id; kebab-case → snake_case. (`allowSepCharsInLogicalIds` was enabled, so the old
  names contain `-`; HCL accepts both, but we standardize on `_`.)
- Values that were inlined from files become `file()` references:
  - `user_data  = file("${path.root}/../assets/userdata.sh")`
  - `public_key = file("${path.root}/../assets/key.pub")`

  `file()` is evaluated locally at plan time, so CLI-initiated TF Cloud runs work
  exactly like the old `readFileSync()`-based setup (the file content is embedded in
  the uploaded plan). No files move, so `scripts/pack.py` and `office/` keep working.
- **The user_data heredoc must not be used** (see pitfalls §6): `assets/userdata.sh`
  contains a nested `cat <<EOF` heredoc, which would prematurely terminate a Terraform
  `<<EOF` heredoc and silently truncate the value → `user_data` is ForceNew on
  `aws_instance` → that would **replace the server**. `file()` sidesteps the issue
  entirely, and the plan gate catches any byte difference.
- Keep `provider = aws.us-east-1` on the KMS key + alias (DNSSEC KMS must live in
  us-east-1; the Route53 zone itself stays on the default eu-central-1 provider).

### Full address map (81 entries)

`moved.tf` is exactly this table, with one `moved` block per row.

**dns.tf** (10)
| current (state) | new |
|---|---|
| `aws_route53_zone.dns_zone_2E2729FB` | `zone` |
| `aws_route53_record.dns_caa-record_487843A3` | `caa_record` |
| `data.aws_caller_identity.dns_current_750979D0` | `current` |
| `data.aws_iam_policy_document.dns_dnssec-policy_FD420429` | `dnssec_policy` |
| `aws_kms_key.dns_kms-key_3A639EF6` | `kms_key` |
| `aws_kms_alias.dns_kms-key-alias_C6B16ECE` | `kms_key_alias` |
| `aws_route53_key_signing_key.dns_key-signing-key_71FE8640` | `key_signing_key` |
| `aws_route53_hosted_zone_dnssec.dns_dnssec_B5444A19` | `dnssec` |
| `aws_route53_record.dns_funk66-cname_1E1DFA2C` | `funk66_cname` |
| `aws_route53_record.dns_google-record_BC4BA9C2` | `google_record` |

**s3.tf** (21)
| current | new |
|---|---|
| `aws_s3_bucket.buckets_minube-backups_0F1ACE02` | `backups` |
| `aws_s3_bucket_versioning.buckets_backups-versioning_50248965` | `backups_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_backups-lifecycle_FA66DD08` | `backups_lifecycle` |
| `aws_s3_bucket.buckets_minube-fs_5D278F8B` | `fs` |
| `aws_s3_bucket_versioning.buckets_fs-versioning_069DB685` | `fs_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_fs-lifecycle_20D547F5` | `fs_lifecycle` |
| `aws_s3_bucket.buckets_minube-files_0207517F` | `files` |
| `aws_s3_bucket_versioning.buckets_files-versioning_DC55B346` | `files_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_files-lifecycle_7E91F0D4` | `files_lifecycle` |
| `aws_s3_bucket.buckets_minube-storage_A1ADE638` | `storage` |
| `aws_s3_bucket_versioning.buckets_storage-versioning_FA7AAE6C` | `storage_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_storage-lifecycle_12A6B5B2` | `storage_lifecycle` |
| `aws_s3_bucket.buckets_minube-photos_3472E0E4` | `photos` |
| `aws_s3_bucket_versioning.buckets_photos-versioning_42CA05AD` | `photos_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_photos-lifecycle_D1433BBC` | `photos_lifecycle` |
| `aws_s3_bucket.buckets_minube-mail_2017F00D` | `mail` |
| `aws_s3_bucket_versioning.buckets_mail-versioning_FB59FB1A` | `mail_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_mail-lifecycle_EC4CE7EE` | `mail_lifecycle` |
| `aws_s3_bucket.buckets_minube-docs_08FE3C73` | `docs` |
| `aws_s3_bucket_versioning.buckets_docs-versioning_4EC986D3` | `docs_versioning` |
| `aws_s3_bucket_lifecycle_configuration.buckets_docs-lifecycle_BCB6FB67` | `docs_lifecycle` |

**iam.tf** (16)
| current | new |
|---|---|
| `aws_iam_policy.iam_grafana-policy_A0E9455B` | `grafana_policy` |
| `aws_iam_user.iam_grafana-user_9562E6EF` | `grafana` |
| `aws_iam_user_policy_attachment.iam_grafana-user-attachment_F86353CE` | `grafana_attachment` |
| `aws_iam_access_key.iam_grafana-access-key_6F3C46DA` | `grafana_key` |
| `aws_iam_policy.iam_office-policy_10853733` | `office_policy` |
| `aws_iam_user.iam_office-user_950D4586` | `office` |
| `aws_iam_user_policy_attachment.iam_office-user-attachment_4480995A` | `office_attachment` |
| `aws_iam_access_key.iam_office-access-key_F94A3599` | `office_key` |
| `aws_iam_policy.iam_stalwart-policy_57E1BEF8` | `stalwart_policy` |
| `aws_iam_user.iam_stalwart-user_3DE0D054` | `stalwart` |
| `aws_iam_user_policy_attachment.iam_stalwart-user-attachment_621C0EDF` | `stalwart_attachment` |
| `aws_iam_access_key.iam_stalwart-access-key_A3106A35` | `stalwart_key` |
| `aws_iam_policy.iam_casa-policy_9B2491A9` | `casa_policy` |
| `aws_iam_user.iam_casa-user_C5DCB003` | `casa` |
| `aws_iam_user_policy_attachment.iam_casa-user-attachment_EF85C26C` | `casa_attachment` |
| `aws_iam_access_key.iam_casa-access-key_38EAC682` | `casa_key` |

**vpc.tf** (8)
| current | new |
|---|---|
| `aws_vpc.vpc_6776A399` | `vpc` |
| `aws_internet_gateway.vpc_igw_E5E304CC` | `igw` |
| `aws_route_table.vpc_routeTable_FC8D1E91` | `route_table` |
| `aws_route.vpc_route4_93D95A3C` | `route_ipv4` |
| `aws_route.vpc_route6_BC6C2BF8` | `route_ipv6` |
| `aws_subnet.vpc_subnet_376FC355` | `subnet` |
| `aws_route_table_association.vpc_routeTableAssociation_B59F732F` | `route_table_association` |
| `aws_vpc_endpoint.vpc_s3Endpoint_8F340651` | `s3_endpoint` |

**ec2.tf** (17, incl. 1 data source)
| current | new |
|---|---|
| `data.aws_ami.minube_ubuntu_DBD887C0` | `ubuntu` |
| `aws_iam_policy.minube_ec2-policy_1589FCF6` | `ec2_policy` |
| `aws_iam_role.minube_ec2-role_7EBD8617` | `ec2_role` |
| `aws_iam_policy_attachment.minube_ec2-role-attachment_79AAE2A7` | `ec2_role_attachment` |
| `aws_iam_instance_profile.minube_profile_DA0BE098` | `instance_profile` |
| `aws_security_group.minube_sg_FD4FC769` | `security_group` |
| `aws_key_pair.minube_key_C5C91068` | `ssh_key` |
| `aws_instance.minube_instance_DC8B55B2` | `instance` |
| `aws_eip.minube_eip_ABBEFAB8` | `eip` |
| `aws_ebs_volume.minube_volume_7905D60F` | `data_volume` |
| `aws_volume_attachment.minube_attachment_5CBBB29D` | `data_attachment` |
| `aws_route53_record.minube_main-a-record_C6633991` | `main_a` |
| `aws_route53_record.minube_main-aaaa-record_6A1C442D` | `main_aaaa` |
| `aws_route53_record.minube_minube-a-record_BF1F97B8` | `minube_a` |
| `aws_route53_record.minube_minube-aaaa-record_DD7D00D9` | `minube_aaaa` |
| `aws_route53_record.minube_mail-a-record_3EE44DA1` | `mail_a` |
| `aws_route53_record.minube_mail-aaaa-record_D2746EED` | `mail_aaaa` |

**ses.tf** (9)
| current | new |
|---|---|
| `aws_ses_domain_identity.ses_domain-identity_2AC0305F` | `domain_identity` |
| `aws_ses_domain_mail_from.ses_domain-mail-from_F87769A2` | `domain_mail_from` |
| `aws_ses_domain_dkim.ses_domain-dkim_A38858C1` | `domain_dkim` |
| `aws_route53_record.ses_verification-record_8F3F9C54` | `verification_record` |
| `aws_route53_record.ses_mail-from-mx_8F614BAA` | `mail_from_mx` |
| `aws_route53_record.ses_mail-from-txt_04902770` | `mail_from_txt` |
| `aws_route53_record.ses_dkim-record-0_DDADBEBD` | `dkim_0` |
| `aws_route53_record.ses_dkim-record-1_9FC8CF42` | `dkim_1` |
| `aws_route53_record.ses_dkim-record-2_5CCE1C1C` | `dkim_2` |

**versions.tf / providers.tf** — no renames (the `terraform` block and provider
blocks have no state addresses):

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"   # exact pin — a newer provider can change plan behavior
    }
  }
  cloud {
    hostname     = "app.terraform.io"
    organization = "minube"
    workspaces {
      name = "minube"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}
```

Not migrated: `constructs/acm.ts` (the `ACM` construct is never instantiated — no
state, excluded). The `storage` bucket is kept exactly as-is (it has no consumers in
code but exists in state; deleting it would be a real infrastructure change and is a
separate decision, not part of this migration).

---

## 4. Staged execution

Work on a dedicated branch (`hcl-migration`). **One commit per stage.** Every stage
ends with the gates in §5; a failed gate means fix-and-retry or drop the commit —
nothing is ever left half-applied.

### Stage 0 — Baseline freeze (✅ done)

- `cdktf synth` → `cdktf.out/stacks/minube/cdk.tf.json`; keep a copy as the value
  reference (it is gitignored; re-generable from the TS source).
- `terraform plan` in `cdktf.out/stacks/minube` → **"No changes"** ✅
- Resource/address inventory captured (§3 tables).

*Rollback: n/a — read-only.*

### Stage 1 — `terraform/` with **identical** addresses

Write the eight `.tf` files exactly as §3, **but keep the old hashed names**
(`dns_zone_2E2729FB`, …). Values are taken verbatim from the TS source /
`cdk.tf.json`, tidied into idiomatic HCL:

- IAM policies and the assume-role policy: **keep the exact JSON strings** (compact,
  single line, interpolations in place). Do *not* pretty-print and do *not*
  `jsonencode()` yet — these are string attributes compared byte-for-byte;
  `jsonencode()` sorts keys and would cause a one-time in-place policy update.
  (Cosmetic policy rewrites belong to stage 5, where a diff is *expected and
  announced*.)
- Security group: drop the synth's `= null` padding; write clean `ingress`/`egress`
  blocks with only the real attributes (omitting an attribute ≡ `null`).
- AAAA records: `records = aws_instance.minube_instance_DC8B55B2.ipv6_addresses`
  (direct list reference; the JSON synth's bare-string interpolation is a
  JSON-config-only quirk — same value, valid HCL).
- `user_data`/`public_key` via `file()` (§3).
- KMS key/alias keep `provider = aws.us-east-1`.

**Gates**: `fmt -check -diff` → clean · `validate` → ok · `plan` → **"No changes"**
(proves the file split + tidying preserved every value exactly; also re-proves the
cloud wiring). *Commit.*

*Rollback: `git revert` — zero state interaction (plan was no-op; the old cdktf path
is untouched, so the workspace keeps working off `cdktf.out`).*

### Stage 2 — Rename everything + `moved.tf` (the cutover)

In `terraform/` only: apply the §3 name map and add `moved.tf` with all 81 blocks.

**Gates (before apply)**: `fmt -check` · `validate` · `plan` → **"No changes"**
(moves are resolved in memory; if plan listed the moves, that's informational —
the assertion is that it reports zero changes to infrastructure). *Commit.*

**Cutover apply** (the only non-read-only step of the whole migration — needs an
explicit GO from the owner, e.g. outside mail-send peak hours):

    cd terraform && terraform apply   # answers "yes" once, prompt-free: -auto-approve

What happens: Terraform refreshes, applies the moves, and **rewrites the 81 state
addresses**. No resource is created, updated, or destroyed; nothing visible happens
in AWS/Route53/S3. Expected output: `Apply complete! Resources: 0 added, 0 changed,
0 destroyed.`

**Post-apply gates**: `terraform plan` again → "No changes"; sanity checks from a
shell: `dig guirao.net A/AAAA`, `dig minube.guirao.net`, mail flow / a test email,
S3 bucket listing. Also confirm in the TF Cloud UI that the resource names are now
the friendly ones.

*Rollback (if anything looks wrong after the apply):*
1. Nothing in AWS changed — the only mutation was state addressing, so "undoing"
   means restoring old addresses: one-off config = the stage-1 code (old names) with
   the moved blocks **reversed** (`from = …new`, `to = …old`), one `terraform apply`
   (again 0 added/changed/destroyed), then the old cdktf flow works as before.
   Keep such a reverse-`moved` snippet in the branch for this purpose; delete it once
   we're confident.
2. An interrupted apply needs no undo — re-run `terraform apply`; moves are
   idempotent and cannot create/destroy.

### Stage 3 — Delete `moved.tf`

Addresses in state now equal the config, so the moved blocks are historical noise.
Remove the file. **Gates**: `validate` · `plan` → "No changes" · *commit.*

*Rollback: revert (moving the file back) — no state impact.*

### Stage 4 — Remove the CDKTF scaffolding

Delete: `main.ts`, `constructs/`, `cdktf.json`, `package.json`,
`package-lock.json`, `tsconfig.json`, `jest.config.js`, `setup.js`, `.eslintrc.js`,
`.npmrc`, `.npmignore`, `node_modules/`, the `cdktf out` remnants
(`cdktf.out/` is gitignored; just delete the dir).
Update: `.gitignore` (drop TS/cdktf entries: `*.d.ts`, `*.js`, `./bin`, `.gen`,
`node_modules`, `cdktf.out`, `cdktf.log`, `tsconfig.tsbuildinfo`, `!jest.config.js`,
`!setup.js`; keep the rest, add `!`/`*.tf` nothing needed), `.github/dependabot.yaml`
(delete — no more npm), `.devcontainer/devcontainer.json` (drop the node tooling
assumptions; keep the `terraform` + `aws-cli` features and `TF_TOKEN` env).
Update `MIGRATION-PLAN.md` status or convert it into a short `terraform/README.md`
documenting the layout + the `cdktf synth` history.

**Gates**: `terraform validate` · `plan` → "No changes" · `git grep cdktf` → only
the plan/README mention it · *commit.*

*Rollback: revert the commit — the TS files come back and `yarn synth` works again.
State is at the new addresses, but the cdktf flow is only needed as a fallback for
**new** config work, which now happens in HCL; for a true rollback of the rename
use the stage-2 reverse-moved procedure.*

### Stage 5 (optional polish, explicit-diff steps — do AFTER the cutover settles)

Each of these is a *deliberate, reviewable* one-time in-place update, so they are
separate commits announced in the PR description, never mixed into stages 1–4:

- Rewrite the six IAM policy strings as `jsonencode({...})` (sorted, readable) →
  plan shows 5–6 IAM policies "updated in-place" (semantically identical; IAM
  applies in seconds).
- Same for the EC2 assume-role policy.
- Widen `version = "6.25.0"` to `~> 6.25` (optional; re-plan to confirm no drift
  with the newer minor releases before adopting).
- Remove the now-redundant `office/`… nothing here; `office/` stays as-is.

---

## 5. Verification commands (run from `terraform/` unless noted)

```bash
cd terraform
terraform init -input=false        # pulls aws 6.25.0, attaches to cloud workspace
terraform fmt -check -recursive    # expect: no output, exit 0
terraform validate                 # expect: "Success! The configuration is valid."
terraform plan -input=false        # expect: "No changes. Your infrastructure matches the configuration."
```

After the cutover apply:

```bash
terraform plan -input=false        # still "No changes"
dig guirao.net A; dig guirao.net AAAA; dig mail.guirao.net A
curl -sI https://minube.guirao.net   # service reachable via the (unchanged) EIP
```

A **plan showing any diff is a failed gate** — investigate (usual suspects: a
value that drifted from `cdk.tf.json` during tidying, a heredoc/`file()` byte
difference in `user_data`, a missing `provider =` line, a provider version change).

---

## 6. Pitfalls discovered (why the plan is shaped this way)

1. **`cdktf synth --hcl` output is broken** (corrupted strings, unparseable) — use
   `cdk.tf.json` + the TS source as truth; hand-write the HCL (§1).
2. **`user_data` is ForceNew** and the script contains a nested `cat <<EOF` heredoc —
   use `file()`, never a Terraform heredoc, for it.
3. **Policy strings compare byte-for-byte** — keep the exact `JSON.stringify` output
   during the cutover; pretty-rewrites only in stage 5.
4. **Provider pin matters** — keep `6.25.0` exact until after the cutover.
5. **JSON vs HCL interpolation semantics** — in `.tf.json` a lone `"${list}"` string
   passes through as the list (documented JSON-config behavior); in HCL write the
   direct reference instead.
6. **KMS pair uses the `us-east-1` alias** — never "simplify" away the alias.
7. **`aws_route53_*` (v3-era resources) are still in use** for zone/records/KSK/
   DNSSEC — keep the same resource types; do not "modernize" to `aws_route53`
   v4-era types in this migration (different types = destroy/create).
8. **TF Cloud workspace is code-uploaded, no VCS** — after stage 4, remember every
   future `terraform plan/apply` must be run from `terraform/`, not
   `cdktf.out/stacks/minube`. (Optionally later: point the workspace at a VCS repo /
   this path, or keep the upload flow.)
9. **IAM access keys**: the four `aws_iam_access_key` resources are in state and must
   be carried over exactly — consumers (grafana/office/stalwart/casa) rely on them.
   A drop = broken credentials everywhere.

---

## 7. Definition of done

- [x] Stage 0: baseline plan = no changes (verified 2026-10-21)
- [ ] Stage 1: `terraform/` with old names; fmt/validate/plan gates green; committed
- [ ] Stage 2: rename + moved.tf; plan gate green; **approved** cutover apply =
      `0 added, 0 changed, 0 destroyed`; post-apply sanity checks pass; committed
- [ ] Stage 3: `moved.tf` removed; plan green; committed
- [ ] Stage 4: cdktf scaffolding gone; plan green; committed; branch merged to master
- [ ] (optional) Stage 5 polish commits
- Result: `git ls-files` shows a small tidy `terraform/` tree; `terraform plan`
  prints "No changes"; the TF Cloud workspace runs on it; the server, mail, and
  DNS keep working throughout.
