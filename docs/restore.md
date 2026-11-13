# Restoring backups

Backups are written nightly into a PVC by the CronJobs in `manifests/backups/` and copied an hour
later to the `backups` bucket by `manifests/backups/offsite/`. Replace `<ns>` with your namespace.

| Service  | Dump job (UTC) | File                         | Bucket path         |
|----------|----------------|------------------------------|---------------------|
| postgres | 02:00          | `<db>-<timestamp>.dump`      | `backups/postgres/` |
| mysql    | 02:00          | `*.sql.gz`                   | `backups/mysql/`    |
| mongodb  | 02:30          | `mongodb-<timestamp>.archive.gz` | `backups/mongodb/` |

## 1. Get the file

From the PVC (newest first):

```bash
kubectl run restore-shell -n <ns> --rm -it --image=busybox \
  --overrides='{"spec":{"containers":[{"name":"c","image":"busybox","command":["sh"],"stdin":true,"tty":true,
  "volumeMounts":[{"name":"b","mountPath":"/backup"}]}],"volumes":[{"name":"b","persistentVolumeClaim":{"claimName":"postgres-backup"}}]}}' \
  -- ls -lt /backup
```

Or from the bucket, on your machine, with the MinIO client (`mc alias set offsite <url> <key> <secret>`):

```bash
mc ls offsite/backups/postgres
mc cp offsite/backups/postgres/<file> .
```

## 2. Restore

Copy the file into the database pod, restore, then check the data. Do this on a spare instance first.

**PostgreSQL**

```bash
kubectl cp <file> <ns>/postgres-0:/tmp/restore.dump
kubectl exec -n <ns> postgres-0 -- sh -c 'pg_restore --clean --if-exists -U "$POSTGRES_USER" -d "$POSTGRES_DB" /tmp/restore.dump'
```

**MySQL**

```bash
kubectl cp <file> <ns>/mysql-0:/tmp/restore.sql.gz
kubectl exec -n <ns> mysql-0 -- sh -c 'gunzip -c /tmp/restore.sql.gz | mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
```

**MongoDB**

```bash
kubectl cp <file> <ns>/mongodb-0:/tmp/restore.archive.gz
kubectl exec -n <ns> mongodb-0 -- sh -c 'mongorestore --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --gzip --archive=/tmp/restore.archive.gz --drop'
```

## 3. Test restores

An untested backup is a guess. Once a quarter restore the newest file into a scratch namespace
(`kubectl apply -k overlays/dev` is enough for postgres) and run a few queries.
