# Ubuntu EC2 Clients Deployment with Terraform

This folder contains Terraform configurations for deploying two Ubuntu EC2 instances. These instances are set up to connect to an FSx for NetApp ONTAP file system, using iSCSI multipath, and to automatically download and configure necessary scripts for LUN management.

## Components

- **Ubuntu EC2 Instances**: Two instances configured to connect to the FSx ONTAP file system using NFS and iSCSI with multipath.
- **Security Group**: Restricts and allows SSH access as specified.
- **IAM Roles and Policies**: Facilitates AWS SSM and other necessary interactions.
- **S3 Buckets**: Stores scripts for creating and mounting iSCSI LUNs for use by client instances.

## Prerequisites

- **AWS Account**: An [Amazon Web Services (AWS) account](https://aws.amazon.com/).
- **Terraform**: Ensure Terraform is installed, refer to [guidance](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).

## Configuration

- **AWS CLI Configuration**: Ensure AWS credentials are exported.

```
export AWS_ACCESS_KEY_ID=(your_access_key_id)
export AWS_SECRET_ACCESS_KEY=(your_secret_access_key)
```

- **Set Variables**: Confirm required variables (e.g., region, subnet IDs, etc.) are configured within Terraform files.

## Usage

1. **Clone the Repository**:

```
git clone https://github.com/RaduLupan/terraform-fsxontap-aws.git
cd terraform-fsxontap-aws/ubuntu-clients
```

2. **Initialize and Apply Terraform Configuration**:

```
terraform init
terraform apply
```

   - This step deploys two Ubuntu EC2 instances.

3. **Security Group Setup**:

   - Configures SSH access using specified CIDR.

4. **IAM Roles**:

   - Assigns necessary policies for SSM and other AWS interactions.

5. **S3 Bucket**:

   - Stores scripts (`create_iscsi_luns.sh`, `mount_iscsi_lun.sh`) for later retrieval and execution on clients.

6. **Instance Setup**:

   - During initialization, instances will:
     - Install necessary utilities (`open-iscsi`, `multipath-tools`).
     - Configure iSCSI multipath and mount NFS volumes.
     - Fetch scripts from S3 as specified by injected variables.

## Important Notes

- Ensure all IAM roles and security group permissions are configured correctly prior to deployment.
- Confirm successful script executions via system logs on the Ubuntu instances.

## Further Reading

- [Amazon FSx Documentation](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html)