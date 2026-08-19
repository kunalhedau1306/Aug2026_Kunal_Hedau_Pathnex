# EKS Terraform Troubleshooting – Worker Nodes CREATE_FAILED / NotReady

## 1. Objective

Create and troubleshoot an Amazon EKS cluster in the Mumbai AWS region (`ap-south-1`) using Terraform with:

- EKS cluster name: `demo-eks`
- Kubernetes version: `1.33`
- Worker instance type: `t3.micro`
- Minimum nodes: `1`
- Desired nodes: `2`
- Maximum nodes: `3`
- Two private subnets across two Availability Zones
- EKS managed add-ons:
  - `vpc-cni`
  - `kube-proxy`
  - `coredns`

---

# 2. Initial Terraform Configuration

The EKS module used:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "demo-eks"
  kubernetes_version = "1.33"

  endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    worker_nodes = {
      name = "eks-workers"

      instance_types = ["t3.micro"]
      ami_type       = "AL2023_x86_64_STANDARD"

      min_size     = 1
      desired_size = 2
      max_size     = 3

      capacity_type = "ON_DEMAND"
      disk_size     = 20

      labels = {
        role = "worker"
      }

      tags = {
        Environment = "dev"
        Name        = "eks-worker"
      }
    }
  }
}
```

Initially, no EKS managed add-ons were configured.

---

# 3. Terraform Apply Problem

Terraform remained waiting for the EKS managed node group for a long time.

The node group was eventually found using:

```bash
aws eks list-nodegroups \
  --region ap-south-1 \
  --cluster-name demo-eks
```

The node group name was:

```text
eks-workers-ac88b704004b22f727d01f999e
```

Checking its status:

```bash
aws eks describe-nodegroup \
  --region ap-south-1 \
  --cluster-name demo-eks \
  --nodegroup-name eks-workers-ac88b704004b22f727d01f999e \
  --query 'nodegroup.{status:status,health:health,scaling:scalingConfig,instances:resources}'
```

Returned:

```json
{
    "status": "CREATE_FAILED",
    "health": {
        "issues": [
            {
                "code": "NodeCreationFailure",
                "message": "Unhealthy nodes in the kubernetes cluster",
                "resourceIds": [
                    "i-0782d6cd35a76d17f",
                    "i-02dfb6c187e81ca41"
                ]
            }
        ]
    },
    "scaling": {
        "minSize": 1,
        "maxSize": 3,
        "desiredSize": 2
    }
}
```

At this point, the node group was known to have:

- Minimum = 1
- Desired = 2
- Maximum = 3
- Two EC2 instances
- But AWS considered the managed node group `CREATE_FAILED`

---

# 4. First Kubernetes Check

Initially:

```bash
kubectl get nodes -o wide
```

failed because the configured Kubernetes API endpoint was temporarily unresolvable.

The error was:

```text
dial tcp: lookup <old-endpoint>.yl4.ap-south-1.eks.amazonaws.com on 172.31.0.2:53:
no such host
```

The actual cluster endpoint was checked with:

```bash
aws eks describe-cluster \
  --region ap-south-1 \
  --name demo-eks \
  --query 'cluster.{status:status,endpoint:endpoint,publicAccess:endpointPublicAccess,privateAccess:endpointPrivateAccess,vpcId:resourcesVpcConfig.vpcId}'
```

The cluster was:

```text
status = ACTIVE
```

The kubeconfig endpoint was also verified:

```bash
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

After the kubeconfig was corrected/refreshed, `kubectl` could contact the cluster.

---

# 5. Authentication Troubleshooting

There was initially an AWS credential problem.

`aws sts get-caller-identity` returned:

```text
InvalidClientTokenId:
The security token included in the request is invalid.
```

Checking:

```bash
aws configure list
```

showed credentials coming from:

```text
shared-credentials-file
```

The stale credentials were removed:

```bash
rm ~/.aws/credentials
```

After that:

```bash
aws configure list
```

showed:

```text
access_key : ****************
secret_key : ****************
region     : ap-south-1
```

with the credential type:

```text
iam-role
```

The EC2 instance role was then used successfully.

Verification:

```bash
aws sts get-caller-identity
```

returned an assumed role similar to:

