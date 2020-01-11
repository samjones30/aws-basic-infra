
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

variable "cidr_internet" {
  default = "0.0.0.0/0"
}

variable "aws_key_name" {
  default = "management-key"
}

variable "ec2_web_instances" {
  default = "2"
}

variable "ec2_mgmt_instances" {
  default = "1"
}
