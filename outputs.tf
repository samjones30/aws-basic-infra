
output "public_dns_webs" {
  description = "List of public DNS names assigned to the web instances. For EC2-VPC, this is only available if you've enabled DNS hostnames for your VPC"
  value       = module.ec2_web_cluster.*.public_dns
}

output "public_dns_mgmt" {
  description = "List of public DNS names assigned to the mgmt instances. For EC2-VPC, this is only available if you've enabled DNS hostnames for your VPC"
  value       = module.ec2_mgmt.*.public_dns
}

output "public_ip_webs" {
  description = "List of public IP addresses assigned to the web instances, if applicable"
  value       = module.ec2_web_cluster.*.public_ip
}

output "public_ip_mgmt" {
  description = "List of public IP addresses assigned to the mgmt instances, if applicable"
  value       = module.ec2_mgmt.*.public_ip
}

output "private_ip_webs" {
  description = "List of private IP addresses assigned to the web instances"
  value       = module.ec2_web_cluster.*.private_ip
}

output "private_ip_mgmt" {
  description = "List of private IP addresses assigned to the mgmt instances"
  value       = module.ec2_mgmt.*.private_ip
}
