# Web Scrapping Container Environment

This demonstration has the purpose of showing how to develop and implement a webscrapping solution using Containers. The application can deploy webscrapping containers into either EKS or ECS, **each container will scrape its own URL defined by Controller Application**.

# Why does this demo exist?
## Scneario
You have webscraping code that you want to run in thousands of ephemeral containers using thousands of unique IPs to scrape websites for potentially malicious code. The life of each container is the duration of the webscraping job. You are working with the constraint that you must use your own pool of  elastic IP address in your VPC and not randomly assigned public IPs. Ideally you want to use AWS Fargate or Lambda services execpt the issue you've hit with is that neither of them support the use of Elastic IPs.

So you want an alternative solution using EC2 based EKS (which does support Elastic IPs) but want the user experience of that service to be similar to Fargate - when it comes to automation of management overhead.

This solution showcases that by demonstrating automation in the following areas:
1. Kubernetes cluster management is automated in two ways:
   * Amazon EKS automates the control plane management including scaling and HA
   * [Karpenter](https://karpenter.sh/) automates worker node management including scaling and HA
2. Container management is automated by Kubernetes including scaling and HA
3. Karpenter itself is deployed as a Kubernets app and hence it's management is managed by Kubernetes (scaling and HA)
4. The residual management overhead that's left for the user is minimal, mostly involving design time concerns like choices for instance types and sizes & observability of infra metrics
 

## Application deployment
The user experience for deploying an application remains the same between this soltution and Fargate-EKS. Users would have to build a application container and submit it to the Kubernetes engine to run.

# Pre reqs

- kubectl
- awscli
- Pre Configured AWS auth (Access Key and Secret Key)
- Terraform 1.3.3 >
- Docker and Docker Compose
- Helm 3 > (Optional)

# Architecture Diagrams

This solution can deploy web-scrapping container apps either on EKS and on ECS.

## EKS Diagram

<p align="center"> 
<img src="static/web-scrapping-diagram-eks.jpg">
</p>

The EKS Architecture consists in the following components:

- **VPC**, with Public and Private subnets, each private subnet has the default route towards the Nat Gateway.
- **EKS Control Plane**, Kubernetes API Server components managed by AWS
- **EKS Managed Node Group**, those Nodes are needed to deploy the first Kubernetes add-ons, such as CoreDNS, Karpenter, Kube-Proxy and so on.
- **Karpenter Pod**, add-on deployed into the EKS cluster that will be responsible to scale the nodes up and down.
- **S3 Bucket**, we are using this bucket to save the scrapped content from the websites.
- **DynamoDB Table**, the DynamoDB table has the purpose of store the IP that we used for do each scrapping and the URL that it scrapped.
- **Controller App**, this application is reponsible for creating the scrapping pods into Kubernetes, **one pod per URL**.
- **Scrape App**, this is the application responsible for scrapping the URLs defined by the controller app, **one pod per URL**.

## ECS

[TBD]

# How does it work?

This demonstration consists in 3 applications, the first one is the **Controller App**, it is reponsible to provision the scrapping containers into either EKS or ECS, each container will run until scrape completition and it will be scaled down. **Scrape App** is the application responsible for scrape the URLs defined into the Controller App. **Dashboard App** that application is responsible for creating a Dashboard of how many URLs were scrapped and show how many IPs we used.

## EKS Implementation

In EKS the **Controller App** will apply the scrape application manifest (One Pod per URL), doing that a pod will be created into EKS, but since we only have one Node available for the cluster there is no space to fit the pod in, so the Pods will remain in **Pending** state. That will trigger **Kapenter** that will provision the Nodes to hadle those Pods (Defined into the provision.yaml), since we need Public IPs, Karpenter will provision those Nodes into **Public Subnets**. When launching, each Node has an [User Data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) that is responsible to assignee an **Elastic IP** that is available from your pool of elastic IPs, if you don't have any Elastic IPs available, it will use the Node own Public IP (Since we are launching it into public Subnets). After the Pods complete their Task, Karpenter will notice that it can remove the Nodes that it launched, so Karpenter will scale down the Nodes, releasing the Elastic IPs again for use. So with EKS + Karpenter and some automations, we can have the Nodes available in less than 120 seconds, **and the amount of Containers that can run in each Node, will depend on how you have configured Karpenter Provisioner** and how much **CPU and Memory** you have defined for you scrape app, with that Karpenter can provision more or less Nodes depending on how many it need to handle the workload, each Node has his own Public/Elastic IP, so all the Containers that run in the same Node will use that IP.

## ECS Implementation

In ECS, the **Controller App** calls the AWS API to provision the task into the ECS cluster (One task per URL), we are using **Fargate** host mode for those tasks, and because of that we don't have any servers to manage. Each Fargate task is deployed into a Public Subnet, doing that each Task will have its own Public IP. After the scrape completes, the Fargate task will be scaled down. With that solution we cannot use Elastic Ips, since Fargate doens't supports it.

# Deploying the solution

For deploying the solution we are gonna need to execute few steps, everything in this repository is automated to make it easier to reproduce in any AWS account.

## Deploying using Terraform

We are using [EKS Blueprints](https://github.com/aws-ia/terraform-aws-eks-blueprints) for the EKS componentes, and pure terraform registry aws resources for other resourcers, such as, S3 bucket, DynamoDB table etc.

```bash
cd terraform
terraform init
```

Terraform init is responsible for initializing the resources, now let's plan, with `terraform plan` we are able to see the infraestructure changes that are gonna be executed.

```bash
terraform plan -var='aws_region=YOUR_REGION_HERE'
```

Replace the region with your region, you should see an output similar to this:

<p align="center"> 
<img src="static/terraform-output.png">
</p>

Let's now apply, with `terraform apply` it will create the entire needed infraestructure.

```bash
terraform apply -var='aws_region=us-east-1' --auto-approve
```

This will take around 20 minutes to execute.

## Testing cluster access

Let's test the clister access by executing the following `kubectl` commands:

```bash
kubectl get nodes
```

## Setup Karpenter Provisioner

We are using [Karpenter](https://karpenter.sh/) for scale our Nodes in that Demonstration. Karpenter automatically launches just the right compute resources to handle your cluster's applications. It is designed to let you take full advantage of the cloud with fast and simple compute provisioning for Kubernetes clusters.

Is in the provisioner manifest where we are going to specify, the instance types, size, capacity type and more, check [this doc](https://karpenter.sh/v0.22.0/concepts/provisioners/) to understand more about Karpenter provisioner.

For the purpose of this demonstration, we are not gonna to change anything in the `provisioner.yaml` manifest file, let's apply it.

```bash
cd .. && kubectl apply -f provisioner.yaml
```

## Creating Scrape Application Image

Since the Scrape application is the only application that we are gonna execute in EKS and ECS, let's create the application image, and push to the repository created by terraform.

```bash
./automation.sh
```

It will ask you to provide the `AWS_ACCOUNT_ID` and `AWS_REGION`.

## Docker Compose

For the purpose of this demonstration, we are running both `Controller Application` and `Dashboard` locally, controllerd by docker-compose.

To run our apps, let's first replace the needed variables on `do ker-compose.yml` file, **the values that we need to replace were generated by terraform output.**

```yaml
services:
  controller-app:
      build: ./controller_app
      networks:
        - project-network
      ports:
        - "3000:5000"
      restart: always
      environment:
        AWS_ACCESS_KEY_ID: YOU HAVE TO CREATE IT (REPLACE)
        AWS_SECRET_ACCESS_KEY: YOU HAVE TO CREATE IT (REPLACE)
        AWS_DEFAULT_REGION: REGION DEFINED IN TERRAFORM (REPLACE)
        EKS_CLUSTER_NAME: web-scrapping-demo
        ECS_CLUSTER_NAME: web-scrapping-demo-ecs
        SCRAPE_IMAGE_URI: ecr_image_uri (REPLACE)
        BUCKET_NAME: s3_bucket_name (REPLACE)
        DYNAMO_DB_TABLE_NAME: web-scrapping
        PUBLIC_SUBNETS: vpc_public_subnet_ids (REPLACE)
        SECURITY_GROUPS: ecs_security_group_id (REPLACE)
        TASK_DEFINITION: web-scrapping-app:1
  dashboard-app:
      depends_on:
        - controller-app
      build: ./dashboard
      networks:
        - project-network
      ports:
        - "5000:5000"
      restart: always
      environment:
        AWS_ACCESS_KEY_ID: YOU HAVE TO CREATE IT (REPLACE)
        AWS_SECRET_ACCESS_KEY: YOU HAVE TO CREATE IT (REPLACE)
        AWS_DEFAULT_REGION: REGION DEFINED IN TERRAFORM (REPLACE)
        DYNAMO_DB_TABLE: web-scrapping
networks:
  project-network:
    driver: bridge
```

After filling the environemnt variables, it is time to execute the application locally.

```bash
docker-compose up --build
```

You should see the following result.

```
NAME                           STATUS                     ROLES    AGE   VERSION
ip-10-24-11-209.ec2.internal   Ready,SchedulingDisabled   <none>   62m   v1.23.13-eks-fb459a0
ip-10-24-12-26.ec2.internal    Ready,SchedulingDisabled   <none>   62m   v1.23.13-eks-fb459a0
```

`SchedulingDisabled` status, it means that we are going to force Karpenter to provision new Nodes to handle the Scape application pods.

## Installing kube-ops-view (Optional)

Kube-ops-view provides a common operational picture for a Kubernetes cluster that helps with understanding our cluster setup in a visual way.

```bash
helm install kube-ops-view christianknell/kube-ops-view --set service.type=LoadBalancer --set rbac.create=True
```

Kube ops view, will make easier to see how karpenter deals with scaling nodes to handle the scrape pods.

It will deploy a LoadBalancer type service, to get the URL execute the following command.

```bash
kubectl get svc kube-ops-view | awk '{print $4}' | grep -vi external
```

Open the URL into your browser, it should look like the following.

<p align="center"> 
<img src="static/kube-ops-view.png">
</p>

## Executing the Application

To guarantee that Karpenter will scale new nodes when we create the scrapping pods, let's cordon the nodes of the managed node groups, by executing the following command.

```bash
kubectl cordon $(kubectl get nodes | awk '{print $1}' | grep -vi name | xargs) && kubectl get nodes
```

Open in your browser the follow URL, http://localhost:3000/, this is the controller interface, that interface is where we are going to define the URLs for our application to scrape.

<p align="center"> 
<img src="static/scrape-controller.png">
</p>

In the text box, let's define the URLs (There is a urls.txt in this repository where you can get some urls for testing) and where we want to execute, in our case `EKS`. It should look like the following.

<p align="center"> 
<img src="static/scrape-controller-2.png">
</p>

Let's submit the request.

After doing that, you could check what is happenning behind the scenes either using `kubectl get nodes && kubectl get pods` or via kube-ops-view.

<p align="center"> 
<img src="static/kube-ops-view-new-node.png">
</p>

You will notice that a new node was already provisioned by `Karpenter` and `Kube Scheduler` already have placed the `scrape pods`, **the amount of nodes will depends on how many CPU and Memory we have defined for our application, and what are the instance types that we've defined on Karpenter provisioner.**

The pods will run until completion, after this, `Karpenter` will notice that the Node is not needed anymore and scale down the replicas.

### Dashboard Application

The Dashboard application in responsible to give you ability to visualize what URLs were scrapped by the Pods and also which IP it used for scrapping. Just open http://localhost:5000

<p align="center"> 
<img src="static/dashboard-app.png">
</p>

# Cleaning