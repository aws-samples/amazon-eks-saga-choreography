#!/bin/bash
set -ex
cd $HOME

## AWS set-up

git clone ${GIT_URL}/amazon-eks-saga-choreography-aws
cd amazon-eks-saga-choreography-aws/scripts

### SQS and SNS set-up
./choreography.sh ${REGION_ID} ${ACCOUNT_ID}

### IAM set-up
./iam.sh ${REGION_ID} ${ACCOUNT_ID} C

### ECR set-up
./ecr.sh C

### Build and push images
./images.sh ${REGION_ID} ${ACCOUNT_ID} ${GIT_URL} C
cd

## AWS RDS set-up

### RDS
git clone ${GIT_URL}/amazon-eks-saga-choreography-db
PROJECT_HOME=${PWD}/amazon-eks-saga-choreography-db
# Change this password !!
MYSQL_MASTER_PASSWORD='V3ry.Secure.Passw0rd'
RDS_DB_ID=eks-saga-db
source ${PROJECT_HOME}/scripts/db.sh
source ${PROJECT_HOME}/scripts/ddl.sh

### RDS IAM
cd ${PROJECT_HOME}/scripts
export DB_RESOURCE_ID=`aws rds describe-db-instances --db-instance-identifier ${RDS_DB_ID} --query 'DBInstances[0].DbiResourceId' --output text`
./iam.sh ${REGION_ID} ${ACCOUNT_ID} ${DB_RESOURCE_ID}
DB_ENDPOINT=`aws rds describe-db-instances --db-instance-identifier ${RDS_DB_ID} --query 'DBInstances[0].Endpoint.Address' --output text`
cd

## Amazon EKS cluster set-up

### Cluster installation
git clone ${GIT_URL}/amazon-eks-saga-choreography-cluster
cd amazon-eks-saga-choreography-cluster/yaml
EKS_CLUSTER=eks-saga-choreography
sed -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/eks-saga-demoType/'"${EKS_CLUSTER}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  -e 's/sns-policy/eks-saga-sns-orche-policy/g' \
  -e 's/sqs-policy/eks-saga-sqs-orche-policy/g' \
  cluster.yaml | eksctl create cluster -f -

### Set log group retention
aws logs put-retention-policy --log-group-name /aws/eks/${EKS_CLUSTER}/cluster --retention-in-days 1

### EKS RDS access
export EKS_VPC=`aws eks describe-cluster --name ${EKS_CLUSTER} --query 'cluster.resourcesVpcConfig.vpcId' --output text`
export RDS_VPC=`aws rds describe-db-instances --db-instance-identifier ${RDS_DB_ID} --query 'DBInstances[0].DBSubnetGroup.VpcId' --output text`
cd ../scripts
STACK_NAME=eksctl-${EKS_CLUSTER}-cluster
./rds.sh ${STACK_NAME} ${EKS_VPC} ${RDS_VPC} ${RDS_DB_ID}

### Load balancer set-up
./elb.sh ${ACCOUNT_ID}

### Container Insights
ClusterName=${EKS_CLUSTER}
LogRegion=${REGION_ID}
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluent-bit-quickstart.yaml | sed 's/{{cluster_name}}/'${ClusterName}'/;s/{{region_name}}/'${LogRegion}'/;s/{{http_server_toggle}}/"'${FluentBitHttpServer}'"/;s/{{http_server_port}}/"'${FluentBitHttpPort}'"/;s/{{read_from_head}}/"'${FluentBitReadFromHead}'"/;s/{{read_from_tail}}/"'${FluentBitReadFromTail}'"/' | kubectl apply -f - 
cd

## Deploy microservices

### Orders microservice
git clone ${GIT_URL}/amazon-eks-saga-choreography-orders
cd amazon-eks-saga-choreography-orders/yaml
sed -e 's#timeZone#Asia/Kolkata#g' \
  -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  -e 's/dbEndpoint/'"${DB_ENDPOINT}"'/g' \
  cfgmap.yaml | kubectl -n eks-saga create -f -
sed -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  orders.yaml | kubectl -n eks-saga create -f -
cd

### Inventory microservice
git clone ${GIT_URL}/amazon-eks-saga-choreography-inventory
cd amazon-eks-saga-choreography-inventory/yaml
sed -e 's#timeZone#Asia/Kolkata#g' \
  -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  -e 's/dbEndpoint/'"${DB_ENDPOINT}"'/g' \
  cfgmap.yaml | kubectl -n eks-saga create -f -
sed -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  inventory.yaml | kubectl -n eks-saga create -f -
cd

### Audit microservice
git clone ${GIT_URL}/amazon-eks-saga-choreography-audit
cd amazon-eks-saga-choreography-audit/yaml
sed -e 's#timeZone#Asia/Kolkata#g' \
  -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  -e 's/dbEndpoint/'"${DB_ENDPOINT}"'/g' \
  cfgmap.yaml | kubectl -n eks-saga create -f -
sed -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  audit.yaml | kubectl -n eks-saga create -f -
cd

### Trail microservice
git clone ${GIT_URL}/amazon-eks-saga-choreography-trail
cd amazon-eks-saga-choreography-trail/yaml
sed -e 's#timeZone#Asia/Kolkata#g' \
  -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/dbEndpoint/'"${DB_ENDPOINT}"'/g' \
  cfgmap.yaml | kubectl -n eks-saga create -f -
sed -e 's/regionId/'"${REGION_ID}"'/g' \
  -e 's/accountId/'"${ACCOUNT_ID}"'/g' \
  trail.yaml | kubectl -n eks-saga create -f -
cd

## Set retention period for log groups of Container Insights
sleep 30

aws logs put-retention-policy --log-group-name /aws/containerinsights/${EKS_CLUSTER}/application --retention-in-days 1
aws logs put-retention-policy --log-group-name /aws/containerinsights/${EKS_CLUSTER}/dataplane --retention-in-days 1
aws logs put-retention-policy --log-group-name /aws/containerinsights/${EKS_CLUSTER}/host --retention-in-days 1
aws logs put-retention-policy --log-group-name /aws/containerinsights/${EKS_CLUSTER}/performance --retention-in-days 1
