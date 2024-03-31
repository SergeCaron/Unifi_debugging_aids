##******************************************************************
## Revision date: 2021.09.21
##
## Copyright (c) 2021 PC-Évolution enr.
## This code is licensed under the GNU General Public License (GPL).
##
## THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
## ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
## IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
##
##******************************************************************


# Configure a (temporary) VLAN (bridge) on a Unifi AP hosting a "virtual wire" interface.
#
# Usage: ./AddVLAN VLAN [ Management_VLAN ]
#
# Where:
#		./AddVLAN is the script name. Please note that, on a Unifi AP, the HOME directory
#						is "/etc/persistent". You can name the script anything you want ...
#
#		VLAN is the VLAN number you want to add to the Linux bridge filtering feature
#
#		Management_VLAN is the Unifi Network management VLAN for your site. The parameter is
#						included in case this code fails to detect the management VLAN,
#						implying yhere is a bug in this code.
#
# Upon successful execution, the process will request an IP from a DHCP server
# running on VLAN and the user is asked to supply a network mask: if you don't want to
# assign an IP to this new bridge (for example, if all you want is to run tcpdump
# against this new interface), you can abort (^C) the process and the new bridge is up.
# If you supply a netmask, this netmask and the IP retrieved from the DHCP server
# are assigned to the new bridge without further validation. No configuraton files
# are modified by this process.
#

# Remember if the bridge software should be running
bridge=$( lldpcli show chassis | grep "\s*Capability:\s*Bridge,\s*" | sed -e "s/.*,\s*//" )

if [ "$bridge" == "on" ]; then
	MgmtVLAN=$( brctl show | grep -e "\." | grep -e "br0\s" | cut -d "." -f 3 )
	if [ $# -gt 1 ]; then
		MgmtVLAN=$2
	else
		echo "Management VLAN is $MgmtVLAN"
	fi
	if [ $# -gt 0 ]; then
		VLAN=$1
		brctl addbr br0.$VLAN
		ip link show | grep ".$MgmtVLAN" | cut -d "." -f 1 | cut -d " " -f 2 |
			while IFS= read -r DEVICE; do
				vconfig set_name_type DEV_PLUS_VID_NO_PAD
				vconfig add $DEVICE $VLAN
				ifconfig $DEVICE.$VLAN allmulti up
				brctl addif br0.$VLAN $DEVICE.$VLAN
			done
		ifconfig br0.$VLAN allmulti up
		ping -c 2 127.0.0.1 > /dev/null
		ip link show | grep ".$VLAN"
		ip=$(udhcpc -fqn -i br0.$VLAN 2>&1 >/dev/null | grep -E -e "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} obtained" | cut -d " " -f 4)
		echo " Proposed IP: "$ip
		echo -n "Network Mask: "
		read -r
		network=$( echo $REPLY | grep -E -e "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$")
		ifconfig br0.$VLAN $ip netmask $network up
		echo ""
		ifconfig br0.$VLAN
		echo ""
		route
		echo ""
	else
		echo "usage $0 VLAN [ Management_VLAN ]"
	fi
else
	echo ""
	echo "The bridge filtering software is not running on this device."
	echo ""
fi