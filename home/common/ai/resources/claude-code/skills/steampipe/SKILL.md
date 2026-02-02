---
name: steampipe
description: Query cloud infrastructure and APIs using SQL with Steampipe. Use when querying AWS, GCP, Azure, or other cloud resources via SQL; checking compliance and security posture; finding misconfigurations or untagged resources; analyzing IAM policies, S3 buckets, EC2 instances, or any cloud resources; or when user mentions steampipe, cloud queries, or infrastructure analysis.
---

# Steampipe

Query cloud infrastructure and APIs using SQL. Steampipe exposes cloud resources as database tables, enabling powerful queries without ETL.

## Quick Reference

```bash
# Query cloud (uses --workspace for Turbot Pipes)
steampipe query --workspace <workspace> "SELECT * FROM aws_s3_bucket"

# Interactive shell
steampipe query --workspace <workspace>

# Output formats: table (default), json, csv, line
steampipe query --workspace <workspace> --output json "SELECT ..."

# Plugin management (local only)
steampipe plugin install aws
steampipe plugin list
steampipe plugin update --all
```

## Cloud vs Local

**Cloud (Turbot Pipes)** - Use `--workspace <workspace-name>`:
```bash
steampipe query --workspace iniciador "SELECT * FROM aws_account"
```

**Local** - Omit `--workspace` or use `--workspace-database local`:
```bash
steampipe query "SELECT * FROM aws_account"
```

## Meta-Commands (Interactive Shell)

| Command | Purpose |
|---------|---------|
| `.tables` | List all available tables |
| `.inspect <table>` | Show table columns and types |
| `.connections` | List configured connections |
| `.output <format>` | Set output format |
| `.timing on` | Show query execution time |
| `.exit` / `.quit` | Exit shell |

## Common Query Patterns

### AWS Examples

```sql
-- List all S3 buckets with versioning status
SELECT name, region, versioning_enabled
FROM aws_s3_bucket;

-- Find public S3 buckets
SELECT name, region
FROM aws_s3_bucket
WHERE bucket_policy_is_public;

-- IAM users without MFA
SELECT name, create_date, mfa_enabled
FROM aws_iam_user
WHERE NOT mfa_enabled;

-- EC2 instances by type
SELECT instance_type, COUNT(*) as count
FROM aws_ec2_instance
GROUP BY instance_type
ORDER BY count DESC;

-- Security groups with open SSH
SELECT group_name, vpc_id, ip_permission
FROM aws_vpc_security_group_rule
WHERE type = 'ingress'
  AND ip_protocol = 'tcp'
  AND from_port <= 22 AND to_port >= 22
  AND cidr_ip = '0.0.0.0/0';

-- Untagged resources
SELECT arn, region
FROM aws_ec2_instance
WHERE tags IS NULL OR tags = '{}';
```

### GCP Examples

```sql
-- List all GCS buckets
SELECT name, location, storage_class
FROM gcp_storage_bucket;

-- Compute instances
SELECT name, machine_type, status
FROM gcp_compute_instance;
```

### Cross-Table Joins

```sql
-- EC2 instances with their security groups
SELECT
  i.instance_id,
  i.instance_type,
  sg.group_name
FROM aws_ec2_instance i
JOIN aws_vpc_security_group sg
  ON sg.group_id = ANY(i.security_groups);

-- IAM users with their attached policies
SELECT
  u.name as user_name,
  p.policy_name
FROM aws_iam_user u
JOIN aws_iam_user_policy p
  ON u.name = p.user_name;
```

## Table Discovery

Find tables for a specific service:
```bash
steampipe query --workspace <ws> ".tables aws_s3%"
steampipe query --workspace <ws> ".tables aws_iam%"
steampipe query --workspace <ws> ".tables gcp_%"
```

Inspect table schema:
```bash
steampipe query --workspace <ws> ".inspect aws_s3_bucket"
```

## Plugin Tables Reference

**AWS** (579+ tables): `aws_s3_bucket`, `aws_ec2_instance`, `aws_iam_user`, `aws_iam_role`, `aws_iam_policy`, `aws_vpc`, `aws_vpc_security_group`, `aws_lambda_function`, `aws_rds_db_instance`, `aws_cloudwatch_log_group`

**GCP** (200+ tables): `gcp_compute_instance`, `gcp_storage_bucket`, `gcp_iam_policy`, `gcp_bigquery_dataset`, `gcp_cloudfunctions_function`

**Azure** (300+ tables): `azure_compute_virtual_machine`, `azure_storage_account`, `azure_ad_user`

See https://hub.steampipe.io/ for complete plugin and table documentation.

## MUST DO

- Always use `--workspace <name>` for cloud queries
- Use `.inspect <table>` to discover column names before writing complex queries
- Quote string values in WHERE clauses
- Use `--output json` when results need programmatic processing

## MUST NOT

- Run queries without specifying workspace when targeting cloud
- Assume column names - always verify with `.inspect`
- Use `SELECT *` on large tables without LIMIT in production
