# Terraform Destroy Troubleshooting Notes for EKS + NGINX + AWS Load Balancer Controller

## 1. Purpose

These notes document the troubleshooting process used when `terraform destroy` failed repeatedly while tearing down an Amazon EKS environment that included:

- Amazon EKS
- EKS managed node groups
- CoreDNS
- VPC networking
- Public and private subnets
- NAT / Internet Gateway dependencies
- Kubernetes namespace and NGINX workload
- Kubernetes `LoadBalancer` Service
- AWS Load Balancer Controller
- AWS Network Load Balancer
- Target Groups
- TargetGroupBindings
- Kubernetes finalizers
- AWS-created security groups

The objective was to completely remove all Terraform-managed infrastructure and clean up AWS/Kubernetes resources that remained after partial or failed destroy attempts.

## 2. Initial Destroy Failure

The first major failure happened while Terraform was trying to remove public subnets and the Internet Gateway.

Terraform eventually failed with:

```text
Error: deleting EC2 Internet Gateway:
DependencyViolation:
Network vpc-09fd306ea1802d434 has some mapped public address(es).
Please unmap those public address(es) before detaching the gateway.
```

The public subnets also failed with:

```text
DependencyViolation:
The subnet 'subnet-...' has dependencies and cannot be deleted.
```

At the same time Terraform reported:

```text
Error: Service (nginx/nginx-service) still exists
```

This indicated that the Kubernetes `LoadBalancer` Service and its AWS Network Load Balancer had not been fully cleaned up before Terraform tried to delete VPC networking.

## 3. Root Cause: Load Balancer Cleanup Was Incomplete

The NGINX Service was:

```text
Type: LoadBalancer
```

and was managed by the AWS Load Balancer Controller.

The effective dependency chain was:

```text
nginx Service
    |
    v
AWS Load Balancer Controller
    |
    v
NLB
    |
    v
Target Group
    |
    v
TargetGroupBinding
    |
    v
AWS-created Security Groups
    |
    v
Public Subnets / Internet Gateway / VPC
```

If the upper resources are not removed first, lower-level VPC resources cannot be deleted safely.

## 4. Manually Deleting the NGINX Service

The Service was deleted manually:

```bash
kubectl delete svc nginx-service -n nginx
```

Kubernetes accepted the deletion:

```text
service "nginx-service" deleted from nginx namespace
```

However, checking it again showed the Service still existed with `<pending>`, indicating that deletion had started but a finalizer was blocking completion.

## 5. Inspecting the Service Finalizer

The Service metadata was inspected:

```bash
kubectl get svc nginx-service -n nginx -o yaml \
  | grep -A10 -E 'deletionTimestamp|finalizers'
```

The result showed:

```text
deletionTimestamp: "2026-08-16T06:03:55Z"
finalizers:
- service.k8s.aws/resources
```

This confirmed that the AWS Load Balancer Controller was holding the Service until AWS-side cleanup completed.

Important rule:

**Do not remove a load-balancer finalizer before confirming the external AWS resources are gone.**

Removing it too early can orphan NLBs, target groups, security groups, and ENIs.

## 6. Verifying the NLB

The NLB was queried directly:

```bash
aws elbv2 describe-load-balancers \
  --region ap-south-1 \
  --query "LoadBalancers[?VpcId=='vpc-09fd306ea1802d434'].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table
```

The result showed the NLB was still:

```text
State: active
```

So the finalizer was still protecting a real AWS resource.

## 7. Checking AWS Load Balancer Controller Health

The controller was checked:

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

The deployment and both replicas were running.

The controller logs were then checked:

```bash
for pod in $(kubectl get pods -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  -o jsonpath='{.items[*].metadata.name}'); do

  echo "===== $pod ====="

  kubectl logs -n kube-system "$pod" \
    --since=15m | grep -iE \
    'nginx|error|delete|loadbalancer|targetgroup|finalizer|accessdenied'

done
```

## 8. Root Cause: Controller Lost STS Connectivity

The logs showed:

```text
failed to retrieve credentials
operation error STS: AssumeRoleWithWebIdentity
Post "https://sts.ap-south-1.amazonaws.com/"
dial tcp ...:443: i/o timeout
```

and also failed calls such as:

```text
EC2: DescribeSecurityGroups
```

This meant the controller was alive but could no longer refresh its IRSA credentials because it could not reach AWS STS.

The likely sequence was:

```text
terraform destroy
    |
    v
NAT/network connectivity removed too early
    |
    v
AWS Load Balancer Controller loses STS access
    |
    v
controller cannot finish AWS cleanup
    |
    v
Service / TargetGroupBinding finalizers remain
```

This was the central teardown-order problem.

## 9. Service Events Confirmed the Issue

The Service was inspected:

```bash
kubectl describe svc nginx-service -n nginx
```

Events included:

