#!/bin/bash
yum -y install httpd git
service httpd start
echo "Welcome from the instance!" >> /var/www/html/index.html
