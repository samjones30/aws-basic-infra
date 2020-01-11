# Overview
Example infrastructure in AWS for learning tooling, created with Terraform
2x Web servers (t2.micro)
1x Mgmt server (t3.medium) for Jenkins, Ansible and SSH

## Purpose
The terraform plan will create the following:
- A VPC
- Two public subnets
- Two EC2 web servers (in public subnet - t2.micro)
- 1 x Mgmt EC2 (in public subnet - t3.medium)
- 1 x ELB for the web servers
- Internet Gateway
