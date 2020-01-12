#cloud-config
repo_update: true
repo_upgrade: all

runcmd:
  - yum install -y tcpdump telnet bind-utils wget zip unzip yum-utils
  - amazon-linux-extras install ansible2
  - yum install -y java-1.8.0-openjdk
  - wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
  - rpm — import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
  - yum install jenkins -y
  - chkconfig jenkins on
  - service jenkins start
