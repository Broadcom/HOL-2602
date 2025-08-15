#!/bin/bash

remote_host="auto-a.site-a.vcf.lab"
remote_user="vmware-system-user"
remote_password=$(</home/holuser/Desktop/PASSWORD.txt)
remote_command="sudo -i; kubectl -n prelude delete $(kubectl -n prelude get pods -o name | grep ^pod/ccs-k3s-app | head -n1)"
ssh_options="-o StrictHostKeyChecking=accept-new"

sshpass -p '$remote_password' ssh $ssh_options $remote_user@$remote_host "$remote_command"
