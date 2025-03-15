# fsxontap Folder

This folder contains Terraform configurations for deploying an Amazon FSx for NetApp ONTAP file system in AWS. The setup includes the creation of necessary networking components, an FSx for ONTAP file system, and related resources.

## Components

- **Amazon FSx for NetApp ONTAP File System**: Provides a high-performance storage solution with features such as NFS and iSCSI support. The configuration includes:
  - **NFS Volume**: A 250GB volume for shared access over NFS.
  - **iSCSI Volumes**: Two 150GB volumes, each dedicated to a separate client.

- **Security Group**: Configures inbound and outbound rules to control traffic for the ONTAP file system, automatically created if not specified.

- **SSM Parameter Store Entries**: Stores configuration details (e.g., management IP, user credentials) securely using AWS Systems Manager Parameter Store.

## Prerequisites

- **AWS Account**: An [Amazon Web Services (AWS) account](https://aws.amazon.com/).
- **Terraform**: Installed on your local machine, [follow the guidance](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

## Configuration

- **Providers and Variables**: Ensure correct AWS region and necessary variables are set within your Terraform configuration files.
- **Subnet Details**: Ensure subnets and VPC settings are accurate to facilitate the deployment.

## Usage

1. **Set Up AWS Credentials**: Export your AWS `access_key_id` and `secret_access_key` as environment variables.

```
export AWS_ACCESS_KEY_ID=(your_access_key_id)
export AWS_SECRET_ACCESS_KEY=(your_secret_access_key)
```

2. **Initialize and Apply Terraform Configuration**:
   
   Navigate to the `fsxontap` folder and apply the Terraform plans to deploy the resources.

```
cd fsxontap
terraform init
terraform apply
```

   Follow the on-screen prompts to confirm the deployment.

## Resources Created

- **VPC and Subnets**: Network infrastructure defined by provided subnet and VPC IDs.
- **Security Group**: Configured to allow necessary traffic to reach the FSx for ONTAP system.
- **FSx ONTAP File System**: The primary storage solution including NFS and iSCSI volumes.
- **SSM Parameters**: Securely store management data like endpoint IP, user credentials, and LUN information.

## Important Notes

- Replace placeholder values in the `main.tf` file (e.g., `<management_ip_placeholder>`, `<management_password_placeholder>`) with actual values to suit your environment needs.
- Confirm permissions and AWS Identity and Access Management (IAM) roles required for executing Terraform with AWS services.

## Further Reading

For detailed guidance on operating FSx for ONTAP, refer to the [Amazon FSx Documentation](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html).