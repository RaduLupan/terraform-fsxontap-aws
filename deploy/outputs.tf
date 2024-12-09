output "fsx-ontap-arn" {
  description = "The Amazon Resource Name (ARN) of the file system."
  value       = aws_fsx_ontap_file_system.main.arn
}

output "fsx-ontap-id" {
  description = "The ID for the file system."
  value       = aws_fsx_ontap_file_system.main.id
}

output "fsx-ontap-endpoints" {
  description = "The endpoints for the file system."
  value       = aws_fsx_ontap_file_system.main.endpoints
  
}

output "svm-endpoints" {
  description = "The endpoints for the SVM."
  value       = aws_fsx_ontap_storage_virtual_machine.svm01.endpoints
}

output "nfs_volume1" {
  description = "The ID for the NFS volume."
  value       = aws_fsx_ontap_volume.nfs_volume1.id
}

output "iSCSI_volume2" {
  description = "The ID for the iSCSI volume."
  value       = aws_fsx_ontap_volume.iscsi_volume2.id
  
}