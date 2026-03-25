# MATLAB Parallel Server on Kubernetes in Amazon Web Services (AWS)

This reference architecture allows you to deploy [MATLAB&reg; Parallel Server&trade; on Kubernetes&reg;](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-kubernetes) on [Amazon® Elastic Kubernetes Service&trade;](https://aws.amazon.com/eks/). After deploying this solution, you can run large-scale parallel computations without having to manage your own Kubernetes control plane. EKS provides elastic, on‑demand scaling for worker nodes, allowing MATLAB workloads to grow and shrink automatically based on demand.

## Requirements

* A MATLAB Parallel Server license. You can use either:
    * A MATLAB Parallel Server license configured to use online licensing for MATLAB. For information on how to configure your license for cloud use, see [Configure MATLAB Parallel Server Licensing for Cloud Platforms](https://www.mathworks.com/help/matlab-parallel-server/configure-matlab-parallel-server-licensing-for-cloud-platforms.html).
    * A network license manager for MATLAB hosting sufficient MATLAB Parallel Server licenses for your cluster. MathWorks&reg; provides a reference architecture to deploy a suitable [Network License Manager for MATLAB on Amazon Web Services](https://github.com/mathworks-ref-arch/license-manager-for-matlab-on-aws), or you can use an existing license manager.
* MATLAB and Parallel Computing Toolbox™ on your client machine.
* An AWS&reg; account with required permissions.
* AWS Command Line Interface (AWS CLI) installed on your client machine. For help with installing AWS CLI, see [Installing or updating to the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) on the AWS website.
* An existing VPC with two subnets. For more details, refer to the AWS documentation on [Amazon EKS networking requirements for VPC and subnets](https://docs.aws.amazon.com/eks/latest/userguide/network-reqs.html). If you need to create a new VPC, you can refer to the [VPC IaC building blocks](https://github.com/mathworks-ref-arch/iac-building-blocks/tree/main/aws/vpc-template/v1).
* AWS credent­ials configured on your client machine. For information on how to configure AWS credentials, see [Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) on the AWS website.
* Helm&reg; package manager version 3.8.0 or later installed on your client machine. For help with installing Helm, see [Quickstart Guide](https://helm.sh/docs/intro/quickstart/) on the Helm website.
* `kubectl` command-line tool installed on your client machine and configured to access your Kubernetes cluster. For help with installing `kubectl`, see [Install Tools](https://kubernetes.io/docs/tasks/tools/) on the Kubernetes website.
* Terraform&trade; or OpenTofu&trade;. For help with installing Terraform, see [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) on the HashiCorp documentation. For help with installing OpenTofu, see [Installing OpenTofu](https://opentofu.org/docs/intro/install/) on the OpenTofu documentation.

## Costs

You are responsible for the cost of the AWS services you use when you create cloud resources using this repository. Resource settings, such as instance type, affects the cost of deployment. For cost estimates, see the pricing pages for each AWS service you use. Prices are subject to change.

## Deployment Steps

These steps show you how to deploy MATLAB Parallel Server on an Amazon Elastic Kubernetes Service (EKS) cluster using Helm and either Terraform or OpenTofu.

1) Clone this repository from GitHub&reg; and navigate to the newly created folder.

```bash
git clone https://github.com/mathworks-ref-arch/matlab-parallel-server-on-eks
cd matlab-parallel-server-on-eks
```

2) Install the Helm chart dependencies using this command.

``` bash
helm dependency update ./matlab-parallel-server-on-eks-chart
```

3) Configure the Terraform variables file, `./terraform/terraform.tfvars`, for your MATLAB Parallel Server cluster. You must manually fill in the required parameters, `vpc_id`, `subnet_ids`, and `public_access_cidr_blocks`. Other parameters are optional, and you can customize them based on your requirements. Note that the number of MATLAB workers is computed automatically based on the worker node EC2 instance type and the Terraform `max_worker_nodes` setting.

4) Initialize Terraform and deploy the EKS cluster in AWS using these commands.

```bash
cd ./terraform
terraform init # or tofu init
terraform apply # or tofu apply
```

5) After Terraform deploys the EKS cluster, it prints several outputs. In these outputs, note the name of the cluster (`<eks_cluster_name>`) and the name of the Helm value override file (`<helm_values_override_file>`). You need these values for the next steps.

6) Configure your local Kubernetes configuration file so that `kubectl` can connect to your EKS cluster and run commands on this EKS cluster.

```bash
aws eks update-kubeconfig --region <AWS_REGION> --name <eks_cluster_name>
```

7) Create a namespace to isolate the MATLAB Job Scheduler from other resources on the Kubernetes cluster. Kubernetes uses namespaces to separate groups of resources. To learn more about namespaces, see the Kubernetes documentation for [Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/). 

