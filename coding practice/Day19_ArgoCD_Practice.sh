#!/bin/bash

export PS4='[ec2-user@ip-172-31-1-189 ~]$ '

set -x

echo "========================================================"
echo "Kubernetes Practice - Day 19"
echo "Topic: Argo CD - GitOps Continuous Delivery"
echo "Environment: Amazon EKS / Kubernetes"
echo "========================================================"

echo
echo "=============================="
echo "Topic: Argo CD Installation Check"
echo "=============================="

kubectl get namespace argocd
kubectl get pods -n argocd
kubectl get svc -n argocd
kubectl get deployments -n argocd

echo
echo "=============================="
echo "Topic: Argo CD CLI"
echo "=============================="

argocd version

echo
echo "=============================="
echo "Topic: Argo CD Applications"
echo "=============================="

argocd app list

echo
echo "=============================="
echo "Topic: Application Details"
echo "=============================="

# Replace myapp with your application name
# argocd app get myapp

echo
echo "=============================="
echo "Topic: Application Diff"
echo "=============================="

# argocd app diff myapp

echo
echo "=============================="
echo "Topic: Manual Synchronization"
echo "=============================="

# argocd app sync myapp

echo
echo "=============================="
echo "Topic: Wait for Application"
echo "=============================="

# argocd app wait myapp

echo
echo "=============================="
echo "Topic: Application History"
echo "=============================="

# argocd app history myapp

echo
echo "=============================="
echo "Topic: Kubernetes Argo CD Resources"
echo "=============================="

kubectl get applications -n argocd
kubectl get pods -n argocd
kubectl get svc -n argocd

echo
echo "=============================="
echo "Topic: Describe Application"
echo "=============================="

# kubectl describe application myapp -n argocd

echo
echo "=============================="
echo "Topic: Argo CD Clusters"
echo "=============================="

argocd cluster list

echo
echo "=============================="
echo "Topic: Port Forward Argo CD"
echo "=============================="

echo "Run separately when required:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"

echo
echo "=============================="
echo "Topic: Initial Admin Password"
echo "=============================="

echo "For a default/fresh installation:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"

echo
echo "=============================="
echo "Topic: Kubernetes Cluster"
echo "=============================="

kubectl get nodes
kubectl get namespaces

echo
echo "=============================="
echo "Topic: Application Namespace"
echo "=============================="

# Replace myapp with your namespace
# kubectl get pods -n myapp
# kubectl get deployments -n myapp
# kubectl get services -n myapp

echo
echo "=============================="
echo "Topic: Kubernetes Events"
echo "=============================="

# Replace myapp with your namespace
# kubectl get events -n myapp --sort-by=.lastTimestamp

echo
echo "=============================="
echo "Topic: Troubleshooting Commands"
echo "=============================="

echo "argocd app get myapp"
echo "argocd app diff myapp"
echo "argocd app history myapp"
echo "kubectl get applications -n argocd"
echo "kubectl describe application myapp -n argocd"
echo "kubectl get pods -n argocd"

echo
echo "=============================="
echo "Topic: GitOps Concepts"
echo "=============================="

echo "Git       = Source of Truth"
echo "Argo CD   = GitOps Continuous Delivery"
echo "Synced    = Desired state matches live state"
echo "OutOfSync = Desired state differs from live state"
echo "Self-Heal = Correct live-state drift"
echo "Prune     = Remove resources deleted from Git"

echo
echo "========================================================"
echo "Day 19 Argo CD Practice Completed"
echo "========================================================"