```text
Normal  DeletedLoadBalancer
```

but also repeated:

```text
Warning FailedDeployModel
failed to retrieve credentials
STS: AssumeRoleWithWebIdentity
i/o timeout
```

So cleanup had started, but the controller could not finish reconciliation.

## 10. TargetGroupBinding Was Still Present

The TargetGroupBinding was checked:

```bash
kubectl get targetgroupbindings -n nginx
```

Result:

```text
k8s-nginx-nginxser-dd8d81e9d2
```

This custom resource was still managed by the AWS Load Balancer Controller.

## 11. NLB Disappeared but Target Group Remained

Later, the NLB query returned no load balancer.

However, the target group still existed:

```bash
aws elbv2 describe-target-groups \
  --region ap-south-1 \
  --query "TargetGroups[?VpcId=='vpc-09fd306ea1802d434'].{Name:TargetGroupName,ARN:TargetGroupArn}" \
  --output table
```

The orphaned target group was:

```text
k8s-nginx-nginxser-dd8d81e9d2
```

with ARN:

```text
arn:aws:elasticloadbalancing:ap-south-1:034703319724:targetgroup/k8s-nginx-nginxser-dd8d81e9d2/3ca8250238592ad4
```

It was manually deleted:

```bash
aws elbv2 delete-target-group \
  --target-group-arn arn:aws:elasticloadbalancing:ap-south-1:034703319724:targetgroup/k8s-nginx-nginxser-dd8d81e9d2/3ca8250238592ad4 \
  --region ap-south-1
```

Then verified with `describe-target-groups` until no rows remained.

## 12. NGINX Namespace Became Stuck in Terminating

Terraform later attempted to destroy:

```text
kubernetes_namespace_v1.nginx
```

but repeatedly printed:

```text
Still destroying...
```

and eventually failed with:

```text
Error: context deadline exceeded
```

The namespace was inspected:

```bash
kubectl get namespace nginx -o yaml
```

It showed:

```text
phase: Terminating
```

and conditions:

```text
Some resources are remaining:
targetgroupbindings.elbv2.k8s.aws has 1 resource instances
```

and:

```text
Some content in the namespace has finalizers remaining:
elbv2.k8s.aws/resources
```

This directly identified the remaining blocker.

## 13. Inspecting the TargetGroupBinding Finalizer

The TargetGroupBinding was inspected:

```bash
kubectl get targetgroupbinding \
  k8s-nginx-nginxser-dd8d81e9d2 \
  -n nginx \
  -o yaml
```

Important fields:

```text
deletionTimestamp: "2026-08-16T06:43:14Z"

finalizers:
- elbv2.k8s.aws/resources
```

At this stage the NLB and target group were already gone, so the finalizer was stale.

It was removed:

```bash
kubectl patch targetgroupbinding \
  k8s-nginx-nginxser-dd8d81e9d2 \
  -n nginx \
  --type=merge \
  -p '{"metadata":{"finalizers":[]}}'
```

After that the TargetGroupBinding disappeared and the namespace was able to finish terminating.

## 14. Terraform Destroy Progressed but VPC Still Failed

Terraform successfully removed resources such as:

```text
EKS managed node group
launch template
IAM policy attachments
node IAM role
```

One attempt ended with:

```text
Error: context deadline exceeded
```

A later destroy got down to the VPC and failed with:

```text
DependencyViolation:
The vpc 'vpc-09fd306ea1802d434' has dependencies and cannot be deleted.
```

## 15. Finding the Remaining VPC Dependency

The main dependency categories were checked.

### ENIs

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=vpc-09fd306ea1802d434" \
  --query 'NetworkInterfaces[].{ENI:NetworkInterfaceId,Status:Status,Type:InterfaceType,Description:Description,Subnet:SubnetId,Attachment:Attachment.InstanceId,SGs:Groups[].GroupId}' \
  --output table
```

Result: none.

### NAT Gateways

```bash
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-09fd306ea1802d434" \
  --query 'NatGateways[].{ID:NatGatewayId,State:State,Subnet:SubnetId}' \
  --output table
```

Result: none.

### VPC Endpoints

```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-09fd306ea1802d434" \
  --query 'VpcEndpoints[].{ID:VpcEndpointId,Type:VpcEndpointType,State:State,Service:ServiceName}' \
  --output table
```

Result: none.

### Internet Gateway

```bash
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-09fd306ea1802d434" \
  --query 'InternetGateways[].{ID:InternetGatewayId,State:Attachments[0].State}' \
  --output table
```

Result: none.

### Route Tables

Only the main route table remained.

### Network ACLs

Only the default network ACL remained.

These default VPC resources are deleted automatically with the VPC.

## 16. Final VPC Blocker: Non-Default Security Groups

Security groups were listed:

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-09fd306ea1802d434" \
  --query 'SecurityGroups[].{ID:GroupId,Name:GroupName}' \
  --output table
```

