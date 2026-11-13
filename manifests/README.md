# Common Kubernetes manifests

Reusable, single-instance baseline manifests for common services. Each folder is a
Kustomize base, so it can be applied directly or referenced as a base from an overlay.

| Service  | Kind        | Image        | Port | Storage |
|----------|-------------|--------------|------|---------|
| postgres | StatefulSet | postgres:17  | 5432 | 10Gi    |
| mysql    | StatefulSet | mysql:8.4    | 3306 | 10Gi    |
| redis    | StatefulSet | redis:7.4    | 6379 | 5Gi     |
| nginx    | Deployment  | nginx:1.27   | 80   | -       |
| mongodb  | StatefulSet | mongo:8.0    | 27017 | 10Gi   |
| rabbitmq | StatefulSet | rabbitmq:4.0-management | 5672 / 15672 (UI) | 5Gi |
| elasticsearch | StatefulSet | elasticsearch:8.15.3 | 9200 | 20Gi |
| kafka    | StatefulSet | apache/kafka:3.8.1 (KRaft) | 9092 | 20Gi |
| sonarqube | StatefulSet + Postgres | sonarqube:10.7.0-community | 9000 | 10Gi + 10Gi |
| minio    | StatefulSet | minio/minio:RELEASE.2024-10-13T13-34-11Z | 9000 / 9001 (console) | 20Gi |
| memcached | Deployment | memcached:1.6 | 11211 | -     |
| jenkins  | StatefulSet | jenkins/jenkins:2.479.1-lts-jdk17 | 8080 / 50000 (agents) | 20Gi |

Also included:

- `monitoring/` - Prometheus, Alertmanager, Grafana (with a provisioned cluster dashboard), node-exporter, kube-state-metrics, Loki and Promtail in the `monitoring` namespace
- `network-policies/` - baseline NetworkPolicies for an application namespace (default-deny ingress, then allow same-namespace, Prometheus and the ingress controller)
- `exporters/` - optional Kustomize components that add a metrics sidecar to postgres, mysql, redis and nginx
- `backups/` - nightly `pg_dump` / `mysqldump` / `mongodump` CronJobs, plus `backups/offsite/` to copy them to an S3-compatible bucket (MinIO by default); restore steps are in [../docs/restore.md](../docs/restore.md)
- `cert-manager/` and `components/cert-manager-tls/` - Let's Encrypt ClusterIssuers and a component that annotates Ingresses for them
- `external-secrets/` - example ClusterSecretStore for the External Secrets Operator
- `../overlays/` - `example/`, `dev/` and `prod/` environments composing the bases
- `../argocd/` - Argo CD project and Applications (app of apps)

## Usage

```bash
NS=my-namespace
kubectl create namespace $NS

# 1. Create the secret (every service except nginx, kafka, memcached and jenkins)
cp manifests/postgres/secret.example.yaml manifests/postgres/secret.yaml
# edit secret.yaml with real values (it is git-ignored)
kubectl apply -n $NS -f manifests/postgres/secret.yaml

# 2. Apply the service
kubectl apply -n $NS -k manifests/postgres
```

Alternatively create secrets without a file:

```bash
kubectl create secret generic postgres-secret -n $NS \
  --from-literal=POSTGRES_USER=app \
  --from-literal=POSTGRES_PASSWORD='<password>' \
  --from-literal=POSTGRES_DB=app
```

## In-cluster connection strings

- Postgres: `postgres.<ns>.svc.cluster.local:5432`
- MySQL:    `mysql.<ns>.svc.cluster.local:3306`
- Redis:    `redis.<ns>.svc.cluster.local:6379` (password required)
- Nginx:    `nginx.<ns>.svc.cluster.local:80`, or via the Ingress host
- MongoDB:  `mongodb://<user>:<password>@mongodb.<ns>.svc.cluster.local:27017`
- RabbitMQ: `amqp://rabbitmq.<ns>.svc.cluster.local:5672`, management UI on port 15672
- Elasticsearch: `http://elasticsearch.<ns>.svc.cluster.local:9200` (user `elastic`)
- Kafka:    `kafka.<ns>.svc.cluster.local:9092` (PLAINTEXT, no auth)
- SonarQube: `http://sonarqube.<ns>.svc.cluster.local:9000`, or via the Ingress host
- MinIO:    S3 API `http://minio.<ns>.svc.cluster.local:9000`, console on port 9001
- Memcached: `memcached.<ns>.svc.cluster.local:11211` (no auth)
- Jenkins:  `http://jenkins.<ns>.svc.cluster.local:8080`, agents connect on port 50000

