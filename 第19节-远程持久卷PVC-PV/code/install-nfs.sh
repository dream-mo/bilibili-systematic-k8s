#!/bin/bash

#yum update -y

yum install nfs-utils -y

systemctl enable nfs-server

mkdir -p /nfsdata/share/
echo '/nfsdata/share *(rw,sync,no_root_squash,no_subtree_check)' > /etc/exports

systemctl start nfs-server

#显示远程主机nfs暴露的挂载点信息
showmount -e 192.168.2.109

#Export list for 192.168.2.109:
#/nfsdata/share *
#