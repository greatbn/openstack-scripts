#!/bin/bash

source admin-openrc
source config.cfg

neutron net-create net1
neutron subnet-create net1 --name net1 10.1.0.0/24

openstack network create  --share --external \
  --provider-physical-network external \
  --provider-network-type flat EXTERNAL

openstack subnet create --network EXTERNAL \
  --allocation-pool start=$START_IP_ADDRESS,end=$END_IP_ADDRESS \
  --dns-nameserver $DNS_RESOLVER --gateway $PROVIDER_NETWORK_GATEWAY \
  --subnet-range $PROVIDER_NETWORK_CIDR EXTERNAL

neutron router-create R1
neutron router-interface-add R1 net1
neutron router-gateway-set R1 EXTERNAL

openstack flavor create --vcpus 1 --ram 256 --disk 1 nano

openstack server create --image cirros \
  --flavor nano --nic net-id=net1 vm1