## SonarQube

`sonarqube/` runs SonarQube with its own dedicated Postgres (`sonarqube-postgres`), so it
does not depend on the shared `postgres` base. One secret feeds both:

```bash
cp manifests/sonarqube/secret.example.yaml manifests/sonarqube/secret.yaml
# edit secret.yaml, then
kubectl apply -n $NS -f manifests/sonarqube/secret.yaml
kubectl apply -n $NS -k manifests/sonarqube
```

The first start takes a few minutes. Log in with `admin` / `admin` and change the password.
Point the scanner at it with `-Dsonar.host.url=https://sonarqube.example.com`.

## Jenkins

The admin password for the setup wizard is printed in the log on first start:

```bash
kubectl exec -n $NS jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
```

The `jenkins` ServiceAccount can create pods in its namespace, so the Kubernetes plugin
can run build agents there with the default in-cluster settings
(Jenkins URL `http://jenkins:8080`, tunnel `jenkins:50000`).

## Backups

`backups/postgres` and `backups/mysql` run a CronJob at 02:00 that dumps the database
into its own PVC and keeps 7 days of dumps. Apply in the same namespace as the database;
they reuse `postgres-secret` / `mysql-secret`:

```bash
kubectl apply -n $NS -k manifests/backups/postgres
kubectl create job -n $NS --from=cronjob/postgres-backup postgres-backup-now   # run once now
```

Restore with `pg_restore -d <db> <file>.dump` or `gunzip -c <file>.sql.gz | mysql <db>`.
Copy dumps off-cluster (e.g. to MinIO / S3) for real disaster recovery.

## Monitoring

```bash
kubectl apply -k manifests/monitoring        # creates the monitoring namespace
cp manifests/monitoring/grafana/secret.example.yaml manifests/monitoring/grafana/secret.yaml
# edit secret.yaml, then
kubectl apply -n monitoring -f manifests/monitoring/grafana/secret.yaml
```

Prometheus scrapes every pod in the cluster annotated with `prometheus.io/scrape: "true"`
and `prometheus.io/port`, plus the kubelets (through the API server) for PVC usage.
Grafana comes with Prometheus already added as its data source.

The stack also includes:

- **node-exporter** - DaemonSet on every node for CPU, memory and disk metrics
- **kube-state-metrics** - pod, deployment, job and PVC state
- **Alertmanager** - receives the alerts in `prometheus/alerts.yml` (target down, crash
  looping, pod not ready, PVC / node disk almost full, low node memory, failed jobs).
  It ships with an empty receiver: add Slack / email / webhook settings to
  `alertmanager/alertmanager.yml` to actually get notified.

Reach the UIs with port-forward:

```bash
kubectl port-forward -n monitoring svc/prometheus 9090
kubectl port-forward -n monitoring svc/alertmanager 9093
```

RabbitMQ and MinIO expose metrics natively and are already annotated. For postgres, mysql, redis and
nginx, add the matching exporter component in an overlay:

```yaml
# overlays/prod/postgres/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
resources:
  - ../../../manifests/postgres
components:
  - ../../../manifests/exporters/postgres
```

## Validation

CI (`.github/workflows/validate-manifests.yml`) runs yamllint, builds every base, overlay and
exporter component, checks the output with kubeconform, and checks the Prometheus rules and
Alertmanager config with `promtool` / `amtool`. Run the same checks locally with:

```bash
yamllint manifests overlays .github .yamllint
scripts/validate-manifests.sh          # needs kubeconform and kustomize (or kubectl)
```

