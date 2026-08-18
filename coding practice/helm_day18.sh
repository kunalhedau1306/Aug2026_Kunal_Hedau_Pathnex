#!/bin/bash

export PS4='[ec2-user@ip-172-31-1-189 ~]$ '

set -x

echo "========================================================"
echo "Kubernetes Practice - Day 18"
echo "Topic: Helm"
echo "Environment: Amazon EKS / Kubernetes"
echo "========================================================"

echo
echo "=============================="
echo "Topic: Helm Installation & Version"
echo "=============================="

helm version
helm env

echo
echo "=============================="
echo "Topic: Helm Repository"
echo "=============================="

helm repo list
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo bitnami

echo
echo "=============================="
echo "Topic: Helm Chart Basics"
echo "=============================="

helm create myapp

ls -l myapp
find myapp -maxdepth 2 -type f

echo
echo "=============================="
echo "Topic: Helm Chart Structure"
echo "=============================="

echo "Chart.yaml:"
cat myapp/Chart.yaml

echo
echo "values.yaml:"
cat myapp/values.yaml

echo
echo "Templates:"
ls -l myapp/templates/

echo
echo "Helpers:"
cat myapp/templates/_helpers.tpl

echo
echo "=============================="
echo "Topic: Helm Lint"
echo "=============================="

helm lint myapp

echo
echo "=============================="
echo "Topic: Helm Template"
echo "=============================="

helm template myapp ./myapp

echo
echo "=============================="
echo "Topic: Helm Template with Custom Values"
echo "=============================="

helm template myapp ./myapp \
  --set replicaCount=2

echo
echo "=============================="
echo "Topic: Helm Install"
echo "=============================="

kubectl create namespace helm-demo

helm install myapp ./myapp \
  --namespace helm-demo

echo
echo "=============================="
echo "Topic: Helm Releases"
echo "=============================="

helm list -A
helm list -n helm-demo
helm status myapp -n helm-demo

echo
echo "=============================="
echo "Topic: Kubernetes Resources Created by Helm"
echo "=============================="

kubectl get all -n helm-demo
kubectl get pods -n helm-demo
kubectl get deployments -n helm-demo
kubectl get services -n helm-demo

echo
echo "=============================="
echo "Topic: Helm Values"
echo "=============================="

helm get values myapp -n helm-demo
helm get values myapp -n helm-demo --all

echo
echo "=============================="
echo "Topic: Helm Release Manifest"
echo "=============================="

helm get manifest myapp -n helm-demo

echo
echo "=============================="
echo "Topic: Helm Release History"
echo "=============================="

helm history myapp -n helm-demo

echo
echo "=============================="
echo "Topic: Helm Upgrade"
echo "=============================="

helm upgrade myapp ./myapp \
  --namespace helm-demo \
  --set replicaCount=2

helm status myapp -n helm-demo

echo
echo "=============================="
echo "Topic: Helm Rollback"
echo "=============================="

helm history myapp -n helm-demo

# Practice rollback after identifying the required revision
# helm rollback myapp 1 -n helm-demo

echo
echo "=============================="
echo "Topic: Helm Environment Values"
echo "=============================="

mkdir -p myapp/environments

cat > myapp/environments/values-dev.yaml <<EOF
replicaCount: 1

image:
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
EOF

cat > myapp/environments/values-stage.yaml <<EOF
replicaCount: 2

image:
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
EOF

cat > myapp/environments/values-prod.yaml <<EOF
replicaCount: 3

image:
  pullPolicy: IfNotPresent

service:
  type: LoadBalancer
  port: 80
EOF

echo
echo "Development values:"
cat myapp/environments/values-dev.yaml

echo
echo "Stage values:"
cat myapp/environments/values-stage.yaml

echo
echo "Production values:"
cat myapp/environments/values-prod.yaml

echo
echo "=============================="
echo "Topic: Environment-based Helm Template"
echo "=============================="

helm template myapp ./myapp \
  -f myapp/environments/values-dev.yaml

helm template myapp ./myapp \
  -f myapp/environments/values-stage.yaml

helm template myapp ./myapp \
  -f myapp/environments/values-prod.yaml

echo
echo "=============================="
echo "Topic: Helm Dry Run"
echo "=============================="

helm upgrade myapp ./myapp \
  --namespace helm-demo \
  --set replicaCount=3 \
  --dry-run

echo
echo "=============================="
echo "Topic: Helm Variables"
echo "=============================="

helm template myapp ./myapp \
  --set replicaCount=5 \
  --set service.type=ClusterIP

echo
echo "=============================="
echo "Topic: Helm Packaging"
echo "=============================="

helm package myapp

ls -lh *.tgz

echo
echo "=============================="
echo "Topic: Helm Chart Information"
echo "=============================="

helm show chart myapp
helm show values myapp

echo
echo "=============================="
echo "Topic: Helm Search"
echo "=============================="

helm search repo nginx
helm search repo bitnami

echo
echo "=============================="
echo "Topic: Helm Uninstall"
echo "=============================="

# Uncomment when you want to remove the release

# helm uninstall myapp -n helm-demo

echo
echo "=============================="
echo "Topic: Kubernetes Verification"
echo "=============================="

kubectl get all -n helm-demo

echo
echo "========================================================"
echo "Day 18 Helm Practice Completed"
echo "========================================================"
