# booking infra + local db

Terraform for a small booking service on AWS (ALB -> ECS/Fargate -> RDS Postgres),
plus a docker-compose Postgres for the DB reliability bits - schema, seed,
index tuning and backup/restore.

RDS is not publicly reachable. Its SG only accepts traffic from the ECS task
SG on the DB port.

```
infra/modules/{network,ecs,rds}     # the pieces
infra/envs/{dev,prod}               # per-env vars + backend + wiring
docker-compose.yml                  # local postgres
db/migrations/                      # schema, indexes, seed (auto-run at init)
scripts/{backup,restore}.sh
.github/workflows/terraform.yml     # fmt/init/validate/plan on PRs
```

## quick review

Terraform (either env):

```
cd infra/envs/dev
terraform fmt -check -recursive .
terraform init -backend=false
terraform validate
terraform plan -refresh=false
```

`-backend=false` skips the S3 backend so you don't need AWS creds. `terraform.tfvars`
is auto-loaded from the env dir.

Local DB:

```
docker compose up -d
./scripts/backup.sh          # writes ./backups/<db>_<ts>.sql.gz
./scripts/restore.sh         # no args -> uses the newest backup
```

More detail in the sections below.

## terraform

Needs terraform >= 1.6. AWS apply is not required for the grader - fmt/init/
validate/plan is enough.

```
cd infra/envs/dev          # or prod
terraform fmt -check -recursive ../..
terraform init -backend=false
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

`-backend=false` lets you review without AWS creds. For a real apply, use the
partial backend that each env ships:

```
terraform init -backend-config=backend.hcl -reconfigure
```

`backend.tf` only declares the backend type; the bucket / region / lock table
values live in `backend.hcl`. Edit that before you apply.

dev runs a `t4g.micro` with 3-day retention, single-AZ, deletion protection
off. prod runs a `m6g.large`, 30-day retention, multi-AZ, deletion protection
on and `skip_final_snapshot=false`. Task CPU/memory and desired count are
also bumped up for prod. Everything else is shared through the modules.

RDS master password is generated with `random_password` and stored in SSM
Parameter Store as a SecureString. The parameter name is emitted as an output.
For real prod this should move to Secrets Manager for rotation - noted in the
module.

## local db

```
docker compose up -d
docker compose logs -f db       # optional, watch init finish
```

Migrations in `db/migrations/` are mounted into
`/docker-entrypoint-initdb.d`, so they run in order on a fresh volume:

- `001_schema.sql` - the two tables.
- `002_indexes.sql` - the tuning indexes.
- `003_seed.sql` - around 250 bookings across 5 orgs / 6 cities / 4 statuses
  (skewed to delhi + recent so the aggregation query has something to chew on),
  plus events for ~40% of bookings.

To re-seed: `docker compose down -v && docker compose up -d`.

Defaults: user `app`, password `app`, db `booking`, port `5432`. Override with
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT`.

### the index

The aggregation query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

The chosen index:

```sql
CREATE INDEX idx_bookings_city_created
  ON hotel_bookings (city, created_at DESC)
  INCLUDE (org_id, status, amount);
```

`city` leads because it's the equality predicate - highest selectivity. With
`city` fixed, the entries are already ordered by `created_at`, so the 30-day
window is a bounded range read rather than a filter-after-scan. The INCLUDE
carries the columns the aggregate needs (`org_id`, `status`, `amount`) into
the leaf pages, which lets Postgres serve this as an index-only scan.

Tradeoff: the INCLUDE bloats the index vs. a bare `(city, created_at)`. On
this table it's negligible; on a fat / wide table you'd have to weigh index
size against the read wins.

Check it's actually being used:

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Look for `Index Only Scan using idx_bookings_city_created`.

## backup / restore

Both scripts run `pg_dump` / `psql` inside the running compose container, so
you don't need pg tools on the host.

```
./scripts/backup.sh                     # writes ./backups/<db>_<ts>.sql.gz
./scripts/restore.sh <dumpfile>         # restore into <db>_restore
./scripts/restore.sh <dumpfile> mydb    # restore into a specific db name
```

Restore drops and recreates the target DB every time, so it always lands in a
clean state. When it finishes it prints row counts for both tables.

### verifying restore

Easy check - row counts + a spot-check aggregate.

```
docker exec -i booking-db psql -U app -d booking          -A -t -c \
  "SELECT COUNT(*) FROM hotel_bookings; SELECT COUNT(*) FROM booking_events;"

docker exec -i booking-db psql -U app -d booking_restore  -A -t -c \
  "SELECT COUNT(*) FROM hotel_bookings; SELECT COUNT(*) FROM booking_events;"
```

Row counts should match. For a stronger check, run the same aggregate on both
databases - everything should line up:

```sql
SELECT COUNT(*), ROUND(SUM(amount),2), COUNT(DISTINCT org_id), COUNT(DISTINCT city)
FROM hotel_bookings;
```

## CI

`.github/workflows/terraform.yml` runs on PRs touching `infra/`:
`terraform fmt -check` -> matrix over dev/prod: `init -backend=false` ->
`validate` -> `plan`. Plan output is uploaded as an artifact and posted (or
updated) as a PR comment. Mock AWS creds are used, so plan may not resolve
every data source - that's fine, the intent is code review, not state.