## Example overlay

`overlays/example` puts postgres (with exporter, a 20Gi volume and nightly backups),
redis (with exporter) and nginx (with its own host) into an `example` namespace. Copy it
to e.g. `overlays/prod`, change the namespace and patches, then:

```bash
kubectl apply -f overlays/prod/namespace.yaml
# create postgres-secret and redis-secret in the namespace
kubectl apply -k overlays/prod
```

## Customising

Create an overlay rather than editing these bases, e.g.:

```yaml
# overlays/prod/postgres/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
resources:
  - ../../../manifests/postgres
patches:
  - target: { kind: StatefulSet, name: postgres }
    patch: |
      - op: replace
        path: /spec/volumeClaimTemplates/0/spec/resources/requests/storage
        value: 50Gi
```

## Notes

- These are single-replica databases (no replication / HA). For HA use an operator
  (CloudNativePG, MySQL Operator, Redis Sentinel, MongoDB Community Operator,
  RabbitMQ Cluster Operator, ECK, Strimzi) or the Bitnami charts.
- Elasticsearch and SonarQube set `node.store.allow_mmap=false`, so nodes do not need
  `vm.max_map_count` raised. Raise it and drop the setting for heavy workloads.
- Kafka uses a fixed `CLUSTER_ID` in `kafka/configmap.yaml`; generate your own per cluster.
- PVCs use the cluster's default StorageClass; set `storageClassName` in an overlay if needed.
- Ingresses (nginx, sonarqube, grafana, minio, jenkins) assume the `nginx` ingress class;
  change the hosts before applying.
- node-exporter runs with `hostNetwork` / `hostPID` and mounts the host root read-only;
  namespaces enforcing the `restricted` Pod Security Standard will reject it.

## Network policies and disruption budgets

`network-policies/` is a Kustomization you add to an application namespace (see
`overlays/example`). It denies all inbound traffic, then allows pods in the same namespace,
Prometheus from the `monitoring` namespace, and the ingress controller from `ingress-nginx`.
Edit `allow-ingress-controller.yaml` if your controller runs in another namespace. Do not apply
it to the `monitoring` or `ingress-nginx` namespaces. Policies only take effect if the CNI
supports them (Calico, Cilium, ...).

`nginx` ships a PodDisruptionBudget (`minAvailable: 1`) so node drains keep one replica up.
The single-replica StatefulSets (kafka, elasticsearch, ...) have none on purpose: a budget on
one replica would block node drains.

## Off-site backups

`backups/offsite/<db>` runs an hour after the dump and mirrors the backup PVC to
`s3://backups/<db>` with `mc mirror`. Create `offsite-backup-secret` from
`backups/offsite/secret.example.yaml` (a MinIO user with write access to the bucket, or S3 keys).
The PVC is mounted read-only; because the PVCs are ReadWriteOnce, keep the upload schedule
clear of the dump schedule.

## Logging

Promtail (a DaemonSet) tails `/var/log/pods` on every node (containerd, CRI-O or the docker runtime) and pushes to Loki (single binary,
20Gi, 7-day retention). Grafana has a `Loki` datasource and a provisioned "Cluster overview"
dashboard; add more JSON dashboards under `monitoring/grafana/dashboards/` and list them in its
`kustomization.yaml`. Promtail runs as root with a read-only `hostPath` mount, so the
`monitoring` namespace must not enforce the `restricted` Pod Security level.

## TLS and secrets

- **TLS:** install cert-manager, apply `cert-manager/` (set your email first), add the
  `components/cert-manager-tls` component to an overlay and give each Ingress a `tls:` section, as in
  `overlays/prod`. Test with `letsencrypt-staging` before switching to `letsencrypt-prod`.
- **Secrets:** install the External Secrets Operator, apply `external-secrets/clustersecretstore.example.yaml`
  (edited for your store), then use `ExternalSecret` objects like `overlays/prod/externalsecrets.yaml`
  instead of `secret.yaml` files.