Three remained:

```text
sg-0da43bbdb960f9956   k8s-traffic-demoeks-9b6da9c768
sg-0334730e25c5d1341   k8s-nginx-nginxser-cd574b41f3
sg-0016c2458c581e790   default
```

Only the default SG was allowed to remain.

The two Kubernetes-created SGs were inspected:

```bash
aws ec2 describe-security-groups \
  --group-ids \
    sg-0da43bbdb960f9956 \
    sg-0334730e25c5d1341 \
  --query 'SecurityGroups[].{ID:GroupId,Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}' \
  --output json
```

Neither referenced the other.

Because no ENIs, NLBs, or target groups remained, both SGs were safe to delete.

## 17. Deleting the Orphaned Security Groups

First:

```bash
aws ec2 delete-security-group \
  --group-id sg-0334730e25c5d1341 \
  --region ap-south-1
```

Then:

```bash
aws ec2 delete-security-group \
  --group-id sg-0da43bbdb960f9956 \
  --region ap-south-1
```

Both returned:

```text
"Return": true
```

Verification showed only:

```text
default
```

remaining.

## 18. EKS Data Source Blocked the Final Destroy

A later `terraform destroy` failed before planning because:

```text
Error: reading EKS Cluster (demo-eks): couldn't find resource
```

The problem was:

```hcl
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}
```

inside `kubernetes.tf`.

The EKS cluster had already been deleted, but Terraform still evaluated the data source during destroy planning.

Important lesson:

**Terraform data sources can still be evaluated during destroy planning.**

If they point to resources that have already been deleted, they can block the remaining teardown.

## 19. Temporarily Removing the Kubernetes Data Lookup

Since the Kubernetes and Helm-managed resources were already gone, `kubernetes.tf` was temporarily moved out of the active configuration:

```bash
mv kubernetes.tf kubernetes.tf.bak
```

Then:

```bash
terraform plan -destroy
```

showed:

```text
Plan: 0 to add, 0 to change, 1 to destroy.
```

The only remaining managed resource was the VPC.

Then:

```bash
terraform destroy
```

completed successfully:

```text
module.vpc.aws_vpc.this[0]: Destruction complete after 0s

Destroy complete! Resources: 1 destroyed.
```

## 20. Final Successful State

The environment was fully removed:

- EKS deleted
- managed node groups deleted
- NGINX namespace deleted
- NLB deleted
- target group deleted
- TargetGroupBinding deleted
- AWS Load Balancer Controller resources deleted
- Kubernetes-created non-default SGs deleted
- VPC deleted

## 21. Key Root Causes

### Root Cause 1: LoadBalancer Service cleanup happened too late

Terraform reached VPC networking before the Kubernetes Service and controller-managed AWS resources were gone.

### Root Cause 2: AWS Load Balancer Controller lost STS connectivity

Network/NAT teardown happened before the controller finished cleanup.

### Root Cause 3: Finalizers correctly blocked deletion

These finalizers remained:

```text
service.k8s.aws/resources
elbv2.k8s.aws/resources
```

They had to stay until external AWS cleanup was complete.

### Root Cause 4: Orphaned AWS resources blocked VPC deletion

The teardown left behind:

- target group
- Kubernetes-created security groups

### Root Cause 5: EKS data source was evaluated after cluster deletion

`data.aws_eks_cluster.this` failed because the cluster was already gone.

## 22. Recommended Destroy Procedure

For this architecture, use a staged teardown.

### Stage 1: Destroy the NGINX LoadBalancer Service

```bash
terraform destroy \
  -target=kubernetes_service_v1.nginx
```

Verify:

```bash
kubectl get svc nginx-service -n nginx
```

Expected: `NotFound`.

Then verify the NLB is gone.

### Stage 2: Verify Target Groups

```bash
aws elbv2 describe-target-groups \
  --region ap-south-1 \
  --query "TargetGroups[?VpcId=='<VPC_ID>']"
```

Expected:

```text
[]
```

### Stage 3: Verify TargetGroupBindings

```bash
kubectl get targetgroupbindings -A
```

There should be no binding associated with the deleted Service.

### Stage 4: Destroy NGINX Deployment and Namespace

```bash
terraform destroy \
  -target=kubernetes_deployment_v1.nginx \
  -target=kubernetes_namespace_v1.nginx
```

### Stage 5: Destroy AWS Load Balancer Controller

Destroy its Helm release, service account, IRSA role, and IAM policy only after LB cleanup is complete.

### Stage 6: Destroy EKS and VPC

```bash
terraform destroy
```

## 23. Pre-Destroy Checklist

Before a full destroy, run:

