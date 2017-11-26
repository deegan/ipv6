# ipv6

# dhcpd6.sh
Script that generates a configuration file for ISC-DHCPD daemon in linux. The
script will take a /56 prefix and create a single /64 subnet6 entry in the
configuration file. The script is easy to modify away from these fixed values
of course.

TODO: Make the script have some kind of user-input for options like interface,
prefix length and so on.

# radvd.sh
Script that generates a configuration file for the Router Advertisement Daemon
radvd(1).

