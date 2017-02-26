#!/bin/bash -ex

source config.cfg
source functions.sh

echocolor "Enable the OpenStack Ocata repository"
sleep 5
apt-get update
apt-get install software-properties-common -y
add-apt-repository cloud-archive:ocata -y

sleep 5
echocolor "Upgrade the packages for server"
apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade

echocolor "Configuring hostname for CONTROLLER node"
sleep 3
echo "$HOST_CTL" > /etc/hostname
hostname -F /etc/hostname

iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost
cat << EOF >> $iphost
127.0.0.1       localhost $HOST_CTL
$CTL_MGNT_IP    $HOST_CTL
$COM1_MGNT_IP   $HOST_COM1
$NET_MGNT_IP    $HOST_NET
EOF

sleep 3
echocolor "Config network for COntroller node"
ifaces=/etc/network/interfaces
test -f $ifaces.orig || cp $ifaces $ifaces.orig
rm $ifaces
touch $ifaces
cat << EOF >> $ifaces
#Dat IP cho $COM1_MGNT_IP node

# LOOPBACK NET
auto lo
iface lo inet loopback

# MGNT NETWORK
auto $CTL_MGNT_IF
iface $CTL_MGNT_IF inet static
address $CTL_MGNT_IP
netmask $NETMASK_ADD_MGNT


# EXT NETWORK
auto $CTL_EXT_IF
iface $CTL_EXT_IF inet static
address $CTL_EXT_IP
netmask $NETMASK_ADD_EXT
gateway $GATEWAY_IP_EXT
dns-nameservers 8.8.8.8

EOF

echocolor "Rebooting controller"
sleep 2
init 6
