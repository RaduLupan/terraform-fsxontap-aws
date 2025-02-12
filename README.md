# terraform-fsxontap-aws
This repository contains Terraform configurations that deploy an [Amazon FSx for NetApp ONTAP](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/what-is-fsx-ontap.html), a management EC2 instance for configuring the FSx ONTAP file system and a couple of example clients that connect to the file system over iSCSI and NFS.

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
$ cd deploy
$ terraform init
$ terraform apply
```
4. Deploy a management EC2 instance to use for configuring the FSx file system.

```
$ cd configure
$ terraform init
$ terraform apply
```
5. (Manual) Configure the FSx ONTAP for iSCSI access.
    - Set passwords for ```fsxadmin``` and ```vsadmin``` accounts.
    - Connect to the ```OPS01``` instance deployed in step 4 using SSM Session Manager.
    - Connect to the FSx management endpoint.
    ```$ ssh fsxadmin@management_endpoint_ip```
    - Create an iSCSI LUN on one of the two FSx volumes.
    ```$ lun create -vserver svm_name -path /vol/vol_name/lun_name -size size -ostype ostype -space-allocation enabled```
    The ```size``` value needs to be in bytes, for example, to curve a 275,000 MB on the 300,000 MB volume the size in bytes will be: 288,358,400,000 as below:
    ```$ lun create -vserver svm01 -path /vol/iscsi_volume2/lun_1 -size 288358400000 -ostype linux -space-allocation enabled```
    - Check the newly created LUN.
    ```$ lun show```
    
    References:
    [Creating an iSCSI LUN](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/create-iscsi-lun.html)

6. Deploy a couple of EC2 instances to use as clients connected to the FSx ONTAP file system.
```
$ cd examples
$ terraform init
$ terraform apply
```

As part of the user-data script that runs at startup on the client instances, the iSCSI packages are installed and multipath configured and set to run automatically.

7. (Manual) Configure iSCSI on the FSx ONTAP file system.
    1. On the client instance get the initiator name.
    ```$ sudo cat /etc/iscsi/initiatorname.iscsi```
    2. Connect to the FSx ONTAP management endpoint from the OPS or client instance.
    ```$ ssh fsxadmin@management_endpoint_ip```
    3. Create an initiator group.
    ```$ lun igroup create -vserver svm_name -igroup igroup_name -initiator host_initiator_name -protocol iscsi -ostype linux ```
    example:
    ```$ lun igroup create -vserver svm01 -igroup igroup_1 -initiator iqn.2004-10.com.ubuntu:01:bbebbd13e7fc -protocol iscsi -ostype linux```
    4. Confirm that the initiator group exists.
    ```$ lun igroup show```
    5. Create a mapping from the LUN you created to the igroup you created.
    ```$ lun mapping create -vserver svm_name -path /vol/vol_name/lun_name -igroup igroup_name -lun-id lun_id```
    example:
    ```$ lun mapping create -vserver svm01 -path /vol/iscsi_volume2/lun_1 -igroup igroup_1 -lun-id 1 ```
    6. Use the lun show -path command to confirm the LUN is created, online, and mapped.
    ```$ lun show -path /vol/vol_name/lun_name -fields state,mapped,serial-hex```
    example:
    ```$ lun show -path /vol/iscsi_volume2/lun_1 -fields state,mapped,serial-hex```
    Record the value of the ```serial-hex``` in the output of the command above. In my example that is ```6c5742304f3f58695552727a```.
    7. Use the network interface show -vserver command to retrieve the addresses of the iscsi_1 and iscsi_2 interfaces for the SVM in which you've created your iSCSI LUN.
    ```$ network interface show -vserver svm_name```
    example:
    ```$ network interface show -vserver svm01```
    Record the iscsi_1 and iscsi_2 values IP in the output of the command above as you need them next.

8. (Manual) Mount an iSCSI LUN on your Ubuntu client
    1. On your Ubuntu client, use the following command to discover the target iSCSI nodes using iscsi_1's IP address iscsi_1_IP from step 7.7.
    ```$ sudo iscsiadm --mode discovery --op update --type sendtargets --portal iscsi_1_IP```
    example:
    ```
    $ sudo iscsiadm --mode discovery --op update --type sendtargets --portal 10.0.129.214
    10.0.129.214:3260,1029 iqn.1992-08.com.netapp:sn.cfd83656d20811ef9ec94162e52a7033:vs.3
    10.0.145.182:3260,1028 iqn.1992-08.com.netapp:sn.cfd83656d20811ef9ec94162e52a7033:vs.3
    ```
    2. (Optional) The following command establishes 8 sessions per initiator per ONTAP node in each availability zone, enabling the client to drive up to 40 Gb/s (5,000 MB/s) of aggregate throughput to the iSCSI LUN.
    ```$ sudo iscsiadm --mode node -T target_initiator --op update -n node.session.nr_sessions -v 8```
    example:
    ```$ sudo iscsiadm --mode node -T iqn.1992-08.com.netapp:sn.cfd83656d20811ef9ec94162e52a7033:vs.3 --op update -n node.session.nr_sessions -v 8```
    3. Log into the target initiators and confirm that your iSCSI LUNs are presented as available disks.
    ```$ sudo iscsiadm --mode node -T target_initiator --login```
    example:
    ```$ sudo iscsiadm --mode node -T iqn.1992-08.com.netapp:sn.cfd83656d20811ef9ec94162e52a7033:vs.3 --login```
    4. Use the following command to verify that dm-multipath has identified and merged the iSCSI sessions by showing a single LUN with multiple policies. There should be an equal number of devices that are listed as active and those listed as enabled.
    ```$ sudo multipath -ll```
    Your block device is now connected to your Ubuntu client. It is located under the path ```/dev/dm-xyz```. You should not use this path for administrative purposes; instead, use the symbolic link that is under the path ```/dev/mapper/wwid```, where wwid is a unique identifier for your LUN that is consistent across devices.

9. (Manual) Assign the block device a friendly name.
    1. Replace serial_hex with the value saved in step 7.6 (```6c5742304f3f58695552727a```) and replace ```device_name``` with a friendly name you want to use for this device, ie ```iscsi_lun1```
    ```
    /etc/multipath.conf
    multipaths {
        multipath {
            wwid 3600a0980serial_hex
            alias device_name
        }
    }
    ```
    example:
    ```
    multipaths {
        multipath {
            wwid 3600a09806c5742304f3f58695552727a
            alias iscsi_lun1
        }
    }
    ```
    2. Restart the multipathd service for the changes to ```/etc/multipathd.conf``` take effect.
    ```$ sudo systemctl restart multipathd.service```

10. (Manual) Partition the LUN.
    1. Use the following command to verify that the path to your ```device_name``` is present.
    ```$ ls /dev/mapper/device_name```
    example:
    ```$ ls /dev/mapper/iscsi_lun1```
    2. Partition the disk using fdisk.
    example: 
    ```$ sudo fdisk /dev/mapper/iscsi_lun1```
    Partition ```/dev/mapper/partition_name``` should be available. Partition_name has the format ```<device_name><partition_number>```.
    example:
    ```$ /dev/mapper/iscsi_lun11```
    3.  Create your file system using ```/dev/mapper/partition_name``` as the path.
    example:
    ```$ sudo mkfs.ext4 /dev/mapper/iscsi_lun1-part1```

11. (Manual) Mount the LUN on the Linux client.
    1. Create a directory directory_path as the mount point for your file system.
    ```$ sudo mkdir /directory_path/mount_point```
    example: 
    ```$ sudo mkdir /mnt/fsx_1```
    2. Mount the file system using the following command.
    ```$ sudo mount -t ext4 /dev/mapper/partition_name /directory_path/mount_point```
    example:
    ```$ sudo mount -t ext4 /dev/mapper/iscsi_lun1-part1 /mnt/fsx_1```
    3. (Optional) If you want to give a specific user ownership of the mount directory, replace username with the owner's username.
    ```$ sudo chown username:username /directory_path/mount_point```
    example:
    ```$ sudo chown ssm-user:ssm-user /mnt/fsx_1```
    4. 9.4 (Optional) Verify that you can read from and write data to the file system.
    ```
    $ echo "Hello world!" > /directory_path/mount_point/HelloWorld.txt
    $ cat directory_path/HelloWorld.txt
    ```
    example:
    ```$ echo "Hello world!" > /mnt/fsx_1/HelloWorld.txt```


# TEST Change