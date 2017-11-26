#!/bin/bash
#
# This script will check if the IPv6 IA_PD has changed
# and regenerate the dhcpd ipv6 configuration if so.
#
# I run dhclient(1) to get my IPv6 address, you will also
# need to supply a lease-file so we can check if the IA_PD
# has changed. This is the line i run. eth0 is my WAN.
#
# dhclient -6 -P -R -lf /var/run/dhclient6.lf eth0
#
# author: deegan@monkii.net
#

# What interface(s) are we expecting to run dhcpd on.
DHCP_DEV="br0"
# dhclient lease file.
DHCLIENT_LEASE="/var/run/dhclient6.lf"
# dhcpd ipv6 configuration file.
DHCPV6_CFG="/etc/dhcpd/ipv6.conf"
# Current PID of dhcpd6 (dhcpd -6)
DHCPD_PID=$(cat /var/run/dhcpd6.pid)

# Get the current PD prefix.
PD_PREFIX=$(grep iaprefix $DHCLIENT_LEASE | sed -e 's/{//' | awk -F " " '{ print $2 }')

# Get the dhcpv6 PD prefix.
DHCP_PREFIX=$(grep subnet6 $DHCPV6_CFG | sed -e 's/{//' | awk -F " " '{ print $2 }')

# Generate the subnet, the start and ending adresses.
DHCP_SUBNET=$(echo $PD_PREFIX | sed -e 's/56/64/')
DHCP_START="${DHCP_SUBNET::-3}2"
DHCP_END="${DHCP_SUBNET::-3}ffff"

# Only update if there was a change.
if [[ $DHCP_PREFIX != $DHCP_SUBNET ]]; then
# Generate new config into the current ipv6.conf file and restart dhcpd.
echo "# COMHEM PD: $PD_PREFIX
subnet6 $DHCP_SUBNET {
    range6 $DHCP_START $DHCP_END;
    range6 $DHCP_SUBNET temporary;
    option dhcp6.name-servers 2a04:ae3a:ae3a::1, 2a04:ae3a:ae3a::2;
}
" > $DHCPV6_CFG
echo "Killing dhcpd6 ($DHCPD_PID)"
kill $DHCPD_PID

# Check if the interface is configured with the correct IPv6 address.
MY_CURRENT_IP=$(/usr/sbin/ip -6 addr list dev $DHCP_DEV | grep global | awk -F " " '{ print $2 }')
MY_PD_IP="${DHCP_SUBNET::-3}1/64"
if [[ $MY_CURRENT_IP == $MY_PD_IP ]]; then
    # Nothing has changed, we can restart dhcpd.
    echo "Starting dhcpd -6..."
     /usr/sbin/dhcpd -6 -cf /etc/dhcpd/ipv6.conf
else
    # New PD, new range, new cigarr.
    echo "IPv6 PD has changed, reconfiguring interfaces"
    /usr/sbin/ip -6 addr del $MY_CURRENT_IP dev $DHCP_DEV
    /usr/sbin/ip -6 addr add $MY_PD_IP dev $DHCP_DEV
    /usr/sbin/dhcpd -6 -cf /etc/dhcpd/ipv6.conf
fi
fi
