## terraform-fsxontap-aws

This repository contains Terraform configurations designed to deploy an [Amazon FSx for NetApp ONTAP](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html) system along with a couple of EC2 instances running Ubuntu. These instances connect to the file system using both iSCSI and NFS protocols.

### Volumes

- **2 iSCSI Volumes**: Each is 150GiB, with connections established individually to one Ubuntu client.
- **1 NFS Volume**: 250GiB, shared between the two Ubuntu clients.

## Prerequisites

- An [Amazon Web Services (AWS) account](https://aws.amazon.com/).
- Terraform v1.9.4 installed. Follow [HashiCorp's documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) for installation guidance.

## Quick Start

1. **Configure AWS Access**: Set your AWS credentials as environment variables.

```
export AWS_ACCESS_KEY_ID=(your_access_key_id)
export AWS_SECRET_ACCESS_KEY=(your_secret_access_key)
```

2. **Clone the Repository**:

```
git clone https://github.com/RaduLupan/terraform-fsxontap-aws.git
cd terraform-fsxontap-aws
```

3. **Deploy Amazon FSx ONTAP**:

```
cd fsxontap
terraform init
terraform apply
```

4. **Deploy Ubuntu EC2 Clients**:

```
cd ../ubuntu-clients
terraform init
terraform apply
```

   - During instance startup, the user-data script configures iSCSI packages and setups multipath for automatic operation.

5. **Configure SSM Parameter Store (Manual)**:

   - Update the ONTAP administrator password via the FSx console under the **Administration** tab -> **ONTAP administrator password** -> **Update**. Store this in the SSM Parameter Store as `/fsxontap-poc/management-password`.
   - Retrieve the Management endpoint IP via the FSx console under the **Administration** tab -> **Management endpoint - IP address**. Store this in the SSM Parameter Store as `/fsxontap-poc/management-endpoint-ip`.

6. **Create iSCSI LUNs and Update SSM Parameters (Manual)**:

   - Connect to an Ubuntu client using SSM Session Manager and execute `/scripts/create_iscsi_luns.sh`. This will create two 125GB LUNs on the iSCSI volumes. Adjust the size if your volume configurations differ to spare room for snapshots and metadata.
   - Record and store the `serial-hex` for both `lun_1` and `lun_2`, and the `iscsi_ip` from the script's output or the log `/scripts/create_iscsi_luns.log` in SSM Parameters `/fsxontap-poc/iscsi-lun1-serial-hex`, `/fsxontap-poc/iscsi-lun2-serial-hex`, and `/fsxontap-poc/iscsi-network-ip`, respectively.

7. **Mount iSCSI LUNs on Clients (Manual)**:

   - Execute `/scripts/mount_iscsi_lun.sh` on each Ubuntu client. This mounts `lun_1` on client 1 and `lun_2` on client 2 at the `/mnt/fsx_1` directory.

## References

- [Creating an iSCSI LUN](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/create-iscsi-lun.html)
- [Provisioning iSCSI for Linux](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/mount-iscsi-luns-linux.html)
- [Managing file systems with the ONTAP CLI](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/managing-resources-ontap-apps.html#fsxadmin-ontap-cli)