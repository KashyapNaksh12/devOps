# devOps

This repository contains the following components:

- **SonarQube server** (`sonarqube/`) - holds the analysed code results
- **Sonar Scanner CLI** (`scanner/`) - used to scan the code and send the results to the SonarQube server
- **Report generator** (`sonar-report/`) - custom Python program to generate an HTML report and convert it into PDF
- **Common Kubernetes manifests** (`manifests/`) - reusable Kustomize bases for postgres, mysql, redis, nginx, mongodb, rabbitmq, elasticsearch, kafka and SonarQube, plus a Prometheus + Grafana monitoring stack (see [manifests/README.md](manifests/README.md))
- **CI** (`.github/workflows/`) - lints and validates every manifest on pull requests


## Scan your code with sonar-scanner

```bash
 /home/$Path/sonar-scanner-4.2.0.1873-linux/bin/sonar-scanner -X -Dsonar.host.url=http://sonarqube.xxx.com -Dsonar.username=admin -Dsonar.password=xxxYmMx -Dsonar.projectName=vexxxxMedia -Dsonar.projectVersion=2 -Dsonar.projectKey=vexxxxedia -Dsonar.sources=. -Dsonar.language=
```

## Save the credentials permanently in the sonar-scanner conf file
```bash
/home/ms/sonar/scanner/sonar-scanner-4.2.0.1873-linux/conf/sonar-scanner.properties

#----- Default SonarQube server
sonar.host.url=http://sonarqube.xxx.com
sonar.login=admin
sonar.password=Zmxxx

#----- Default source code encoding
sonar.sourceEncoding=UTF-8

```
## Run & Scan the code with configured conf file
```
 /home/sonar/Scanner/sonar-scanner-4.2.0.1873-linux/bin/sonar-scanner -X -Dsonar.projectName=vertexMedia -Dsonar.projectVersion=2 -Dsonar.projectKey=vertexMedia -Dsonar.sources=. -Dsonar.language=
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
| prometheus / grafana | StatefulSet / Deployment | prom/prometheus:v2.55.1, grafana/grafana:11.3.0 | 9090 / 3000 |

```bash
kubectl apply -n <namespace> -f manifests/postgres/secret.yaml   # copied from secret.example.yaml
kubectl apply -n <namespace> -k manifests/postgres
```

See [manifests/README.md](manifests/README.md) for secrets, connection strings, overlays, monitoring and local validation.
