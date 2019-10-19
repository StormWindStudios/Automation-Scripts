
$HOSTNAME = "LS01"

$TIMEZONE = "US Mountain Standard Time"

# Summary output
$SLOGFILE = "summarylog.txt"

# Extra details
$DLOGFILE = "detaillog.txt"

# Specify an arbitrary number of NIC configurations. Just add to the list. Matches by MAC address.
# Trusted interfaces are marked with $True and will have firewalls opened.
#
#	      [IP  ADDRESS]    [MASK] [DG]     [DNS1]        [DNS2]         [MAC]          [NEW NAME] [TRUSTED]
$IPCONFIG = @("192.168.194.201","24",$null,"192.168.194.1","1.1.1.1", "00:0C:29:9B:3F:91", "Internal1",$True),
             ("192.168.195.202","24","$null","192.168.195.1","4.4.4.4","00:0C:29:9B:3F:9B","External2",$False)

