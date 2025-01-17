# For pre-requisites run this command
>      make all
# Set Environment variables for database
>      export DB_HOST=your-db-host
>      export DB_PORT=3306
>      export DB_NAME=phonebook
>      export DB_USERNAME=your-username
>      export DB_PASSWORD=your-password
# Test lint
  >     make lint-test
# Manual application start on local
  >     mvn install
  >     java -jar target/phonebook-0.0.1-SNAPSHOT.jar

# Run using Docker Container
  Build docker image
  >     docker buildx build -t phonebook-app:v1 .
Run docker image
  >     docker run -p 8280:8280 -e DB_HOST=Host_IP -e DB_PORT=Port -e DB_NAME=Database_Name -e DB_USERNAME=Username -e DB_PASSWORD=password phonebook-app:v1
# Run app using Docker Compose
  >     make docker-compose-start
# Make the script executable For linux
  >     cd k8s/setup
  >     chmod +x setup-minikube.sh
# Run the linux script:
  >     ./setup-minikube.sh
 # Make the script executable For windows
  >     cd k8s/setup
  >     Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
# Run the windows script:
  >     .\setup-minikube.ps1

# if kubeclt command is not present 
  >     curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  >     curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
  >     echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
  >     sudo install kubectl /usr/local/bin/kubectl
  >     kubectl version --client

# Run app using Kubernetes
  >     make k8s-deployment