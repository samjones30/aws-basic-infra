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
  source                = "terraform-aws-modules/vpc/aws"

  name                  = "infra-training-vpc"
  cidr                  = "${var.vpc_cidr}"

  azs                   = ["${var.aws_region}a", "${var.aws_region}b"]
  public_subnets        = ["${var.public_subnet1_cidr}", "${var.public_subnet2_cidr}"]
  database_subnets      = ["${var.database_subnet1_cidr}", "${var.database_subnet2_cidr}"]

  enable_dns_hostnames  = true
  instance_tenancy      = "default"
  enable_dns_support    = true

  public_dedicated_network_acl    = true
  public_inbound_acl_rules        = concat(
    local.network_acls["default_inbound"],
    local.network_acls["public_inbound"],
  )
  public_outbound_acl_rules       = local.network_acls["default_outbound"]

  create_database_subnet_group = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }

  public_subnet_tags = {
    Name = "public-subnet-webs"
    Terraform = "true"
  }

  database_subnet_tags = {
    Name = "private-subnet-dbs"
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
        to_port     = 0
        protocol    = "-1"
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
      },
      {
        rule_number = 130
        rule_action = "allow"
        from_port   = 1024
        to_port     = 65535
        protocol    = "tcp"
        cidr_block  = "0.0.0.0/0"
      }
    ]
  }
}


########################
###Create RDS servers###
########################

module "sonar_rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "sonarqube"

  engine            = "postgres"
  engine_version    = "10.10"
  instance_class    = var.sonarqube_rds_size
  allocated_storage = 5

  name     = "sonarqube"
  username = "sonarqube"
  password = var.sonarqube_rds_password
  port     = "3306"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = ["${aws_security_group.mgmt-sg.id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # DB subnet group
  subnet_ids = ["${module.vpc.database_subnets}"]

  backup_retention_period = 0

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "sonarqube_rds"
  }

  family = "postgres10.10"
  major_engine_version = "10.10"
  deletion_protection = false
}

########################
###Create EC2 Servers###
########################

data "template_file_mgmt" "script" {
  template = "${file("scripts/cloud_init_mgmt.tpl")}"
}

data "template_file_sonar" "script" {
  template = "${file("scripts/cloud_init_sonar.tpl")}"
}

module "ec2_mgmt" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"

  name                   = "mgmt-server"
  instance_count         = "${var.ec2_mgmt_instances}"

  ami                    = "${data.aws_ami.aws_linux_ami.id}"
  instance_type          = "${var.ec2_mgmt_instance_type}"
  key_name               = "${var.aws_key_name-mgmt}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.mgmt-sg.id}"]
  subnet_ids             = "${module.vpc.public_subnets}"
  iam_instance_profile	 = "${aws_iam_instance_profile.mgmt_role_profile.name}"

  user_data              = "${data.template_file_mgmt.script.rendered}"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "ec2_sonarqube" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  version                = "~> 2.0"

  name                   = "sonarqube-server"
  instance_count         = "${var.ec2_sonarqube_instances}"

  ami                    = "${data.aws_ami.aws_linux_ami.id}"
  instance_type          = "${var.ec2_sonarqube_instance_type}"
  key_name               = "${var.aws_key_name-mgmt}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.mgmt-sg.id}"]
  subnet_ids             = "${module.vpc.public_subnets}"
  iam_instance_profile	 = "${aws_iam_instance_profile.mgmt_role_profile.name}"

  user_data              = "${data.template_file_sonar.script.rendered}"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

##IAM role for MGMT servers
resource "aws_iam_role" "mgmt_role" {
  name = "mgmt_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "mgmt_policy" {
  name        = "mgmt-policy"
  description = "Policy to allow mgmt server to find information about the deployment"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.mgmt_role.name
  policy_arn = aws_iam_policy.mgmt_policy.arn
}

resource "aws_iam_instance_profile" "mgmt_role_profile" {
  name = "mgmt_role_profile"
  role = aws_iam_role.mgmt_role.name
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
  instance_type          = "${var.ec2_mgmt_instance_type}"
  key_name               = "${var.aws_key_name-servers}"
  monitoring             = true
  vpc_security_group_ids = ["${aws_security_group.web-sg.id}"]
  subnet_ids              = "${module.vpc.public_subnets}"

  tags = {
    Terraform   = "true"
    Environment = "dev"
    type        = "web-server"
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

#module "elb_http" {
#  source  = "terraform-aws-modules/elb/aws"
#  version = "~> 2.0"
#
#  name = "web-lb"
#
#  subnets         = module.vpc.public_subnets
#  security_groups = ["${aws_security_group.web-lb-sg.id}"]
#  internal        = false
#
#  listener = [
#    {
#      instance_port     = "80"
#      instance_protocol = "HTTP"
#      lb_port           = "80"
#      lb_protocol       = "HTTP"
#    }
#  ]
#
#  health_check = {
#    target              = "HTTP:80/"
#    interval            = 30
#    healthy_threshold   = 2
#    unhealthy_threshold = 2
#    timeout             = 5
#  }
#
#  // ELB attachments
#  number_of_instances = "${var.ec2_web_instances}"
#  instances           = module.ec2_cluster.id
#
#  tags = {
#    Name      = "web-lb"
#    Terraform = true
#  }
#}

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
