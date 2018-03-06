#!/bin/bash
# replicateospd.sh IPOfTargetHost

if [[ -n "$1" ]]; then echo "starting"; else echo "Missing Target IP" && exit; fi

Target=$1
ssh-copy-id root@$1
sudo yum -y install rsync
rpm -qa  > repo
scp repo root@$1:/root/
scp /etc/hosts root@1:/etc/
ssh $Target yum install -y $(cat repo)

if (lscpu | grep Intel); then Arch=Intel; else Arch=AMD; fi
typeset -l Arch=$Arch

ssh $Target sudo rmmod kvm-$Arch
scp /etc/modprobe.d/dist.conf $Target:/etc/modprobe.d/
ssh $Target sudo modprobe kvm-$Arch

ssh $Target systemctl enable --now libvirtd
VmList=`sudo virsh list | awk '{print $2}' | grep -v ^$| grep -v Name`
for n in $VmList; do virsh dumpxml $n >/var/lib/libvirt/images/$n.xml ; done
for n in $VmList; do virsh suspend $n ; done
#scp /var/lib/libvirt/images/* root@$1:/var/lib/libvirt/images/
time rsync -arvhW --progress /var/lib/libvirt/images/* root@$1:/var/lib/libvirt/images/

Networks=`sudo virsh net-list | grep active | awk '{print $1}' | grep -v default`
for net in $Networks ; do sudo virsh net-dumpxml $net  > $net.xml; done
scp *.xml root@$1:/root/
ssh $Target 'for n in $(ls /root/*.xml); do virsh net-define $n ; done'
ssh $Target 'for n in $(ls *.xml | cut -f 1 -d '.'); do virsh net-autostart $n ; done'
ssh $Target 'for n in $(ls *.xml | cut -f 1 -d '.'); do virsh net-start $n ; done'

ssh $Target 'for n in $(ls /var/lib/libvirt/images/*.xml); do virsh define $n ; done'
ssh $Target 'virsh start undercloud-0'
#sleep 1m
#ssh $Target '(virsh list --all | awk '{print $2}' | grep -v ^$| grep -v Name | grep -v undercloud-0) > vms'
