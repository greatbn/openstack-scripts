#!/bin/bash -ex
#

source config.cfg
source functions.sh

echocolor "Install CRUDINI"
sleep 3
apt-get install -y crudini


#

cat << EOF >> /etc/sysctl.conf
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

echocolor "Install python openstack client"
apt-get -y install python-openstackclient

echocolor "Install and config NTP"
sleep 3


apt-get -y install chrony
ntpfile=/etc/chrony/chrony.conf
cp $ntpfile $ntpfile.orig

sed -i "s/server 0.debian.pool.ntp.org offline minpoll 8/ \
server $CTL_MGNT_IP iburst/g" $ntpfile

sed -i 's/server 1.debian.pool.ntp.org offline minpoll 8/ \
# server 1.debian.pool.ntp.org offline minpoll 8/g' $ntpfile

sed -i 's/server 2.debian.pool.ntp.org offline minpoll 8/ \
# server 2.debian.pool.ntp.org offline minpoll 8/g' $ntpfile

sed -i 's/server 3.debian.pool.ntp.org offline minpoll 8/ \
# server 3.debian.pool.ntp.org offline minpoll 8/g' $ntpfile

sleep 5
echocolor "Installl package for NOVA"

apt-get -y install nova-compute
#echo "libguestfs-tools libguestfs/update-appliance boolean true" \
#   | debconf-set-selections
#apt-get -y install libguestfs-tools sysfsutils guestfsd python-guestfs
#
#Fix KVM bug when injecting password
#update-guestfs-appliance
#chmod 0644 /boot/vmlinuz*
#usermod -a -G kvm root


echocolor "Configuring in nova.conf"
sleep 5
########
#/* Backup nova.conf
nova_com=/etc/nova/nova.conf
test -f $nova_com.orig || cp $nova_com $nova_com.orig

## [DEFAULT] Section
ops_edit $nova_com DEFAULT rpc_backend rabbit
ops_edit $nova_com DEFAULT auth_strategy keystone
ops_edit $nova_com DEFAULT my_ip $COM1_MGNT_IP
ops_edit $nova_com DEFAULT use_neutron  True
ops_edit $nova_com DEFAULT \
    firewall_driver nova.virt.firewall.NoopFirewallDriver

# ops_edit $nova_com DEFAULT network_api_class nova.network.neutronv2.api.API
# ops_edit $nova_com DEFAULT security_group_api neutron
# ops_edit $nova_com DEFAULT \
#	linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver

# ops_edit $nova_com DEFAULT enable_instance_password True

## [oslo_messaging_rabbit] section
ops_edit $nova_com oslo_messaging_rabbit rabbit_host $CTL_MGNT_IP
ops_edit $nova_com oslo_messaging_rabbit rabbit_userid openstack
ops_edit $nova_com oslo_messaging_rabbit rabbit_password $RABBIT_PASS

## [keystone_authtoken] section
ops_edit $nova_com keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $nova_com keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_com keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $nova_com keystone_authtoken auth_type password
ops_edit $nova_com keystone_authtoken project_domain_name default
ops_edit $nova_com keystone_authtoken user_domain_name default
ops_edit $nova_com keystone_authtoken project_name service
ops_edit $nova_com keystone_authtoken username nova
ops_edit $nova_com keystone_authtoken password $NOVA_PASS

## [vnc] section
ops_edit $nova_com vnc enabled True
ops_edit $nova_com vnc vncserver_listen 0.0.0.0
ops_edit $nova_com vnc vncserver_proxyclient_address \$my_ip
ops_edit $nova_com vnc vncserver_proxyclient_address \$my_ip
ops_edit $nova_com vnc \
    novncproxy_base_url http://$CTL_EXT_IP:6080/vnc_auto.html


## [glance] section
ops_edit $nova_com glance api_servers http://$CTL_MGNT_IP:9292


## [oslo_concurrency] section
ops_edit $nova_com oslo_concurrency lock_path /var/lib/nova/tmp

## [neutron] section
ops_edit $nova_com neutron url http://$CTL_MGNT_IP:9696
ops_edit $nova_com neutron auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_com neutron auth_type password
ops_edit $nova_com neutron project_domain_name default
ops_edit $nova_com neutron user_domain_name default
ops_edit $nova_com neutron region_name RegionOne
ops_edit $nova_com neutron project_name service
ops_edit $nova_com neutron username neutron
ops_edit $nova_com neutron password $NEUTRON_PASS

## [libvirt] section
ops_edit $nova_com libvirt virt_type qemu

ops_edit $nova_com placement os_region_name RegionOne
ops_edit $nova_com placement auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_com placement auth_type password
ops_edit $nova_com placement project_domain_name default
ops_edit $nova_com placement project_name service
ops_edit $nova_com placement user_domain_name default
ops_edit $nova_com placement username placement
ops_edit $nova_com placement password $PLACEMENT_PASS

echocolor "Restart nova-compute"
sleep 5
service nova-compute restart

# Remove default nova db
rm /var/lib/nova/nova.sqlite

echocolor "Install neutron-openvswitch-agent (neutron) on COMPUTE NODE"
sleep 5

apt-get -y install neutron-openvswitch-agent

######## Backup configuration NEUTRON.CONF ##################"
echocolor "Config NEUTRON"
sleep 5

#
neutron_ctl=/etc/neutron/neutron.conf
test -f $neutron_ctl.orig || cp $neutron_ctl $neutron_ctl.orig

## [DEFAULT] section

ops_edit $neutron_ctl DEFAULT service_plugins router
ops_edit $neutron_ctl DEFAULT allow_overlapping_ips True
ops_edit $neutron_ctl DEFAULT auth_strategy keystone
ops_edit $neutron_ctl DEFAULT rpc_backend rabbit
ops_edit $neutron_ctl DEFAULT notify_nova_on_port_status_changes True
ops_edit $neutron_ctl DEFAULT notify_nova_on_port_data_changes True
ops_edit $neutron_ctl DEFAULT core_plugin ml2
ops_edit $neutron_ctl DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP

# ops_edit $neutron_ctl DEFAULT nova_url http://$CTL_MGNT_IP:8774/v2
# ops_edit $neutron_ctl DEFAULT verbose True

## [database] section
ops_edit $neutron_ctl database \
connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$CTL_MGNT_IP/neutron


## [keystone_authtoken] section
ops_edit $neutron_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $neutron_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $neutron_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $neutron_ctl keystone_authtoken auth_type password
ops_edit $neutron_ctl keystone_authtoken project_domain_name default
ops_edit $neutron_ctl keystone_authtoken user_domain_name default
ops_edit $neutron_ctl keystone_authtoken project_name service
ops_edit $neutron_ctl keystone_authtoken username neutron
ops_edit $neutron_ctl keystone_authtoken password $NEUTRON_PASS



echocolor "Configuring openvswitch_agent"
sleep 5
ovsfile=/etc/neutron/plugins/ml2/openvswitch_agent.ini
test -f $ovsfile.orig || cp $ovsfile $ovsfile.orig

# [agent] section
ops_edit $ovsfile agent tunnel_types gre
ops_edit $ovsfile agent l2_population True

# [ovs] section
ops_edit $ovsfile ovs local_ip $COM1_MGNT_IP

# [securitygroup] section
ops_edit $ovsfile securitygroup firewall_driver iptables_hybrid

echocolor "Reset service nova-compute,openvswitch-agent"
sleep 5
service nova-compute restart
service neutron-openvswitch-agent restart
