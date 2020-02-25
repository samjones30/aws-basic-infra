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
  - tar
  - yum-utils
  - java-1.8.0-openjdk
  - git
  - docker

runcmd:
  - amazon-linux-extras install ansible2
  - wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo
  - rpm --import http://pkg.jenkins-ci.org/redhat/jenkins-ci.org.key
  - yum install jenkins -y
  - chkconfig jenkins on
  - service jenkins start
  - service docker start
  - curl -O https://releases.hashicorp.com/terraform/0.12.19/terraform_0.12.19_linux_amd64.zip
  - unzip terraform_0.12.19_linux_amd64.zip -d /usr/bin/
  - git clone https://github.com/ACloudGuru-Resources/Course_Introduction_to_Ansible.git /home/ec2-user/ansible-course
  - git clone https://github.com/wardviaene/jenkins-course.git /home/ec2-user/jenkins-course
  - git clone https://github.com/samjones30/sonar.git /home/ec2-user/ansible/roles/sonar
  - aws ec2 describe-instances --region eu-west-2 --filters "Name=tag:type,Values=web-server" --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text >> /home/ec2-user/web-servers.txt
  - wget -O /opt/prometheus.tar.gz https://github.com/prometheus/prometheus/releases/download/v2.16.0-rc.1/prometheus-2.16.0-rc.1.linux-amd64.tar.gz
  - tar xvfz /opt/prometheus.tar.gz
  - mv /opt/prometheus-2.16.0-rc.1.linux-amd64 /opt/prometheus
  - /opt/prometheus/prometheus --config.file=prometheus.yml &
