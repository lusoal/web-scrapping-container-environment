# Web Scrapping Container Environment

This demonstration has the purpose of showing how to develop and implement a webscrapping solution using Containers. The application can deploy webscrapping containers into either EKS or ECS, **each container will scrape its own URL defined by Controller Application**.

# Pre reqs

- kubectl
- awscli
- Pre Configured AWS auth (Access Key and Secret Key)
- Terraform 1.3.3 >
- Docker and Docker Compose

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