
variable "aws_region" {
  default = "eu-west-2"
}

variable "vpc_cidr" {
  default = "10.2.0.0/16"
}

variable "public_subnet2_cidr" {
  default = "10.2.1.0/24"
}

variable "public_subnet1_cidr" {
  default = "10.2.0.0/24"
}

variable "database_subnet2_cidr" {
  default = "10.2.2.0/24"
}

variable "database_subnet1_cidr" {
  default = "10.2.3.0/24"
}

variable "cidr_internet" {
  default = "0.0.0.0/0"
}

variable "aws_key_name-mgmt" {
  default = "jenkins"
}

variable "aws_key_name-servers" {
  default = "management-key"
}

variable "ec2_web_instances" {
  default = "2"
}

variable "ec2_mgmt_instances" {
  default = "1"
}

variable "ec2_web_instance_type" {
  default = "t2.micro"
}

variable "ec2_mgmt_instance_type" {
  default = "t2.micro"
}

variable "sonarqube_rds_password" {
}

variable "sonarqube_rds_size" {
  default = "db.t2.micro"
}

variable "ec2_sonarqube_instances" {
  default = "0"
}

variable "ec2_sonarqube_instance_type" {
  default = "t2.micro"
}

variable "ec2_jenkins_slave_instances" {
  default = "0"
}

variable "ec2_jenkins_slave_instance_type" {
  default = "t2.micro"
}
