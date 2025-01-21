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
```

As part of the user-data script that runs at startup on the client instances, the iSCSI packages are installed and multipath configured and set to run automatically.

7. (Manual) Configure iSCSI on the FSx ONTAP file system:
    7.1 On the client instance get the initiator name:
    ```$ sudo cat /etc/iscsi/initiatorname.iscsi```
    7.2 Connect to the FSx ONTAP management endpoint from the OPS or client instance:
    ```$ ssh fsxadmin@management_endpoint_ip```
    7.3 Create an initiator group:
    ```$ lun igroup create -vserver svm_name -igroup igroup_name -initiator host_initiator_name -protocol iscsi -ostype linux ```
    example:
    ```$ lun igroup create -vserver svm01 -igroup igroup_1 -initiator iqn.2004-10.com.ubuntu:01:bbebbd13e7fc -protocol iscsi -ostype linux```
    7.4 Confirm that the initiator group exists:
    ```$ lun igroup show```
    7.5 Create a mapping from the LUN you created to the igroup you created:
    ```$ lun mapping create -vserver svm_name -path /vol/vol_name/lun_name -igroup igroup_name -lun-id lun_id```
    example:
    ```$ lun mapping create -vserver svm01 -path /vol/iscsi_volume2/lun_1 -igroup igroup_1 -lun-id 1 ```
    7.6 Use the lun show -path command to confirm the LUN is created, online, and mapped:
    ```$ lun show -path /vol/vol_name/lun_name -fields state,mapped,serial-hex```
    example:
    ```$ lun show -path /vol/iscsi_volume2/lun_1 -fields state,mapped,serial-hex```
    7.7 Use the network interface show -vserver command to retrieve the addresses of the iscsi_1 and iscsi_2 interfaces for the SVM in which you've created your iSCSI LUN:
    ```$ network interface show -vserver svm_name```
    example:
    ```$ network interface show -vserver svm01```
8. 
test