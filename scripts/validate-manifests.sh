#!/usr/bin/env bash
# Render every Kustomize base under manifests/ and overlays/ (and each exporter component
# on top of its base) and validate the output against the Kubernetes schemas with kubeconform.
# Requires: kubeconform, and kustomize or kubectl.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if command -v kustomize >/dev/null; then
  build() { kustomize build "$1"; }
else
  build() { kubectl kustomize "$1"; }
fi

# Built-in schemas plus the community CRD catalog (cert-manager, External Secrets, ...).
# CRDs missing from the catalog are skipped rather than failing the run.
crds='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
validate() {
  kubeconform -strict -ignore-missing-schemas -schema-location default -schema-location "$crds" \
    -summary -output text "$@"
}

# Inside the repo: kustomize only accepts relative paths to other kustomizations.
tmp="$(mktemp -d "$root/.validate.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
failed=0

# Kustomizations (skip Components, they cannot be built on their own).
while read -r file; do
  dir="$(dirname "$file")"
  grep -q '^kind: Component' "$file" && continue
  echo "==> $dir"
  build "$dir" | validate - || failed=1
done < <(find manifests overlays -name kustomization.yaml | sort)

# Components, each applied to the base of the same name.
for comp in manifests/exporters/*/; do
  name="$(basename "$comp")"
  overlay="$tmp/$name"
  mkdir -p "$overlay"
  cat > "$overlay/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../manifests/$name
components:
  - ../../manifests/exporters/$name
YAML
  echo "==> manifests/$name + exporters/$name"
  build "$overlay" | validate - || failed=1
done

echo "==> secret examples"
find manifests -name secret.example.yaml -print0 | sort -z | xargs -0 kubeconform -strict -summary || failed=1

exit "$failed"
