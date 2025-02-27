# terraform-fsxontap-aws
This repository contains Terraform configurations that deploy an [Amazon FSx for NetApp ONTAP](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html), a couple of EC2 instances running Ubuntu as clients that connect to the file system over iSCSI and NFS.
There are three volumes created on the FSx file system: 
- 2 x volumes of 150GiB each that are being connected over iSCSI one to each Ubuntu client.
- 1 x 250GiB volume connected over NFS and shared between the two Ubuntu clients

## Prerequisites
* [Amazon Web Services (AWS) account](https://aws.amazon.com/).
* Terraform v1.9.4 installed on your computer. Check out HasiCorp [documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) on how to install Terraform.

## Quick start

1. Configure your [AWS access 
keys](http://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys) as 
environment variables.

```
$ export AWS_ACCESS_KEY_ID=(your access key id)
$ export AWS_SECRET_ACCESS_KEY=(your secret access key)
```
2. Clone this repository.

```
$ git clone https://github.com/RaduLupan/terraform-fsxontap-aws.git
$ cd terraform-fsxontap-aws
```
3. Deploy an Amazon FSx ONTAP file system.

```
$ cd fsxontap
$ terraform init
$ terraform apply
```
4. Deploy a couple of EC2 instances to use as clients connected to the FSx ONTAP file system.

```
$ cd ../ubuntu-clients
$ terraform init
$ terraform apply
```
As part of the user-data script that runs at startup on the client instances, the iSCSI packages are installed and multipath configured and set to run automatically.

5. (Manual) Save parameters in the SSM Parameter Store.
    - In the FSx console -> **Administration** tab -> **ONTAP administrator password** -> **Update** to create a password for the ```fsxadmin``` account.
    - Store the password in the SSM Parameter ```/fsxontap-poc/management-password```  that was created by Terraform in step 3.
    - In the FSx console -> **Administration** tab -> **Management endpoint - IP address** get the IP of the management endpoint.
    - Store the IP in the SSM Parameter ```/fsxontap-poc/management-endpoint-ip``` that was created by Terraform in step 3.
    
6. (Manual) Create two iSCSI LUNs one on each iSCSI volumes and populate SSM Parameters.
    - Use SSM Session Manager to connect to any of the two Ubuntu clients and run the bash script ```/scripts/create_iscsi_luns.sh```. The script is configured to create two 125GB LUNs on each of the iSCSI volumes which are set for 150GB. If you end up sizing your iSCSI volumes differently make sure you modify the size of the LUNs accordingly to be less than the size of respective volume to allow for snapshots and metadata.
    - From the script output (or from the log file ```/scripts/create_iscsi_luns.log```) capture the **serial-hex** value for **lun_1**.
    - Store the the **serial-hex** value for **lun_1** in the SSM Parameter ```/fsxontap-poc/iscsi-lun1-serial-hex``` that was created by Terraform in step 3.
    - From the script output (or from the log file ```/scripts/create_iscsi_luns.log```) capture the **serial-hex** value for **lun_2**.
    - Store the the **serial-hex** value for **lun_2** in the SSM Parameter ```/fsxontap-poc/iscsi-lun2-serial-hex``` that was created by Terraform in step 3.
    - From the script output (or from the log file ```/scripts/create_iscsi_luns.log```) capture the **iscsi_ip** value (either **iscsi_1** or **iscsi_2** but only the network address part, no /Mask - ie if **iscsi_1** is ```10.0.131.46/20``` the network IP is ```10.0.131.46```).
    - Store the the **iscsi_ip** value in the SSM Parameter ```/fsxontap-poc/iscsi-network-ip``` that was created by Terraform in step 3.






# References:
[Creating an iSCSI LUN](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/create-iscsi-lun.html)