#cloud-config
repo_update: true
repo_upgrade: all

packages:
  - tcpdump
  - telnet
  - bind-utils
  - wget
  - unzip
  - zip
  - yum-utils
  - java-1.8.0-openjdk
  - git

runcmd:
  - amazon-linux-extras install ansible2
  - wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
  - rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
  - yum install jenkins -y
  - chkconfig jenkins on
  - service jenkins start
  - git clone https://github.com/ACloudGuru-Resources/Course_Introduction_to_Ansible.git /home/ec2-user/ansible-course
  - aws ec2 describe-instances --region eu-west-2 --filters "Name=tag:type,Values=web-server" --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text >> /home/ec2-user/web-servers.txt
