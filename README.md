# devOps

This repository contains the following components:

- **SonarQube server** (`sonarqube/`) - holds the analysed code results
- **Sonar Scanner CLI** - used to scan the code and send the results to the SonarQube server (not stored in git; download it, see below)
- **Report generator** (`sonar-report/`) - custom Python program to generate an HTML report and convert it into PDF
- **Common Kubernetes manifests** (`manifests/`) - reusable Kustomize bases for postgres, mysql, redis, nginx, mongodb, rabbitmq, elasticsearch, kafka, SonarQube, MinIO, Memcached and Jenkins, database backup CronJobs, baseline NetworkPolicies, TLS/secrets helpers, and a Prometheus + Alertmanager + Grafana + Loki monitoring stack (see [manifests/README.md](manifests/README.md))
- **Overlays** (`overlays/`) - `example/`, `dev/` and `prod/` show how to compose the bases into an environment
- **Argo CD** (`argocd/`) - GitOps: apply `argocd/project.yaml` and `argocd/root.yaml` and Argo CD keeps dev, prod and monitoring in sync
- **Docs** (`docs/`) - backup restore runbook
- **CI** (`.github/workflows/`) - lints and validates every manifest on pull requests


## Install sonar-scanner

The scanner is not committed to this repo. Download it (it ships with its own JRE) and put it on your `PATH`:

```bash
VER=6.2.1.4610
curl -sSLO https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$VER-linux-x64.zip
unzip -q sonar-scanner-cli-$VER-linux-x64.zip -d ~/sonar
export PATH=~/sonar/sonar-scanner-$VER-linux-x64/bin:$PATH
```

## Scan your code with sonar-scanner

Use a token (My Account > Security in SonarQube) instead of a username and password, and keep it out of git:

```bash
export SONAR_TOKEN=<your-token>
sonar-scanner -Dsonar.host.url=http://sonarqube.xxx.com \
  -Dsonar.projectName=MyProject -Dsonar.projectVersion=2 \
  -Dsonar.projectKey=MyProject -Dsonar.sources=.
```

To avoid repeating the server URL, put it in `conf/sonar-scanner.properties` inside the scanner folder:

```
sonar.host.url=http://sonarqube.xxx.com
sonar.sourceEncoding=UTF-8
```

## Sonarqube PDF Report Generation

## To Setup Report Generation Code

### Requirements
```
1. python 2.7
2. pip
3. wkhtmltopdf
```

Install dependencies using
```
pip2 install -r requirements.txt
pip2 install pdfkit
```

Install wkhtmltopdf ( This is a utility used to convert html to pdf )
```
sudo apt-get install wkhtmltopdf
```

To Generate Report
```
python generator.py <sonarqube url> <sonarqube port> <username> <password> <project name>
```
```
#Example command to generate report of project "oodles" from sonarqube running on local.
python generator.py localhost 9000 admin admin oodles
```
 
This will create a report of your project in the `pdf_reports/` directory.

### NOTE: Please run the project scan at least twice before creating the PDF report, as the PDF script compares the current result with the last scan result to create the final report.

## Common Kubernetes manifests

Reusable single-instance Kustomize bases live in `manifests/`:

| Service  | Kind        | Image       | Port |
|----------|-------------|-------------|------|
| postgres | StatefulSet | postgres:17 | 5432 |
| mysql    | StatefulSet | mysql:8.4   | 3306 |
| redis    | StatefulSet | redis:7.4   | 6379 |
| nginx    | Deployment  | nginx:1.27  | 80   |
| mongodb  | StatefulSet | mongo:8.0   | 27017 |
| rabbitmq | StatefulSet | rabbitmq:4.0-management | 5672 |
| elasticsearch | StatefulSet | elasticsearch:8.15.3 | 9200 |
| kafka    | StatefulSet | apache/kafka:3.8.1 | 9092 |
| sonarqube | StatefulSet | sonarqube:10.7.0-community | 9000 |
| minio    | StatefulSet | minio/minio:RELEASE.2024-10-13T13-34-11Z | 9000 |
| memcached | Deployment | memcached:1.6 | 11211 |
| jenkins  | StatefulSet | jenkins/jenkins:2.479.1-lts-jdk17 | 8080 |
| prometheus / grafana | StatefulSet / Deployment | prom/prometheus:v2.55.1, grafana/grafana:11.3.0 | 9090 / 3000 |
| alertmanager | StatefulSet | prom/alertmanager:v0.27.0 | 9093 |

```bash
kubectl apply -n <namespace> -f manifests/postgres/secret.yaml   # copied from secret.example.yaml
kubectl apply -n <namespace> -k manifests/postgres
```

See [manifests/README.md](manifests/README.md) for secrets, connection strings, overlays, monitoring and local validation.
