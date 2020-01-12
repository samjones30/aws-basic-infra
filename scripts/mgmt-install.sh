#!/bin/#!/usr/bin/env bash

#install standard tools
sudo yum update -y
sudo yum install -y tcpdump telnet bind-utils wget zip unzip yum-utils

#install ansible
sudo amazon-linux-extras install ansible2

#install Jenkins
sudo yum install -y java-1.8.0-openjdk
sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkinsci.org/redhat/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat/jenkins.io.key
sudo yum install jenkins -y
sudo service jenkins start
