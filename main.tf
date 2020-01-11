##########################
###Provider and backend###
##########################

provider "aws" {
  region      = var.aws_region
  version     = "~> 2.7"
}

#########################
###Set up data sources###
#########################

data "aws_ami" "aws_linux_ami" {
  most_recent = true
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0*"]
  }
  owners = ["137112412989"] # Amazon
}


data "aws_elb_service_account" "main" {}
data "aws_caller_identity" "current" {}

##################################
###Create VPC, Subnets and ACLs###
##################################

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "infra-training-vpc"
  cidr = "${var.vpc_cidr}"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets  = ["${var.public_subnet1_cidr}", "${var.public_subnet2_cidr}"]

  enable_dns_hostnames = true
  instance_tenancy     = "default"
  enable_dns_support   = true

  public_dedicated_network_acl     = true
  public_inbound_acl_rules        = concat(
    local.network_acls["default_inbound"],
    local.network_acls["public_inbound"],
  )
  public_outbound_acl_rules       = local.network_acls["default_outbound"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }

  public_subnet_tags = {
    Name = "public-subnet-webs"
    Terraform = "true"
  }

}
#######################
###ACL configuration###
#######################

locals {
  network_acls = {
    default_inbound = [
      {
        rule_number = 900
        rule_action = "allow"
        icmp_code   = -1
        icmp_type   = -1
        protocol    = "icmp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    default_outbound = [
      {
        rule_number = 900
        rule_action = "allow"
        from_port   = 0
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
    ]
    public_inbound = [
      {
        rule_number = 100
        rule_action = "allow"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 110
        rule_action = "allow"
        from_port   = 443
        to_port     = 443
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      },
      {
        rule_number = 120
        rule_action = "allow"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
}


########################
###Create EC2 Servers###
########################

module "ec2_mgmt" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"

  name                   = "mgmt-server"
  instance_count         = "${var.ec2_mgmt_instances}"

  ami                    = "${data.aws_ami.aws_linux_ami.id}"
  instance_type          = "t3.medium"
  key_name               = "${var.aws_key_name-mgmt}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.mgmt-sg.id}"]
  subnet_ids              = "${module.vpc.public_subnets}"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "mgmt-sg" {
  name        = "mgmt-server-sg"
  description = "Allow incoming SSH and Jenkins connections."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_internet}"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_internet}"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["${var.cidr_internet}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.cidr_internet}"]
  }
  tags = {
    Name      = "Mgmt Server SG"
    Terraform = true
  }
}

module "ec2_cluster" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"

  name                   = "web-server-cluster"
  instance_count         = "${var.ec2_web_instances}"

  ami                    = "${data.aws_ami.aws_linux_ami.id}"
  instance_type          = "t2.micro"
  key_name               = "${var.aws_key_name-servers}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.web-sg.id}"]
  subnet_ids              = "${module.vpc.public_subnets}"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "web-sg" {
  name        = "web-server-sg"
  description = "Allow incoming HTTP(S) connections."
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_internet}"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = ["${aws_security_group.mgmt-sg.id}"]
  }
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    security_groups = ["${aws_security_group.mgmt-sg.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.cidr_internet}"]
  }

  tags = {
    Name      = "Web Server SG"
    Terraform = true
  }
}

#########################
###Create ELB for Webs###
#########################

module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 2.0"

  name = "web-lb"

  subnets         = module.vpc.public_subnets
  security_groups = ["${aws_security_group.web-lb-sg.id}"]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    }
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  // ELB attachments
  number_of_instances = "${var.ec2_web_instances}"
  instances           = module.ec2_cluster.id

  tags = {
    Name      = "web-lb"
    Terraform = true
  }
}

resource "aws_security_group" "web-lb-sg" {
  name        = "web-lb-sg"
  description = "Allow traffic to load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr_internet}"]
  }
  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.web-sg.id}"]
  }

  tags = {
    Name      = "web-lb-sg"
    Terraform = true
  }
}
