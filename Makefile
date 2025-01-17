ARCH := $(shell dpkg --print-architecture)
VERSION_CODENAME := $(shell . /etc/os-release && echo ""$$VERSION_CODENAME"")


.PHONY: all install-java install-maven install-docker check-prerequisites clean run build test docker-app-build docker-db-run docker-app-run db-migration

# Run all installation steps
all: install-java install-maven install-docker check-prerequisites

# Install Java (OpenJDK 11)
install-java:
	@echo "Installing Java (OpenJDK 11)..."
	@sudo apt-get update
	@sudo apt-get install -y openjdk-11-jdk
	@java -version
	@echo "Java installation completed!"

# Install Maven
install-maven:
	@echo "Installing Maven $(MAVEN_VERSION)..."
	@sudo apt-get update
	@sudo apt-get install -y wget
	@wget https://dlcdn.apache.org/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz
	@sudo tar -xvzf apache-maven-3.9.9-bin.tar.gz -C /opt
	@sudo rm -rf /usr/bin/mvn
	@sudo ln -s /opt/apache-maven-3.9.9/bin/mvn /usr/bin/mvn
	@mvn -version
	@sudo rm -rf apache-maven-3.9.9-bin.*
	@echo "Maven installation completed!"

# Install Docker (optional for containerization)
install-docker:
	@echo "Installing Docker..."
	@sudo apt-get update
	@sudo apt-get install ca-certificates curl
	@sudo install -m 0755 -d /etc/apt/keyrings
	@sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	@sudo chmod a+r /etc/apt/keyrings/docker.asc
	@echo "deb [arch=$(ARCH) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	@sudo apt-get update
	@sudo apt-get install -y -f  containerd.io docker-ce docker-ce-cli  docker-buildx-plugin docker-compose-plugin
	@docker --version
	@echo "Docker installation completed!"

# Check all prerequisites
check-prerequisites:
	@echo "Checking prerequisites..."
	@if ! command -v java >/dev/null 2>&1; then echo "Error: Java is not installed." && exit 1; fi
	@if ! command -v mvn >/dev/null 2>&1; then echo "Error: Maven is not installed." && exit 1; fi
	@if ! command -v docker >/dev/null 2>&1; then echo "Warning: Docker is not installed." && exit 0; fi
	@echo "All prerequisites are installed!"


# Maven tasks
run:
	@echo "Running Spring Boot application..."
	@mvn spring-boot:run

build:
	@echo "Building Spring Boot application..."
	@mvn clean package

test:
	@echo "Running tests..."
	@mvn test

clean:
	@echo "Cleaning project..."
	@mvn clean

lint-checkstyle:
	@echo "Running Checkstyle..."
	curl -L -o checkstyle.jar https://github.com/checkstyle/checkstyle/releases/download/checkstyle-10.12.3/checkstyle-10.12.3-all.jar
	@java -jar checkstyle.jar -c config/checkstyle.xml src/main/java/com/evertcode/phonebook/PhonebookApplication.java
	@sudo rm -rf checkstyle.jar

lint-pmd:
	@echo "Running PMD..."
	@curl -L -o pmd-bin.zip https://github.com/pmd/pmd/releases/download/pmd_releases/6.55.0/pmd-bin-6.55.0.zip && unzip pmd-bin.zip -d pmd-bin
	@./pmd-bin/pmd-bin-6.55.0/bin/run.sh pmd -d src -R config/ruleset.xml -f text
	@sudo rm -rf pmd-*

lint-spotbugs:
	@echo "Running SpotBugs..."
	@curl -L -o spotbugs-bin.zip https://github.com/spotbugs/spotbugs/releases/download/4.7.3/spotbugs-4.7.3.zip && unzip spotbugs-bin.zip
	@chmod +x spotbugs-4.7.3/bin/spotbugs
	@./spotbugs-4.7.3/bin/spotbugs .
	@sudo rm -rf spotbugs-*

lint-test: lint-checkstyle lint-checkstyle lint-spotbugs

# Docker tasks
docker-app-build:
	@echo "Building Docker image for the Spring Boot application..."
	@docker build -t phonebook-app:v1 .

docker-network-create:
	@echo "Creating Docker Private Network..."
	@docker network create privateNetwork

docker-db-run:
	@echo "Running MySQL Docker container..."
	@docker run --net=privateNetwork --name mysql-container -e MYSQL_ROOT_PASSWORD=rootpassword -e MYSQL_DATABASE=phonebook -e MYSQL_USER=phonebook -e MYSQL_PASSWORD=phonebook -d mysql:latest

docker-app-run:
	@echo "Running Spring Boot application in Docker..."
	@docker network create appNetwork
	@docker run --net=privateNetwork -p 8280:8280 -e DB_HOST=mysql-container -e DB_PORT=3306 -e DB_NAME=phonebook -e DB_USERNAME=phonebook -e DB_PASSWORD=phonebook phonebook-app:v1

db-migration:
	@echo "Restoring database from backup..."
	@if ! docker ps -q -f name=mysql-container >/dev/null; then \
		echo "MySQL container is not running. Attempting to start..."; \
		docker start mysql-container || (echo "Failed to start MySQL container. Please check the container logs." && exit 1); \
	fi
	@echo "Waiting for MySQL service to respond..."
	@count=0; \
	while ! docker exec mysql-container mysqladmin ping -u phonebook -pphonebook --silent >/dev/null 2>&1; do \
		echo "MySQL service not responding. Retrying in 5 seconds... ($$count)"; \
		sleep 5; \
		count=$$((count + 1)); \
		if [ $$count -ge 10 ]; then \
			echo "MySQL service failed to respond after multiple attempts. Exiting."; \
			exit 1; \
		fi; \
	done
	@docker exec -i mysql-container mysql -u phonebook -pphonebook phonebook < sql_backup.sql
	@echo "Database restored successfully!"



docker-compose-start:
	@chmod +x nginx/envfornginx.sh
	@./nginx/envfornginx.sh
	@docker-compose up

docker-app-start: docker-network-create docker-db-run db-migration docker-app-build docker-app-run

# Clean temporary files
clean-temp:
	@echo "Cleaning up temporary files..."
	@rm -f apache-maven-$(MAVEN_VERSION)-bin.tar.gz
	@echo "Cleanup completed!"

install-helm:
	@echo "Installing helm"
	@curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
	@chmod 700 get_helm.sh
	@./get_helm.sh
	@sudo rm -rf get_helm.sh

deploy-vault:
	@helm repo add hashicorp https://helm.releases.hashicorp.com
	@helm install vault hashicorp/vault --create-namespace --namespace vault --values k8s/deployments/vault/values.yaml
	@sleep 60

install-external-secrets:
	@helm repo add external-secrets https://charts.external-secrets.io
	@helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
	@sleep 30

deploy-secrets-store:
	@kubectl create ns phonebook-api-ns
	@kubectl apply -f k8s/deployments/secrectstore/secretstore.yaml
	@kubectl apply -f k8s/deployments/secrectstore/externersecrect.yaml
k8s-app-deploy:
	@kubectl apply -f k8s/deployments/phonebook-app/database.yaml
	@kubectl create configmap sql-file --from-file=sql_backup.sql -n phonebook-api-ns
	@kubectl apply -f k8s/deployments/phonebook-app/application.yaml
k8s-deployment: install-helm deploy-vault install-external-secrets deploy-secrets-store k8s-app-deploy