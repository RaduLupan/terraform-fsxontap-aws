# terraform-fsxontap-aws
This repository contains Terraform configurations that deploy an [Amazon FSx for NetApp ONTAP](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html), a management EC2 instance for configuring the FSx ONTAP file system and a couple of example clients that connect to the file system over iSCSI and NFS.

## Prerequisites
* [Amazon Web Services (AWS) account](https://aws.amazon.com/).
* Terraform v1.9.4 installed on your computer. Check out HasiCorp [documentation](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) on how to install Terraform.

## Quick start

1. Configure your [AWS access 
keys](http://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys) as 
environment variables:

```
$ export AWS_ACCESS_KEY_ID=(your access key id)
$ export AWS_SECRET_ACCESS_KEY=(your secret access key)
```
2. Clone this repository:

```
$ git clone https://github.com/RaduLupan/terraform-fsxontap-aws.git
$ cd terraform-fsxontap-aws
```
3. Deploy an Amazon FSx ONTAP file system:

```
$ cd deploy
$ terraform init
$ terraform apply
```
4. Deploy a management EC2 instance to use for configuring the FSx file system:

```
$ cd configure
$ terraform init
$ terraform apply
```
5. (Manual) Configure the FSx ONTAP for iSCSI access:
    - Set passwords for ```fsxadmin``` and ```vsadmin``` accounts.
    - Connect to the ```OPS01``` instance deployed in step 4 using SSM Session Manager.
    - Connect to the FSx management endpoint: 
    ```$ ssh fsxadmin@management_endpoint_ip```
    - Create an iSCSI LUN on one of the two FSx volumes:
    ```$ lun create -vserver svm_name -path /vol/vol_name/lun_name -size size -ostype ostype -space-allocation enabled```
    The ```size``` value needs to be in bytes, for example, to curve a 275,000 MB on the 300,000 MB volume the size in bytes will be: 288,358,400,000 as below:
    ```$ lun create -vserver svm01 -path /vol/iscsi_volume2/lun_1 -size 288358400000 -ostype linux -space-allocation enabled```
    - Check the newly created LUN:
    ```$ lun show```
    References:
    [Creating an iSCSI LUN](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/create-iscsi-lun.html)

6. Deploy a couple of EC2 instances to use as clients connected to the FSx ONTAP file system:
```
$ cd examples
$ terraform init
$ terraform apply