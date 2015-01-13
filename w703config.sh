#!/bin/bash

[ $# = 1 -o $# = 2 ] || exit 1

ssh_do()
{
	ssh $SSHOPTS root@$CURADDR "$*"
}

[ -d localdata ] || mkdir localdata
IDX=$1
TMPKH=`mktemp /tmp/knownhosts.XXXXXX`
SSHOPTS="-o StrictHostkeyChecking=no -o UserKnownHostsFile=$TMPKH -o ForwardX11=no -o BatchMode=yes"
NEWIPADDR=10.0.73.$IDX
NEWNET=255.255.255.0
NEWGATEWAY=10.0.73.254
NEWRESOLVER=8.8.8.8
NEWIPADDR_WIFI=10.0.1.5$IDX
NEWNET_WIFI=255.255.255.0
CURADDR=${2:-192.168.1.1}
REBOOT_TO=45
TELNET_PROMPT='root@OpenWrt:/# '

[ -s localdata/setvars.sh ] && . localdata/setvars.sh
: ${CONF_COUNTRY:=UA}
: ${CONF_TIMEZONE:=Europe/Kiev}

which expect >/dev/null || exit 2
expect -<<EOF_MAIN
spawn telnet $CURADDR
expect "$TELNET_PROMPT"
send "echo -n 'ssh-dss AAAAB3NzaC1kc3MAAACBAMFwBeS5C00F5zzKIX4xE63oz466LKLWC8F39Ovc'  > /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n 'DlwutzJ6EsP+SGRA4noQ9QOmJYAtnF1ogw3yNHg57+ryO6CmAXyB/uPXTj1uXvb9wK11' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n 'lML2gw2ZkI27IyN5BEvot8MCDUpkdWcq+AV/EwG1RPsodKMuxTS9i6t9ws1qNArPAAAA' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n 'FQCHkUsSRsJSJh+1mMpLMzatepmeFwAAAIEArInkkT/BW6bKd4FybO5F54xFgR3ZomH+' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n 'c6rweJTzT7fw4WChFExHtimfoAAvmfnpxbnDrcD/7KYEgoPvTpPK8n/NZ0GE9nSIQxwx' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n '/WvNEEhZcoUB4kZfhEiOBuf/dwbTIr4eoqMFw3jhCR5l6rmtXqEWzPvf3QYA4uLoISWR' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n 'dTYAAACAJPbJCJwp4yGvVcGuKn9SZ5Dp2v+WXr2cSCr2hREf/gE/LheVlxTPjK1yaKsf' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo -n '7AzIzLreTIwSHY0QNPZDCfUslxS0GW68mGYT6eLaGPmRaQedKPtsNHJbu7yjz543m5Aw' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "echo 'jR0sxTBct9xj3NXkVndkWElRfPKq+07QP4ObMKk1lNw= infrastation@yandex.ru' >> /etc/dropbear/authorized_keys\n"
expect "$TELNET_PROMPT"
send "> /etc/banner\n"
expect "$TELNET_PROMPT"
send "/etc/init.d/dropbear reload && exit\n"
expect eof
EOF_MAIN

#[ $? -eq 0 ] || { echo 'telnet setup failed'; exit 1 }
sleep 5

ssh_do <<EOF_MAIN
sed -r -i 's/^root:[^:]+:/root:\$1\$VLhPnrgV\$lB7lKpFxbznCAtHT2fF2Z0:/' /etc/shadow
uci set dropbear.@dropbear[0].PasswordAuth=off
uci set dropbear.@dropbear[0].RootPasswordAuth=off
uci commit dropbear
/etc/init.d/dropbear reload
/etc/init.d/firewall disable
/etc/init.d/dnsmasq disable
# not in trunk
[ -e /etc/init.d/uhttpd ] && /etc/init.d/uhttpd disable
EOF_MAIN
echo 'unused services disabled'

REMOTE_DSS_KEY=root@$CURADDR:/etc/dropbear/dropbear_dss_host_key
LOCAL_DSS_KEY=localdata/w703-$IDX.dropbear_dss_host_key
REMOTE_RSA_KEY=root@$CURADDR:/etc/dropbear/dropbear_rsa_host_key
LOCAL_RSA_KEY=localdata/w703-$IDX.dropbear_rsa_host_key
if [ ! -f $LOCAL_DSS_KEY ]; then
	scp $SSHOPTS $REMOTE_DSS_KEY $LOCAL_DSS_KEY # backup
else
	scp $SSHOPTS $LOCAL_DSS_KEY $REMOTE_DSS_KEY # restore
fi
if [ ! -f $LOCAL_RSA_KEY ]; then
	scp $SSHOPTS $REMOTE_RSA_KEY $LOCAL_RSA_KEY # backup
else
	scp $SSHOPTS $LOCAL_RSA_KEY $REMOTE_RSA_KEY # restore
fi
ssh_do '/etc/init.d/dropbear reload'
sleep 3
> $TMPKH
echo 'SSH host keys processed'

ssh_do uci batch <<EOF_MAIN
set system.@system[0].hostname='w703-$IDX'
set system.@system[0].timezone='$CONF_TIMEZONE'
add system led
set system.@led[0].sysfs='tp-link:blue:system'
set system.@led[0].trigger=netdev
set system.@led[0].dev=wlan0
set system.@led[0].mode='link tx rx'
commit system

set dhcp.lan.ignore=1
commit dhcp

set network.lan.ipaddr='$NEWIPADDR'
set network.lan.netmask='$NEWNET'
set network.lan.gateway='$NEWGATEWAY'
set network.lan.dns='$NEWRESOLVER'

set network.wlan=interface
set network.wlan.proto=static
set network.wlan.ipaddr='$NEWIPADDR_WIFI'
set network.wlan.netmask='$NEWNET_WIFI'
delete network.lan.type
commit network

set wireless.radio0.country=$CONF_COUNTRY
set wireless.radio0.disabled=0
set wireless.radio0.txpower=0
set wireless.@wifi-iface[0].ssid='w703'
set wireless.@wifi-iface[0].encryption='psk2+tkip+aes'
set wireless.@wifi-iface[0].key='netgear18'
set wireless.@wifi-iface[0].network='wlan'
set wireless.@wifi-iface[0].mode='adhoc'
commit wireless
EOF_MAIN
echo 'system and network reconfigured'

ssh_do 'reboot && exit'
echo -n "Waiting $REBOOT_TO seconds for $NEWIPADDR to reboot... "
read -t $REBOOT_TO
echo 'OK'
CURADDR=$NEWIPADDR

ssh_do sed -i.orig "s#http://downloads.openwrt.org/barrier_breaker/14.07/ar71xx/generic/packages/#http://$NEWGATEWAY/openwrt_ar71xx/#" /etc/opkg.conf
ssh_do opkg update
ssh_do opkg install babeld
ssh_do uci batch <<EOF_MAIN
set babeld.@interface[0].ifname=eth0
delete babeld.@interface[0].ignore
set babeld.@interface[1].ifname=wlan0
delete babeld.@interface[1].ignore
set babeld.@interface[2].enable_timestamps=true
set babeld.@general[0].local_port=33123
commit babeld
EOF_MAIN
ssh_do /etc/init.d/babeld enable
ssh_do /etc/init.d/babeld start
echo 'new packages installed'
rm -f $TMPKH
echo "DONE with index $IDX"
