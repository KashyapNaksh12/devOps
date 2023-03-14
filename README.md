# sonarqube-scanner-reportgenerator 

Repository contains all the three components tasks for below tasks :
Sonarqube server - It will hold the analised code
Sonarscanner-cli - It will used to scan the code and send the result to sonar server
Custom python program - to generate & convert html report in to PDF.


## Scan our code with sonar-scaanner

```bash
 /home/$Path/sonar-scanner-4.2.0.1873-linux/bin/sonar-scanner -X -Dsonar.host.url=http://sonarqube.xxx.com -Dsonar.username=admin -Dsonar.password=xxxYmMx -Dsonar.projectName=vexxxxMedia -Dsonar.projectVersion=2 -Dsonar.projectKey=vexxxxedia -Dsonar.sources=. -Dsonar.language=
```

## Save the creds permanent in the sonarscan conf file
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
 
This will create a report of your project in the pdf_reports/ directory.

### NOTE: Please perform two project scanning action before creating PDF report as the pdf script check current result and last scan result to create final report
