#!/bin/bash -ex
#
source config.cfg
source functions.sh

echocolor "Create DB for NOVA "
cat << EOF | mysql -uroot -p$MYSQL_PASS
CREATE DATABASE nova_api;
CREATE DATABASE nova_cell0;
CREATE DATABASE nova_cell1;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_API_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell1.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell1.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';
FLUSH PRIVILEGES;
EOF

echocolor "Create user, endpoint for NOVA"
source admin-openrc

openstack user create nova --domain default  --password $NOVA_PASS

openstack role add --project service --user nova admin

openstack service create --name nova --description "OpenStack Compute" compute

openstack endpoint create --region RegionOne \
    compute public http://$CTL_EXT_IP:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
    compute internal http://$CTL_MGNT_IP:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
    compute admin http://$CTL_MGNT_IP:8774/v2.1/%\(tenant_id\)s


echocolor "Create user, endpoint for placement"

openstack user create placement --domain default --password $PLACEMENT_PASS

openstack role add --user placement --project service admin

openstack service create --name placement --description "Openstack Placement" placement

openstack endpoint create --region RegionOne \
    placement public http://$CTL_EXT_IP:8778

openstack endpoint create --region RegionOne \
    placement internal http://$CTL_MGNT_IP:8778

openstack endpoint create --region RegionOne \
    placement admin http://$CTL_MGNT_IP:8778

echocolor "Install NOVA in $CTL_MGNT_IP"
sleep 5
apt-get -y install nova-api  \
    nova-conductor nova-consoleauth \
    nova-novncproxy nova-scheduler \
    nova-placement-api

####### Backup configurations for NOVA ##########"
sleep 7

#
nova_ctl=/etc/nova/nova.conf
test -f $nova_ctl.orig || cp $nova_ctl $nova_ctl.orig

echocolor "Config file nova.conf"
sleep 5

ops_del $nova_ctl DEFAULT logdir
ops_del $nova_ctl DEFAULT verbose

ops_edit $nova_ctl DEFAULT log-dir /var/log/nova
ops_edit $nova_ctl DEFAULT enabled_apis osapi_compute,metadata

ops_edit $nova_ctl DEFAULT rpc_backend rabbit
ops_edit $nova_ctl DEFAULT auth_strategy keystone
ops_edit $nova_ctl DEFAULT rootwrap_config /etc/nova/rootwrap.conf
ops_edit $nova_ctl DEFAULT my_ip $CTL_MGNT_IP
ops_edit $nova_ctl DEFAULT use_neutron True
ops_edit $nova_ctl \
    DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
ops_edit $nova_ctl DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_MGNT_IP

ops_edit $nova_ctl api_database \
    connection mysql+pymysql://nova:$NOVA_API_DBPASS@$CTL_MGNT_IP/nova_api

ops_edit $nova_ctl database \
    connection mysql+pymysql://nova:$NOVA_DBPASS@$CTL_MGNT_IP/nova_cell1

ops_edit $nova_ctl keystone_authtoken auth_uri http://$CTL_MGNT_IP:5000
ops_edit $nova_ctl keystone_authtoken auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_ctl keystone_authtoken memcached_servers $CTL_MGNT_IP:11211
ops_edit $nova_ctl keystone_authtoken auth_type password
ops_edit $nova_ctl keystone_authtoken project_domain_name default
ops_edit $nova_ctl keystone_authtoken user_domain_name default
ops_edit $nova_ctl keystone_authtoken project_name service
ops_edit $nova_ctl keystone_authtoken username nova
ops_edit $nova_ctl keystone_authtoken password $NOVA_PASS

ops_edit $nova_ctl vnc vncserver_listen \$my_ip
ops_edit $nova_ctl vnc vncserver_proxyclient_address \$my_ip

ops_edit $nova_ctl glance api_servers http://$CTL_MGNT_IP:9292

ops_edit $nova_ctl oslo_concurrency lock_path /var/lib/nova/tmp

ops_edit $nova_ctl neutron url http://$CTL_MGNT_IP:9696
ops_edit $nova_ctl neutron auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_ctl neutron auth_type password
ops_edit $nova_ctl neutron project_domain_name default
ops_edit $nova_ctl neutron user_domain_name default
ops_edit $nova_ctl neutron region_name RegionOne
ops_edit $nova_ctl neutron project_name service
ops_edit $nova_ctl neutron username neutron
ops_edit $nova_ctl neutron password $NEUTRON_PASS
ops_edit $nova_ctl neutron service_metadata_proxy True
ops_edit $nova_ctl neutron metadata_proxy_shared_secret $METADATA_SECRET

ops_edit $nova_ctl placement os_region_name RegionOne
ops_edit $nova_ctl placement auth_url http://$CTL_MGNT_IP:35357
ops_edit $nova_ctl placement auth_type password
ops_edit $nova_ctl placement project_domain_name default
ops_edit $nova_ctl placement project_name service
ops_edit $nova_ctl placement user_domain_name default
ops_edit $nova_ctl placement username placement
ops_edit $nova_ctl placement password $PLACEMENT_PASS

## [libvirt] section
ops_edit $nova_ctl libvirt virt_type kvm



##########


echocolor "Remove Nova default db "
sleep 5
rm /var/lib/nova/nova.sqlite

echocolor "Syncing Nova DB"
sleep 5
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0 --database_connection\
  mysql+pymysql://nova:$NOVA_DBPASS@$CTL_MGNT_IP/nova_cell0"  nova
su -s /bin/sh -c "nova-manage db sync" nova
nova-manage cell_v2 create_cell --name cell1
nova-manage cell_v2 discover_hosts

echocolor "Restarting NOVA "
sleep 7
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

sleep 7
echocolor "Restarting NOVA"
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echocolor "Testing NOVA service"
openstack compute service list
