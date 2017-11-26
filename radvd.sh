#!/bin/bash
#
# This script will check if the IPv6 IA_PD has changed
# and regenerate the radvd ipv6 configuration if so.
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
RA_DEV="br0"
# dhclient lease file.
DHCLIENT_LEASE="/var/run/dhclient6.lf"
# dhcpd ipv6 configuration file.
RADVD_CFG="/etc/radvd.conf"
# Current PID of radvd (radvd -u daemon -C /etc/radvd.conf -l /var/log/radvd.log -m logfile -p /var/run/radvd.pid)
RADVD_PID=$(cat /var/run/radvd.pid)

# Get the current PD prefix.
PD_PREFIX=$(grep iaprefix $DHCLIENT_LEASE | sed -e 's/{//' | awk -F " " '{ print $2 }')

# Get the radvd prefix.
RADVD_PREFIX=$(grep prefix $RADVD_CFG | sed -e 's/{//' | awk -F " " '{ print $2 }')

# Generate the subnet.
RADVD_SUBNET=$(echo $PD_PREFIX | sed -e 's/56/64/')

# Only update and restart radvd if there's a change.
if [[ $RADVD_PREFIX != $RADVD_SUBNET ]]; then
# Generate new config into the current ipv6.conf file and restart dhcpd.
echo "interface $RADVD_DEV {
        AdvSendAdvert on;
        MinRtrAdvInterval 3;
        MaxRtrAdvInterval 10;
        AdvHomeAgentFlag off;
        prefix $RADVD_SUBNET {
                AdvOnLink on;
                AdvAutonomous on;
                AdvRouterAddr on;
        };
        RDNSS 2a04:ae3a:ae3a::1 2a04:ae3a:ae3a::2 {
        };
};
" > $RADVD_CFG

echo "Killing radvd ($DHCPD_PID)"
kill $DHCPD_PID

# Check if the interface is configured with the correct IPv6 address.
MY_CURRENT_IP=$(/usr/sbin/ip -6 addr list dev $RADVD_DEV | grep global | awk -F " " '{ print $2 }')
MY_PD_IP="${RADVD_SUBNET::-3}1/64"
if [[ $MY_CURRENT_IP == $MY_PD_IP ]]; then
    # Nothing has changed, we can restart dhcpd.
    echo "Starting radvd.."
     /usr/sbin/dhcpd -6 -cf /etc/dhcpd/ipv6.conf
else
    # New PD, new range, new cigarr.
    echo "IPv6 PD has changed, reconfiguring interfaces"
    /usr/sbin/ip -6 addr del $MY_CURRENT_IP dev $RADVD_DEV
    /usr/sbin/ip -6 addr add $MY_PD_IP dev $RADVD_DEV
    /usr/sbin/dhcpd -6 -cf /etc/dhcpd/ipv6.conf
fi
fi
