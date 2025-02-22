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
4. (Manual) Set up admin passwords and save them in the SSM Parameter Store.
    - Set passwords for ```fsxadmin``` and ```vsadmin``` accounts.
    - Create SSM Parameter ```/fsx-ontap-poc/admin/management-ip``` string with value: ```<management_IP>```.
    - Create SSM Parameter ```/fsx-ontap-poc/admin/management-user``` string with value: ```fsxadmin```
    - Create SSM Parameter ```/fsx-ontap-poc/admin/management-pwd``` secure string with value ```<Your_fsxadmin_password>```
    
5. Deploy a couple of EC2 instances to use as clients connected to the FSx ONTAP file system.
```
$ cd ../ubuntu-clients
$ terraform init
$ terraform apply
```

As part of the user-data script that runs at startup on the client instances, the iSCSI packages are installed and multipath configured and set to run automatically.



# References:
[Creating an iSCSI LUN](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/create-iscsi-lun.html)