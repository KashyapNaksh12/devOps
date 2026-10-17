# Common Kubernetes manifests

Reusable, single-instance baseline manifests for common services. Each folder is a
Kustomize base, so it can be applied directly or referenced as a base from an overlay.

| Service  | Kind        | Image        | Port | Storage |
|----------|-------------|--------------|------|---------|
| postgres | StatefulSet | postgres:17  | 5432 | 10Gi    |
| mysql    | StatefulSet | mysql:8.4    | 3306 | 10Gi    |
| redis    | StatefulSet | redis:7.4    | 6379 | 5Gi     |
| nginx    | Deployment  | nginx:1.27   | 80   | -       |

## Usage

```bash
NS=my-namespace
kubectl create namespace $NS

# 1. Create the secret (postgres, mysql, redis)
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
  (CloudNativePG, MySQL Operator, Redis Sentinel) or the Bitnami charts.
- PVCs use the cluster's default StorageClass; set `storageClassName` in an overlay if needed.
- Nginx Ingress assumes the `nginx` ingress class; change the host before applying.