```bash
kubectl get svc -A
kubectl get targetgroupbindings -A
kubectl get namespace nginx
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

Check AWS:

```bash
aws elbv2 describe-load-balancers --region ap-south-1
aws elbv2 describe-target-groups --region ap-south-1
```

Do not continue to VPC teardown until controller-managed LB resources are gone.

## 24. VPC Dependency Troubleshooting Checklist

If VPC deletion fails with `DependencyViolation`, check in this order:

### ENIs

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

### Load Balancers

```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?VpcId=='<VPC_ID>']"
```

### Target Groups

```bash
aws elbv2 describe-target-groups \
  --query "TargetGroups[?VpcId=='<VPC_ID>']"
```

### NAT Gateways

```bash
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=<VPC_ID>"
```

### VPC Endpoints

```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

### Internet Gateway

```bash
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=<VPC_ID>"
```

### Security Groups

```bash
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

Only `default` should remain.

### Route Tables

```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

Only the main route table should remain.

### Network ACLs

```bash
aws ec2 describe-network-acls \
  --filters "Name=vpc-id,Values=<VPC_ID>"
```

Only the default NACL should remain.

## 25. Finalizer Troubleshooting Checklist

If a Kubernetes object is stuck deleting:

```bash
kubectl get <resource> -o yaml
```

Look for:

```text
deletionTimestamp:
finalizers:
```

Common AWS Load Balancer Controller finalizers:

```text
service.k8s.aws/resources
elbv2.k8s.aws/resources
```

Do not remove them immediately.

First verify the protected AWS resources are gone.

Only then remove a stale finalizer, for example:

```bash
kubectl patch targetgroupbinding <name> \
  -n <namespace> \
  --type=merge \
  -p '{"metadata":{"finalizers":[]}}'
```

## 26. Namespace Stuck in Terminating

Check:

```bash
kubectl describe namespace <namespace>
```

Look for:

```text
NamespaceContentRemaining
NamespaceFinalizersRemaining
```

In this incident Kubernetes explicitly reported that one TargetGroupBinding remained.

That message was the direct pointer to the blocker.

## 27. Terraform State Troubleshooting

After partial destroy failures:

```bash
terraform state list
```

Then:

```bash
terraform plan -destroy
```

Repeated destroy attempts are normal after partial failures.

Typical progression:

```text
first destroy:
many resources removed, some fail

second destroy:
fewer resources remain

third destroy:
only VPC remains
```

Do not recreate resources between attempts unless necessary.

## 28. Context Deadline Exceeded

Several operations failed with:

```text
context deadline exceeded
```

This does **not** necessarily mean the resource still exists.

After a timeout:

1. inspect AWS/Kubernetes directly
2. run `terraform plan -destroy`
3. continue from refreshed state

Do not assume the whole teardown failed.

## 29. State Lock Safety

If Terraform reports a state lock:

```bash
ps -ef | grep '[t]erraform'
```

If another apply/destroy is still running:

**do not force-unlock**

Only use:

```bash
terraform force-unlock <LOCK_ID>
```

when no Terraform process is active and the lock is confirmed stale.

Avoid `-lock=false` during normal operations.

## 30. Best-Practice Destroy Flow

Recommended order:

```text
1. NGINX LoadBalancer Service
        |
        v
2. NLB
        |
        v
3. Target Groups
        |
        v
4. TargetGroupBindings
        |
        v
5. NGINX Deployment / Namespace
        |
        v
6. AWS Load Balancer Controller
        |
        v
7. Controller IAM / IRSA
        |
        v
8. EKS managed node groups
        |
        v
9. EKS add-ons
        |
        v
10. EKS cluster
        |
        v
11. NAT / route resources
        |
        v
12. Internet Gateway
        |
        v
13. Subnets
        |
        v
14. Non-default Security Groups
        |
        v
15. VPC
```

The key principle is:

**Destroy resources that need the cluster/network first, before destroying the cluster/network they depend on for cleanup.**

## 31. Recommended Terraform Design Improvement

For future builds, consider separating Terraform into two states.

### Infrastructure state

Manage:

```text
VPC
EKS
Node Groups
EKS Add-ons
IAM
```

### Platform / workload state

Manage:

```text
Kubernetes provider
Helm provider
AWS Load Balancer Controller
NGINX
LoadBalancer Services
Namespaces
```

Then destroy in this order:

```text
terraform destroy workload/platform state
        |
        v
verify NLB resources gone
        |
        v
terraform destroy infrastructure state
```

This makes teardown much more predictable and avoids circular lifecycle problems between Kubernetes resources, AWS controllers, EKS, and VPC networking.

## 32. Final Result

The full environment was ultimately destroyed successfully.

Final Terraform output:

```text
module.vpc.aws_vpc.this[0]: Destruction complete after 0s

Destroy complete! Resources: 1 destroyed.
```

That confirmed that once all stale Kubernetes and AWS dependencies were cleared, the final VPC deletion completed successfully.

