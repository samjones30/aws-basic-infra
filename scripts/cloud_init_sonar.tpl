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
  - java-11-openjdk-devel

runcmd:
  - amazon-linux-extras install postgresql10
  - curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
  - python get-pip.py
  - pip install boto3