```bash
kubectl create namespace mjs
```

8) (Optional) To customize your MATLAB Parallel Server beyond the default settings, configure the Helm Chart parameters in the `./matlab-parallel-server-on-eks-chart/values.yaml` file. For details about these parameters, see [Helm Values for MATLAB Parallel Server in Kubernetes](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-kubernetes/blob/main/helm_values.md)

9) Install the Helm chart using this command.

```bash
 cd ..
 helm install matlab-parallel-server-on-eks-chart ./matlab-parallel-server-on-eks-chart -n mjs -f terraform/<helm_value_override_file>
```

10) Check the status of the MATLAB Job Scheduler pods. When all pods display 1/1 in the READY field, your MATLAB Parallel Server cluster is ready to use. This command takes a few minutes.

```bash
kubectl get pods -n mjs -w
```

Once the `mjs-job-manager` pod is `READY 1/1`, press `Ctrl+C` to exit the watch command.

### Connect to Your Cluster From MATLAB

To connect to your cluster from MATLAB, you need the cluster profile. The cluster profile is a JSON-format file that allows the MATLAB client on your desktop to connect to your MATLAB Job Scheduler cluster. Download the cluster profile using this command.

```bash
kubectl get secrets mjs-cluster-profile --template="{{.data.profile | base64decode}}" --namespace mjs > profile.json
```