```text
arn:aws:sts::<account-id>:assumed-role/ec2-admin-for-eks/<instance-id>
```

### Lesson

When running Terraform/AWS CLI from an EC2 instance:

1. Remove stale static credentials if present.
2. Prefer the EC2 IAM role.
3. Verify with:

```bash
aws sts get-caller-identity
```

---

# 6. Kubernetes Authentication Check

The EKS cluster used:

```bash
aws eks describe-cluster \
  --region ap-south-1 \
  --name demo-eks \
  --query 'cluster.accessConfig'
```

Result:

```json
{
    "authenticationMode": "API_AND_CONFIG_MAP"
}
```

Access entries were checked:

```bash
aws eks list-access-entries \
  --region ap-south-1 \
  --cluster-name demo-eks
```

The EC2 role and EKS service role were present.

This established that AWS IAM authentication was configured.

---

# 7. Worker Nodes Registered but Were NotReady

After authentication was fixed:

```bash
kubectl get nodes
```

showed:

```text
NAME                                       STATUS
ip-10-0-1-10.ap-south-1.compute.internal   NotReady
ip-10-0-2-63.ap-south-1.compute.internal   NotReady
```

The next step was:

```bash
kubectl describe node ip-10-0-1-10.ap-south-1.compute.internal
```

The critical condition was:

```text
Ready False
Reason: KubeletNotReady
Message:
container runtime network not ready:
NetworkReady=false
reason:NetworkPluginNotReady
message: Network plugin returns error:
cni plugin not initialized
```

This was the key diagnostic.

---

# 8. Root Cause Identified

The worker nodes themselves were healthy enough to register with the cluster.

The important evidence was:

```text
MemoryPressure   False
DiskPressure     False
PIDPressure      False
```

The kubelet was running and the nodes were registered.

The actual failure was:

```text
CNI plugin not initialized
```

The AWS VPC CNI is responsible for providing pod networking on EKS worker nodes.

Therefore, the next check was:

```bash
kubectl get pods -n kube-system \
  -l k8s-app=aws-node \
  -o wide
```

Initially this returned:

```text
No resources found in kube-system namespace.
```

This confirmed that the `aws-node` DaemonSet was missing.

---

# 9. Check EKS Managed Add-ons

The EKS managed add-ons were checked:

```bash
aws eks list-addons \
  --region ap-south-1 \
  --cluster-name demo-eks
```

Initially:

```json
{
    "addons": []
}
```

This was the root cause.

The cluster had no managed EKS add-ons, including:

- VPC CNI
- kube-proxy
- CoreDNS

The most important missing component for the current failure was:

```text
vpc-cni
```

---

# 10. Temporary Manual Fix

The VPC CNI was installed.

After installation:

```bash
kubectl get pods -n kube-system \
  -l k8s-app=aws-node \
  -o wide
```

returned:

```text
NAME             READY   STATUS    NODE
aws-node-kn65b   2/2     Running   ip-10-0-1-10
aws-node-l8b4j   2/2     Running   ip-10-0-2-63
```

The nodes then became healthy:

```bash
kubectl get nodes -o wide
```

Result:

```text
ip-10-0-1-10.ap-south-1.compute.internal   Ready
ip-10-0-2-63.ap-south-1.compute.internal   Ready
```

### Important distinction

The manual VPC CNI installation fixed the **actual Kubernetes networking problem**, but AWS still considered the original managed node group:

```text
CREATE_FAILED
```

The EKS managed node group creation status is historical and cannot simply be changed from `CREATE_FAILED` to `ACTIVE`.

Therefore, the failed node group needed to be replaced.

---

# 11. Verify Node Group IAM

Terraform state was inspected:

```bash
terraform state list | grep -i node
```

The node group resources included:

```text
module.eks.module.eks_managed_node_group["worker_nodes"].aws_eks_node_group.this[0]
```

The node IAM role already had:

```text
AmazonEKSWorkerNodePolicy
AmazonEKS_CNI_Policy
AmazonEC2ContainerRegistryReadOnly
```

Therefore, the problem was not missing node IAM policies.

### Lesson

For EKS `NotReady` nodes, do not assume IAM is the problem.

Use:

```bash
kubectl describe node <node-name>
```

and follow the actual error.

---

# 12. Terraform Configuration Was Corrected

