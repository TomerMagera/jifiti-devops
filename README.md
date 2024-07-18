# Jifiti - DevOps EKS Application Deployment task ***Hello World***

### Objective
Deploy a simple "Hello World" application on Amazon EKS, using Terraform and Helm, with the EKS cluster in private subnets.

## Table of Contents

1. [Requirements](#requirements)
2. [Deliverables](#deliverables)
3. [Prerequisites](#prerequisites-and-setup)
4. [Solution description](#solution-description)
    - [Terraform](#terraform)
    - [Terraform variables](#terraform-variables)
    - [Helm Chart](#helm-chart)
5. [Usage](#usage)
    - [Terraform](#terraform-1)
    - [helm chart](#helm-chart-1)
    - [Cleanup](#cleanup)

## Requirements
[↑ Back to top](#table-of-contents)

1. Infrustructure as Code (IaC - Terraform)
    - Use terraform to create 
        - VPC with CIDR block 10.0.0.0/24
        - 2 public subnets in different AZs
        - 2 private subnets in different AZs
        - Internet Gateway
        - NAT Gateway in one of the public subnets
        - Route tables for public and private subnets
        - EKS Cluster with 2 worker nodes (t3.small) in private subnets
        - Security Group allowing inbound traffic on port 8000 from the ALB
2. Application
    - Use the pre-built Docker image: crccheck/hello-world
    - This image runs a web server on port 8000
3. Helm Chart
    - Create a basic helm chart for deploying the **crccheck/hello-world** application.
    - Include simple configurable parameters like replica count and image tag.
4. Deployment
    - Use Helm to deploy the application to the EKS cluster.
    - Use AWS Load Balancer Controller to create the ALM Ingress resource.
5. Documentation
    - Provide a README file with setup instructions and explanation of the solution.

## Deliverables
[↑ Back to top](#table-of-contents)

[**The Github repository where the code resides along with the documentation**](https://github.com/TomerMagera/jifiti-devops)

## Prerequisites and setup
[↑ Back to top](#table-of-contents)

Before we proceed and provision VPC and EKS Cluster using Terraform, there are a few tools to install and configure along with a few commands.

- Install [Terraform](https://www.terraform.io/downloads.html) >= 1.0.0 ( I used version 1.6.6 ) 
- Install and configure [AWS CLI](https://aws.amazon.com/cli/).
    Once completed aws cli installation, you'll need to configure it to be able to connect to the sandbox account/user:

    ```bash
    # follow instructions to provide the access key and secret access key, eu-west-1 as region
    aws configure --profile jifiti-devops 
    ```

    Once configured, your ~/.aws/config file should have the following included
    ```
    [profile jifiti-devops]
    region = eu-west-1
    ```

    and ~/.aws/credentials file should have
    ```
    [jifiti-devops]
    aws_access_key_id = <values you provided>
    aws_secret_access_key = <values you provided>
    ```

    Check that aws can connect - it should reply with user id, account, and arn of the caller.
    ```
    export AWS_PROFILE=jifiti-devops
    aws sts get-caller-identity
    ```
- Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).
- Install [helm](https://helm.sh/docs/intro/install/).

## Solution Description
[↑ Back to top](#table-of-contents)

#### Terraform
[↑ Back to top](#table-of-contents)

The code includes:
- A main root module
- 3 sub modules which are being used/instantiated from the root module:
    - VPC module - based on [AWS VPC terraform module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
        - The module creates the VPC as per the CIDR it recieves as required (10.0.0.0/24)
        - The module is configured to create an Internet Gateway and a single NAT Gatway and associates it with the 1st public subnet.
        - The module creates 2 private subnets in 2 different AVZ
        - The module creates 2 public subnets in 2 different AVZ
        ```
        azs             = ["eu-west-1a", "eu-west-1b"]
        private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
        public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 2)]

        enable_nat_gateway = true
        single_nat_gateway = true
        create_igw         = true # this is the default
        ```
        - The module also taggs the subnets respectively with some elb specific tab, as these tags serve the AWS Load Balancer Controller Auto Subnet Discovey, according to which it associates the ALB when it creates it.
        ```
        # These tags are needed for aws load balancer controller 
        # auto subnet discovery of public/private subnets 
        public_subnet_tags = {
            "kubernetes.io/role/elb" = 1
        }

        private_subnet_tags = {
            "kubernetes.io/role/internal-elb" = 1
        }

        ```
        - The VPC module accordingly also hadles the creation of the route tables and associates the respective subnets accordingly to the correct route table
        - It also creates the respective routes in the route table, like the route where the destination to the internet points to the igw for the public subnets' route table. And the destination to the internet that points to the NAT gw for the private subnets'route table.
        - It also handles the creation of the EIP for the NAT GW.

    - EKS cluster module - based on [AWS EKS module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
        - The module creates public endpoint for the k8s API server access (for kubectl from my local machine)
        ```
        cluster_endpoint_public_access = true

        ```
        - By default provides access to the user/role that created it - additional users/roles can be added with configuration of related permissions, but it's out of the scope of the implementation.
        - All basic needed as addons as per AWS documentation are added/configured
        ```
        cluster_addons = {
            coredns = {
            most_recent = true
            }
            kube-proxy = {
            most_recent = true
            }
            vpc-cni = {
            most_recent = true
            }
            aws-ebs-csi-driver = {
            most_recent = true
            }
        }

        ```
        - The module creates a managed Node Group of 2 worker nodes, and configured to scale upto 4 nodes - nodes are of instance type `t3.small`
        ```
        eks_managed_node_groups = {
            main = {
            min_size     = 2
            max_size     = 4
            desired_size = 2

            instance_types = var.eks_instance_types
            }
        
        ```
    - AWS load balancer module based on 
        - AWS [iam-role-for-service-accounts-eks terraform module](https://github.com/terraform-aws-modules/terraform-aws-iam/tree/master/examples/iam-role-for-service-accounts-eks), for creating the IAM Role and policies for the AWS LB Controller.
        ```
        role_name                              = "${var.env_name}-eks-lb"
        attach_load_balancer_controller_policy = true

        oidc_providers = {
            main = {
            provider_arn               = var.oidc_provider_arn
            namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
            }
        }

        ```

        - Kubernetes service account  terraform resource - helping to link the k8s SA and the AWS IAM role for the AWS LB Controller.
          The role arn annotation on the k8s service account creates the linkage to the AWS IAM Role.
        ```
        metadata {
            name      = "aws-load-balancer-controller"
            namespace = "kube-system"
            labels = {
            "app.kubernetes.io/name"      = "aws-load-balancer-controller"
            "app.kubernetes.io/component" = "controller"
            }
            annotations = {
            "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
            "eks.amazonaws.com/sts-regional-endpoints" = "true"
            }
        }

        ```
        - Helm Release terraform resource - for installing the AWS Load Balancer Controller Helm chart to the EKS cluster.

    
    
#### **Terraform Variables**
[↑ Back to top](#table-of-contents)

This outlines the default variables used in the Terraform configuration.

| Name                | Description                                | Type         | Default               |
|---------------------|--------------------------------------------|--------------|-----------------------|
| `aws_profile`       | Main AWS profile to use                    | string       | `jifiti-devops`       |
| `region`            | AWS region                                 | string       | `eu-west-1`           |
| `vpc_cidr`          | CIDR of the created VPC                    | string       | `10.0.0.0/24`         |
| `cluster_name`      | Name of the EKS cluster                    | string       | `jifiti-devops-cluster`|
| `cluster_version`   | Version of the EKS cluster                 | string       | `1.29`                |
| `eks_instance_types`| Instance types for EKS nodes               | list(string) | `["t3.small"]`        |
| `rolearn`           | Add admin role to the aws-auth configmap   | string       | `null`                |
| `environment`       | Environment name                           | string       | `jifiti-devops`       |


#### Helm Chart 
[↑ Back to top](#table-of-contents)


The helm chart for deploying the application to the eks cluster, consists of the following files:
 - Chart yaml 
 - values yaml
 - tepmplates/service yaml
 - templates/deployment yaml
 - templates/ingress yaml
 - templates/helper tpl

 Values:

 values can be overriden when installing/upgrading the chart with `--set <var-name>=<new-value>`.

 - Note specifically the following values, and the comments below for them:
    - `replicaCount`
    - `ingress.annotations`
    - `image.repository`
    - `image.tag`
    - `image.pullPolicy`
    - `service.type`

- The ingress annotations
    - `internet-facing` - directs the controller to assign the ALB to a public subnet (Vs internal, to a private subnet)
    - `inbound-cidrs` - limits inbound traffic accepted by the ALB from this cidr.
    - There are many more annotations that can be used for loads of needs and scenarios.

```
# to override hello-world.fullname template, used for naming of deploy, ingress and service.
fullnameOverride: ""
# to override the Chart.name part in the hello-world.fullname/name templates
nameOverride: ""
# determine the # of pod replicas in replicaSet from the Deployment
replicaCount: 1

# Application image details
image:
  # the image registry/repository to pull the image from
  repository: crccheck/hello-world
  # the image tag to use - can be overridden in the deployment
  tag: latest
  # pullPolicy: Always, Never, IfNotPresent
  pullPolicy: IfNotPresent

# service details
service:
  type: NodePort # due to ALB target-type `instance`
  port: 8000

# ingress configurataion
ingress:
  enabled: true
  # the type of load balancer to use - in our case it's alb
  type: alb
  className: alb
  # Annotations for the aws-load-balancer-controller
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/inbound-cidrs: 5.29.154.57/32 # Tomer's specific home IP
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
  hosts:
  - host:
    paths:
    - /
```


## Usage 
[↑ Back to top](#table-of-contents)

Clone the repository:

    git clone https://github.com/TomerMagera/jifiti-devops.git

### **Terraform**
[↑ Back to top](#table-of-contents)

Change directory:

    cd jifiti-devops/terraform/infra

Update the `backend-configs/backend-jifiti-devops.conf` and update the s3 bucket and the region of your s3 bucket. Update the profile if you are not using the default profile. 

Update the `variables.tf` profile and region variables if you are not using the default profile or region used. Or create `variables.tfvars` file that will contain the values you would like to override from the default. 


Initialize the project to pull all the moduels used and the s3 backend

    terraform init -backend-config=./backend-configs/backend-jifiti-devops.conf

Validate that the project is correctly setup

    terraform validate

Run the plan command to see all the resources that will be created (use -var-file as with the init, or -var flag as needed)

    terraform plan
    
Or, plan with overriden values (`variables.tfvars`)

    terraform plan -var-file=<path-to-.tfvars-file>

When you ready, run the apply command to create the resources (use -var-file as with the init, or -var flag as needed). 

    terraform apply

Validated the resources created in the AWS console.

Update the kubectl config file with credential to connect to the newly created EKS cluster

    aws eks update-kubeconfig --name jifiti-devops-cluster

Check the connection with the API server

    kubectl get ns

### **helm chart**
[↑ Back to top](#table-of-contents)

Change directory:

    cd jifiti-devops/chart

Confirm that helm can communicate with the EKS cluster (ideally if kubectl could it should also)

    helm ls

Install the application's chart to EKS, to have a release of the chart installed.

    helm upgrade --install -n jifiti-devops --create-namespace --debug hw .

Check the ingress, service, deployment, pods resources in the `jifiti-devops` namespace, and the `aws-load-balancer-controller` pods' logs for any error.

The ingress should be updated with the DNS of the ALB, once the controller creates it.

    kubectl logs pods/aws-load-balancer-controller-... -n kube-system
    kubectl get ingress -n jifiti-devops -o yaml

Check the AWS Console for the ALB that was created.
Check its listener, and security groups and rules.
Copy the ALB DNS from the console, or from the k8s ingress...

Access the application from your browser:

    http://<ALB-DNS>

You should be able to see the "Hello World" message along with the drawing.

#### Cleanup:
[↑ Back to top](#table-of-contents)

    helm uninstall hw

Go back to the terraform configuration directory, where you applied the configuration from, and (if you used tfvars or -var, you'll need to use it with the destroy also)

    terraform destroy






