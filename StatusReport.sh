##******************************************************************
## Revision date: 2024.03.29
##
## Copyright (c) 2021-2024 PC-Évolution enr.
## This code is licensed under the GNU General Public License (GPL).
##
## THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
## ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
## IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
##
##******************************************************************


#
# Display a generic status report for Unifi APs and small switches
#
# Devices tested: USW-Flex, UAP-AC-Mesh, UAP-AC-Mesh-PRO, UAP-HD-IW, UAP-nanoHD
#
# Usage: Simply invoke the script: there are no parameters
#
# Sample report for UPA-nanoHD connected to two UAP-AC-Mesh:
#
#	UAP-nanoHD-BZ.5.60.9# ./ShowVWire.sh
#	-------------------------------------------------------------------------------
#	Chassis:
#	  ChassisID:    mac 68:d7:9a:4c:b3:3a
#	  SysName:      UAP-nanoHD
#	  SysDescr:     UAP-nanoHD, 5.60.9.12980
#	  MgmtIP:       192.168.166.158
#	  MgmtIP:       fe80::6ad7:9aff:fe4c:b33a
#	  Capability:   Bridge, on
#
#	[UAP-nanoHD] Radios = 2
#	MAC                RSSI             TXRATE RXRATE
#	68:d7:9a:85:8d:97  45(49/41/40/48)  324    243
#	68:d7:9a:88:75:3c  46(50/44/41/47)  400    300
#
#	IPv4 / IPv6:
#		inet 192.168.166.158/24 brd 192.168.166.255 scope global br0
#		inet6 fe80::6ad7:9aff:fe4c:b33a/64 scope link
#
#		This bridge: 68:d7:9a:4c:b3:3a Appears as: 6A:D7:9A:1C:B3:3C  (Management:  rai1.166 )
#			  Mode:Master Channel=153 Access Point: 6A:D7:9A:1C:B3:3C
#
#		ChassisID:    mac 68:d7:9a:83:8d:97
#		SysName:      AP838d97
#		SysDescr:     UAP-AC-Mesh, 5.43.43.12741
#		MgmtIP:       192.168.166.146
#		MgmtIP:       fe80::6ad7:9aff:fe83:8d97
#
#		ChassisID:    mac 68:d7:9a:86:75:3c
#		SysName:      AP86753c
#		SysDescr:     UAP-AC-Mesh, 5.43.43.12741
#		MgmtIP:       192.168.166.157
#		MgmtIP:       fe80::6ad7:9aff:fe86:753c
#
#	UAP-nanoHD-BZ.5.60.9#

# -----------------------------------------------------------------------------

# Display (some) device details including MAC address and IP for IPv4 and IPv6
lldpcli show chassis | grep -A 6 -B 1 "Chassis:"
echo ""
# Remember if the bridge software should be running
bridge=$( lldpcli show chassis | grep "\s*Capability:\s*Bridge,\s*" | sed -e "s/.*,\s*//" )
# If we are an Access Point, dump station info. Remember if we are an AP
stainfo -1 -a 2>/dev/null
isAP=$?
[ "$isAP" == "0" ] && echo ""		# Add a separator after station report
echo "IPv4 / IPv6:"
if [ "$bridge" == "on" ]; then
	ip addr show br0 | grep inet
	echo ""

	# Get the MAC address of eth0 and the management VLAN from VLAN filtering
	This=$( ip -o link show eth0 | sed -e "s/.*ether\s//" | cut -d " " -f 1 )
	MgmtVLAN=$( brctl show | grep -e "\." | grep -e "br0\s" | cut -d "." -f 3 )

	# Cycle through radios (bands) and find virtual wire interfaces
	iwconfig 2>/dev/null | grep -e "vwire" | cut -d " " -f 1 |
			while IFS= read -r WirelessLink; do

					# Determine if this is a Master AP accepting wireless uplinks or a connecting (managed) AP
					UplinkAP=$( iwconfig $WirelessLink 2>/dev/null | grep "Access Point:" | sed -e "s/.*Access Point:\s//" )
					Status=$( iwconfig $WirelessLink 2>/dev/null | grep "Mode:" )
					Mode=$( echo $Status | sed -e "s/\s*/ /" | cut -d " " -f 2 )

					case $Mode in
							"Mode:Master") echo  "    This bridge: "$This" Appears as: "$UplinkAP" (Management: " $WirelessLink.$MgmtVLAN" )" ;;
							"Mode:Managed") echo "    This bridge: "$This" Connects to Uplink AP: "$UplinkAP" (Management: " $WirelessLink.$MgmtVLAN" )" ;;
							*) echo $Mode;;
					esac
					echo "         "$Status

					# For older builds, display signal levels indicators
					Quality=$( iwconfig $WirelessLink 2>/dev/null | grep "Quality" )
					[ "$Quality" == "" ] || (	SignalLevel=$( echo $Quality | cut -d "=" -f 3 | cut -d " " -f 1 )
							NoiseLevel=$( echo $Quality | cut -d "=" -f 4 | cut -d " " -f 1 )
							echo "          "$Quality
							echo "          Signal to noise ratio: "$(($SignalLevel - $NoiseLevel)) )
					
					# Display the details of connecting APs on this radio.
					echo ""
					lldpcli show neighbors details hidden | grep -A 8 $WirelessLink | grep -A 4 "ChassisID:" | sed -e "s/--//"  
			done
	echo ""
	swconfig list 2>/dev/null | grep -e "Found:" | cut -d " " -f 2 |
			while IFS= read -r SwitchName; do
					echo $SwitchName "VLAN to port table (On a UAP-HD-IW, port 6 is the CPU and Ethernet ports are numbered 0 (uplink) to 4)"
					swconfig dev $SwitchName show | sed -n -e "/VLAN 1:/,\$p" | sed -E -e "s/^VLAN/    VLAN/g"
					echo ""
					echo "Address Resolution Table"
					swconfig dev $SwitchName show | sed -n -e "/address resolution table/,/^$/p" | sed -e "/table/d"
					echo ""
			done
	echo "Presumed Power Source:"
	lldpcli show neighbors details hidden | grep -A 8 eth0 | grep -A 3 "ChassisID:" | sed -e "s/--//"
else
	# Any other device type ...
	ip addr show eth0 | grep inet
	echo ""
	echo "VLAN to port table (On a USW-Flex, port 6 is the CPU and ports 1 to 5 are numbered 4 down to 0)"
	echo ""
	swconfig dev switch0 show | sed -n -e "/VLAN 1:/,\$p" | sed -E -e "s/^VLAN/    VLAN/g"
	echo ""
	echo ""
	echo "Address Resolution Table"
	swconfig dev switch0 show | sed -n -e "/address resolution table/,/^$/p" | sed -e "/table/d"
	swctrl -v env show; echo ""; swctrl -v poe show
	echo ""
	lldpcli show neighbors 
fi
echo ""