Import the cluster profile into MATLAB. For details, see [Discover Clusters and Use Cluster Profiles](https://www.mathworks.com/help/parallel-computing/discover-clusters-and-use-cluster-profiles.html). Your cluster is now ready to use from your MATLAB client. You can also share the cluster profile with other MATLAB users that want to connect to the cluster. When users first submit jobs or tasks to the cluster, they must create a username and password. 
 
If you are a cluster administrator, you can access all jobs and tasks using the administrator password. This reference architecture stores this password in a Kubernetes secret, `mjs-admin-password`. To retrieve the administrator password, use this command.  

```bash
kubectl get secret -n mjs mjs-admin-password -o jsonpath='{.data.password}' | base64 --decode
```

Your cluster remains running after you close MATLAB. To delete your cluster, follow the instructions in the [Delete Your Cloud Resources](#delete-your-cloud-resources) section.

## Delete Your Cloud Resources

You can remove the Terraform stack and all associated resources when you are done with them. Note that you cannot recover resources once they are deleted. After you delete the cloud resources, you cannot use the downloaded profile again. To delete all resources created by this reference architecture, run this command. This command can take up to 15 minutes to complete.

```bash
helm uninstall matlab-parallel-server-on-eks-chart -n mjs
cd ./terraform
terraform destroy # or tofu destroy
```

## Learn About Cluster Architecture

This reference architecture contains two main components.

1. Terraform or OpenTofu module: This module sets up all the required infrastructure in AWS, including EC2 instances, security groups, IAM roles and policies, networking components, autoscaling groups, and the EKS cluster itself.

2. Helm chart: This chart deploys MATLAB Parallel Server on the EKS cluster, including the job manager, workers, and all necessary Kubernetes resources. The Helm chart bundles two primary sub-charts, that you can configure using the Helm values file.

   * MATLAB Parallel Server in Kubernetes: Deploys the core MATLAB Parallel Server components. For more information, see the [MATLAB Parallel Server on Kubernetes](https://github.com/mathworks-ref-arch/matlab-parallel-server-on-kubernetes) GitHub repository. For details about its architecture, see [Architecture and Resources for MATLAB Parallel Server in Kubernetes](https://www.mathworks.com/help/matlab-parallel-server/run-matlab-parallel-server-on-kubernetes.html).

   * Autoscaling: Configures autoscaling for worker nodes. For more information, see [Cluster Autoscaler on AWS](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md) in the Kubernetes Autoscaler GitHub repository.

## FAQ

### What can I do with MATLAB Parallel Server?

Parallel Computing Toolbox and MATLAB Parallel Server software let you solve computationally and data-intensive programs using MATLAB and Simulink on computer clusters, clouds, and grids. Parallel processing constructs such as parallel-for loops and code blocks, distributed arrays, parallel numerical algorithms, and message-passing functions let you implement task-parallel and data-parallel algorithms at a high level in MATLAB. To learn more, see the documentation: [Parallel Computing Toolbox](https://www.mathworks.com/help/parallel-computing) and [MATLAB Parallel Server](https://www.mathworks.com/help/matlab-parallel-server/).

### What is MATLAB Job Scheduler?

MATLAB Job Scheduler is a built-in scheduler that ships with MATLAB Parallel Server. The scheduler coordinates the execution of jobs and distributes the tasks for evaluation to the server’s individual MATLAB sessions called workers. For more details, see [How Parallel Computing Toolbox Runs a Job](https://www.mathworks.com/help/parallel-computing/how-parallel-computing-products-run-a-job.html).

### How long does it take to deploy the Reference Architecture?

If you have already set up your AWS account, you can deploy this cluster in under 30 minutes. This time estimate applies only to the first deployment. Later job runs need less setup time.

### How do I manage limits for AWS services?

To learn about setting quotas, see [AWS Service Quotas](https://docs.aws.amazon.com/general/latest/gr/aws_service_limits.html).

### How can I store my Terraform state file in a remote location?

To enable collaboration and avoid issues with local state files, you can store your Terraform state file remotely. Terraform supports several remote backends, including AWS S3. To use AWS S3, configure the settings in [`./terraform/backend.tf`](./terraform/backend.tf) before running `terraform init`.

To manage multiple environments or deployments, you can use Terraform Workspaces. For details see [Terraform Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces) on the HashiCorp website.

### How do I copy the EBS Snapshot to a different region?

You can copy the EBS snapshot for a specific MATLAB version to any AWS region using these steps.

1) In the `terraform` folder of this repository, navigate to the [./terraform/locals.tf](./terraform/locals.tf) file.
2) Find the MATLAB release you want to copy, and note the corresponding `snapshot_id`.
3) In the AWS EC2 console, go to **Snapshots**, select **Public Snapshots**, and search for the `snapshot_id`.
4) Select the snapshot checkbox, then from the **Actions** dropdown, choose **Copy snapshot**.
5) In the window that appears, select your target region from the **Destination region** dropdown and click **Copy**.

For more details, see [Copy an Amazon EBS snapshot](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-copy-snapshot.html).

### How do I restrict connections to the Kubernetes control plane to a private subnet?

To restrict connections to the Kubernetes control plane to a private subnet, modify the cluster section in the Terraform template. Update the VPC configuration of the cluster to enable only private access using these commands.

```bash
#--------------------------------------------
# Cluster
#--------------------------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = var.subnet_ids
    endpoint_private_access = true
    # Restrict access to control pane to private subnet
    endpoint_public_access = false
  }

```

Any host or service accessing the cluster must be in the VPC’s private subnet. This includes the environment used to deploy the Helm chart. To access the cluster, you can use a bastion host, an AWS Lambda function, or [AWS CloudShell](https://aws.amazon.com/cloudshell/) deployed in the VPC.

The host or service accessing the cluster must also belong to the security group that allows access to the control plane node. This ensures that `kubectl` and `helm` commands can run successfully.

## Technical Support

If you require assistance or have a request for additional features or capabilities, contact [MathWorks Technical Support](https://www.mathworks.com/support/contact_us.html).

----

Copyright 2026 The MathWorks, Inc.

----
