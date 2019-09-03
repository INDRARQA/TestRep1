dotnet new sln --name adm.akspoc 
dotnet new webapi --name adm.akspoc.microservice1 --output ./adm.akspoc.microservice1 --language C#
dotnet sln add ./adm.akspoc.microservice1/adm.akspoc.microservice1.csproj

# Docker Build
docker build --pull -t adm.akspoc.microservice1 -f adm.akspoc.microservice1/Dockerfile .
docker run --name adm.akspoc.microservice1 --rm -it -p 80:80 adm.akspoc.microservice1:latest

# Publish docker image to ACR
az login
az account set --subscription e50d9638-408e-43bf-b121-7a8d836cf959 --verbose
sudo az acr login --name acrmaznaakspoc01 --verbose
sudo docker tag adm.akspoc.microservice1:latest acrmaznaakspoc01.azurecr.io/adm.akspoc.microservice1:v1
sudo docker push acrmaznaakspoc01.azurecr.io/adm.akspoc.microservice1:v1
sudo docker rmi acrmaznaakspoc01.azurecr.io/adm.akspoc.microservice1:v1

# Build and Publish to ACR using ACR Build Task
az acr build --registry acrmaznaakspoc01 \
             --image akspoc/microservice1:v2 \
             --verbose \
             --file ./adm.akspoc.microservice1/Dockerfile \
             .

# Build using ACR Task -- Doesn't work with Gitlab, only Github or Azure Repos
az acr task create \
            --registry acrmaznaakspoc01 \
            --name adm-akspoc-microservice1 \
            --image akspoc/microservice2:{{.Run.ID}} \
            --context https://code.fresco.me/bdhar1/pure-paas-aks-platform-poc.git \
            --branch master \
            --file adm.akspoc.microservice1/Dockerfile \
            --git-access-token AksZ4EX9AXNGznfFzWyx \
            --verbose

az acr repository list --name acrmaznaakspoc01 --output table

# Deploy image to AKS
az aks get-credentials --resource-group rg-maz-na-cont-qa-01 --name aksmaznashrpoc01
kubectl get nodes  # To confirm kubectl works properly
kubectl create -f api-deploy.yml


# Delete Deployments
kubectl get deployments
kubectl delete deployment microservice1-api
kubectl get services
kubectl delete service microservice1-api-ilb

# Deploy API to APIM
az group deployment create --name "Microservice1-APIM-VSet-Deployment" \
                           --resource-group "rg-maz-na-cont-qa-01" \
                           --template-file "./infrastructure/testmicroservice1.apim.vset.deploy.json" \
                           --verbose

az group deployment create --name "Microservice1-APIM-API-Deployment" \
                           --resource-group "rg-maz-na-cont-qa-01" \
                           --template-file "./infrastructure/testmicroservice1.apim.api.deploy.json" \
                           --verbose

az group deployment create --name "Microservice1-APIM-Ops-Deployment" \
                           --resource-group "rg-maz-na-cont-qa-01" \
                           --template-file "./infrastructure/testmicroservice1.apim.ops.deploy.json" \
                           --verbose

# Test Service using curl
curl -v -H "Ocp-Apim-Subscription-Key: f5ece8d6184e4baeb7ad9f1958b70ee0" https://apimmaznaakspoc01.azure-api.net/testmicroservice1/v1/requestinfo 

# Scipt to add policy to APIM
curl -v -H "Ocp-Apim-Subscription-Key: f5ece8d6184e4baeb7ad9f1958b70ee0" http://admpocappgw.eastus2.cloudapp.azure.com/testmicroservice1/v1/requestinfo 