The EKS module was modified to manage the required EKS add-ons:

```hcl
addons = {
  vpc-cni = {
    most_recent = true
  }

  kube-proxy = {
    most_recent = true
  }

  coredns = {
    most_recent = true
  }
}
```

The complete relevant EKS configuration became:

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "demo-eks"
  kubernetes_version = "1.33"

  endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  addons = {
    vpc-cni = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    coredns = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    worker_nodes = {
      name = "eks-workers"

      instance_types = ["t3.micro"]

      ami_type = "AL2023_x86_64_STANDARD"

      min_size     = 1
      desired_size = 2
      max_size     = 3

      capacity_type = "ON_DEMAND"

      disk_size = 20

      labels = {
        role = "worker"
      }

      tags = {
        Environment = "dev"
        Name        = "eks-worker"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
```

---

# 13. Import Existing VPC CNI into Terraform

Because VPC CNI had already been manually installed, Terraform initially wanted to create it again.

The existing add-on was verified:

```bash
aws eks describe-addon \
  --region ap-south-1 \
  --cluster-name demo-eks \
  --addon-name vpc-cni \
  --query 'addon.{name:addonName,status:status,version:addonVersion}'
```

Result:

```json
{
    "name": "vpc-cni",
    "status": "ACTIVE",
    "version": "v1.22.4-eksbuild.3"
}
```

Instead of deleting it, it was imported into Terraform:

```bash
terraform import \
  'module.eks.aws_eks_addon.this["vpc-cni"]' \
  'demo-eks:vpc-cni'
```

Import succeeded.

### Why import?

Without import:

```text
AWS:
vpc-cni exists

Terraform:
vpc-cni does not exist in state
```

Terraform would attempt to create a duplicate.

After import:

```text
AWS:
vpc-cni exists

Terraform:
vpc-cni exists in state
```

Terraform can now manage the existing resource.

---

# 14. Terraform Detected the Failed Node Group as Tainted

The final plan showed:

```text
module.eks.module.eks_managed_node_group["worker_nodes"].aws_eks_node_group.this[0]
is tainted, so must be replaced
```

The old resource had:

```text
status = "CREATE_FAILED"
```

Terraform therefore planned:

```text
+/- create replacement and then destroy
```

This was the correct action.

The replacement would create a new node group with:

```text
instance type = t3.micro
min           = 1
desired       = 2
max           = 3
```

while removing the old failed node group.

---

# 15. Final Terraform Apply

Terraform was applied after confirming that the replacement was limited to the failed node group and that the EKS add-ons were included.

The new node group was created successfully.

New nodes appeared:

```text
ip-10-0-1-126.ap-south-1.compute.internal   Ready
ip-10-0-2-52.ap-south-1.compute.internal    Ready
```

The old node IPs were replaced.

---

# 16. Final Kubernetes Verification

Run:

```bash
kubectl get nodes -o wide
```

Final result:

```text
NAME                                        STATUS
ip-10-0-1-126.ap-south-1.compute.internal   Ready
ip-10-0-2-52.ap-south-1.compute.internal    Ready
```

Both nodes were:

```text
Ready
```

---

# 17. Verify Kubernetes System Pods

Run:

```bash
kubectl get pods -n kube-system -o wide
```

Final result included:

```text
aws-node-*       2/2   Running
coredns-*        1/1   Running
kube-proxy-*     1/1   Running
```

This confirmed that all major EKS networking and DNS components were healthy.

---

# 18. Verify EKS Add-ons

Run:

```bash
aws eks list-addons \
  --region ap-south-1 \
  --cluster-name demo-eks
```

Final result:

```json
{
    "addons": [
        "coredns",
        "kube-proxy",
        "vpc-cni"
    ]
}
```

The add-ons were now managed by Terraform.

---

# 19. Verify Final Node Group

The old failed node group:

```text
eks-workers-ac88b704004b22f727d01f999e
```

was replaced by:

```text
eks-workers-166b7c9b611db9647ebfe9c9e0
```

Verification:

```bash
aws eks describe-nodegroup \
  --region ap-south-1 \
  --cluster-name demo-eks \
  --nodegroup-name eks-workers-166b7c9b611db9647ebfe9c9e0 \
  --query 'nodegroup.{status:status,health:health,scaling:scalingConfig,instanceTypes:instanceTypes}'
```

Final result:

```json
{
    "status": "ACTIVE",
    "health": {
        "issues": []
    },
    "scaling": {
        "minSize": 1,
        "maxSize": 3,
        "desiredSize": 2
    },
    "instanceTypes": [
        "t3.micro"
    ]
}
```

This confirms:

- Node group = `ACTIVE`
- Health issues = none
- Minimum = `1`
- Desired = `2`
- Maximum = `3`
- Instance type = `t3.micro`

---

# 20. Final Architecture

```text
                         AWS Mumbai
                        ap-south-1
                            |
                       EKS demo-eks
                            |
             +--------------+--------------+
             |              |              |
          VPC CNI       kube-proxy       CoreDNS
          Running        Running          Running
             |              |              |
             +--------------+--------------+
                            |
                    Managed Node Group
                            |
                    Auto Scaling Group
                            |
                +-----------+-----------+
                |                       |
             t3.micro                t3.micro
           10.0.1.126              10.0.2.52
              Ready                   Ready
                            |
                 Auto Scaling settings
                            |
                    min     = 1
                    desired = 2
                    max     = 3
```

---

# 21. Root Cause Summary

## Primary root cause

The EKS cluster was initially created without the required managed add-ons.

Specifically, the AWS VPC CNI was missing.

The worker nodes therefore registered with the Kubernetes API but could not initialize pod networking.

The critical error was:

```text
NetworkPluginNotReady
CNI plugin not initialized
```

## Why the EC2 instances were not the primary problem

The worker instances were:

- Running
- Able to register with the Kubernetes API
- Running kubelet
- Running containerd
- Reporting sufficient memory
- Reporting no disk pressure
- Reporting no PID pressure

The failure was specifically the network plugin.

## Why the node group became CREATE_FAILED

EKS health checks saw that the worker nodes were unhealthy:

```text
NodeCreationFailure
Unhealthy nodes in the kubernetes cluster
```

Therefore the managed node group creation was marked:

```text
CREATE_FAILED
```

Even after fixing the CNI manually, the historical node group remained `CREATE_FAILED`.

Terraform subsequently replaced the tainted node group.

---

# 22. Troubleshooting Decision Tree

When an EKS worker node is `NotReady`:

```text
kubectl get nodes
        |
        v
     NotReady
        |
        v
kubectl describe node <node>
        |
        +----------------------------+
        |                            |
        v                            v
CNI/network error              Other condition
        |                            |
        v                            v
Check aws-node                 Investigate condition
        |
        v
kubectl get pods -n kube-system \
  -l k8s-app=aws-node
        |
        +--------------------+
        |                    |
        v                    v
aws-node missing        aws-node Running
        |                    |
        v                    v
Check EKS add-ons        Check CNI logs,
        |                 IAM, subnet,
        v                 security/network
aws eks list-addons
        |
        v
vpc-cni missing?
        |
        v
Install/manage vpc-cni
        |
        v
Check nodes again
```

---

# 23. Useful Commands

## Check cluster

```bash
aws eks describe-cluster \
  --region ap-south-1 \
  --name demo-eks
```

## List node groups

```bash
aws eks list-nodegroups \
  --region ap-south-1 \
  --cluster-name demo-eks
```

## Check node group

```bash
aws eks describe-nodegroup \
  --region ap-south-1 \
  --cluster-name demo-eks \
  --nodegroup-name <node-group-name>
```

## Check Kubernetes nodes

```bash
kubectl get nodes -o wide
```

## Describe a node

```bash
kubectl describe node <node-name>
```

## Check AWS VPC CNI

```bash
kubectl get pods -n kube-system \
  -l k8s-app=aws-node \
  -o wide
```

## Check all system pods

```bash
kubectl get pods -n kube-system -o wide
```

## Check EKS add-ons

```bash
aws eks list-addons \
  --region ap-south-1 \
  --cluster-name demo-eks
```

## Check one add-on

```bash
aws eks describe-addon \
  --region ap-south-1 \
  --cluster-name demo-eks \
  --addon-name vpc-cni
```

## Check AWS identity

```bash
aws sts get-caller-identity
```

## Check Terraform resources

```bash
terraform state list
```

## Check Terraform plan

```bash
terraform plan
```

## Check Terraform formatting

```bash
terraform fmt
```

---

# 24. Interview Questions From This Troubleshooting Exercise

## Q1. Why was the EKS node NotReady?

Because the AWS VPC CNI was not initialized.

The exact kubelet message was:

```text
NetworkPluginNotReady
CNI plugin not initialized
```

## Q2. How do you troubleshoot a NotReady EKS node?

Start with:

```bash
kubectl describe node <node-name>
```

Then inspect:

```bash
kubectl get pods -n kube-system
```

For AWS VPC CNI specifically:

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
```

## Q3. What is the `aws-node` pod?

`aws-node` is the DaemonSet created by the AWS VPC CNI. It runs on worker nodes and provides pod networking and IP address management.

## Q4. Why were the EC2 instances running while Kubernetes showed NotReady?

EC2 instance health and Kubernetes node readiness are different things.

The operating system and kubelet can be running while Kubernetes reports the node as `NotReady` because networking, storage, container runtime, or another node condition is unhealthy.

## Q5. What does `CREATE_FAILED` mean for an EKS managed node group?

It means EKS failed its node group creation/health checks. In this case, the worker instances existed but were unhealthy from Kubernetes' perspective.

## Q6. Can you change CREATE_FAILED to ACTIVE manually?

No. A failed managed node group creation should be replaced/recreated rather than attempting to change its historical creation status.

## Q7. Why import the VPC CNI into Terraform?

Because it already existed in AWS after the manual fix. Importing it brought the existing AWS resource into Terraform state so Terraform could manage it instead of trying to create a duplicate.

## Q8. Why use EKS managed add-ons?

They allow AWS-supported components such as:

- VPC CNI
- kube-proxy
- CoreDNS

to be managed through EKS and, in this case, declaratively through Terraform.

## Q9. What is the difference between desired, minimum and maximum node count?

```text
min     = 1
desired = 2
max     = 3
```

- `min`: lowest number of nodes the Auto Scaling Group should maintain.
- `desired`: current target number of nodes.
- `max`: highest number of nodes the Auto Scaling Group can scale to.

Desired is the starting target. Minimum and maximum define the allowed range.

## Q10. Does setting min=1, desired=2, max=3 automatically mean CPU-based autoscaling?

No.

Those values define the Auto Scaling Group's capacity limits and desired capacity. They do not by themselves create a Kubernetes workload-based scaling policy.

For Kubernetes workload autoscaling, services such as the Horizontal Pod Autoscaler and Cluster Autoscaler/Karpenter are used depending on the architecture.

---

# 25. Key Lessons

1. **Always inspect `kubectl describe node` when a worker is NotReady.**
2. `NetworkPluginNotReady` strongly points toward a CNI/networking problem.
3. Check the `aws-node` DaemonSet for AWS VPC CNI issues.
4. Check EKS managed add-ons with `aws eks list-addons`.
5. Worker IAM policies and CNI installation are separate concerns.
6. An EC2 instance being `Running` does not mean the Kubernetes node is `Ready`.
7. A node group can be `CREATE_FAILED` even though its EC2 instances exist.
8. Fixing the underlying issue does not change a historical EKS node group creation failure to `ACTIVE`.
9. A failed/tainted Terraform-managed node group should be replaced.
10. When a manually created AWS resource is later added to Terraform configuration, import it into Terraform state instead of creating a duplicate.
11. Manage EKS add-ons through Terraform for repeatable infrastructure.
12. Always finish with `terraform plan` and aim for:

```text
No changes. Your infrastructure matches the configuration.
```

---

# 26. Final Result

The final EKS environment successfully achieved the original requirements:

```text
Region             = ap-south-1
Cluster            = demo-eks
Kubernetes         = 1.33
Worker type        = t3.micro

Minimum nodes      = 1
Desired nodes      = 2
Maximum nodes      = 3

Node group         = ACTIVE
Node health        = No issues

Worker node 1      = Ready
Worker node 2      = Ready

VPC CNI            = Running
kube-proxy         = Running
CoreDNS            = Running

Terraform managed  = EKS + node group + add-ons
```

The cluster is now healthy and reproducible through Terraform.

