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

Also included:

- `monitoring/` - Prometheus + Grafana in the `monitoring` namespace
- `exporters/` - optional Kustomize components that add a metrics sidecar to postgres, mysql, redis and nginx

## Usage

```bash
NS=my-namespace
kubectl create namespace $NS

# 1. Create the secret (every service except nginx and kafka)
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

## Monitoring

```bash
kubectl apply -k manifests/monitoring        # creates the monitoring namespace
cp manifests/monitoring/grafana/secret.example.yaml manifests/monitoring/grafana/secret.yaml
# edit secret.yaml, then
kubectl apply -n monitoring -f manifests/monitoring/grafana/secret.yaml
```

Prometheus scrapes every pod in the cluster annotated with `prometheus.io/scrape: "true"`
and `prometheus.io/port`. Grafana comes with Prometheus already added as its data source.

RabbitMQ exposes metrics natively and is already annotated. For postgres, mysql, redis and
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

CI (`.github/workflows/validate-manifests.yml`) runs yamllint and builds every base and
exporter component, checking the output with kubeconform. Run the same checks locally with:

```bash
yamllint manifests .github .yamllint
scripts/validate-manifests.sh          # needs kubeconform and kustomize (or kubectl)
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
- Nginx Ingress assumes the `nginx` ingress class; change the host before applying.
