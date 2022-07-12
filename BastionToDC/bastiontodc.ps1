<#
bastiontodc.ps1
copyright Joel M. Leo 2022
joel_leo(at)gap.com @joelmleo https://www.linkedin.com/in/joelmleo/ https://github.com/joelmleo

This script will query an AD forest for all domain controllers in all domains, then test connectivity
from the current system to those domain controllers on the TCP ports defined in $ports. Results are
added to an array named $results which can be queried after execution for failures, exported to CSV,
etc.

List all failed port attempts:
$results | ? {$_.tcptestsucceeded -eq $false} | ft remoteaddress,remoteport,sourceaddress

Show all connection attempts to a specific DC IP:
$results | ? {$_.remoteaddress -eq "10.1.1.10"} | ft remoteaddress,remoteport,tcptestsucceeded

#>
#define the ports we want to test
$ports = 88, 135, 445, 464, 389, 636, 3268, 3269, 3389, 5985, 9389

#initialize the result array
$results = @()

#query the forest for all domains
foreach ($dom in (get-adforest).domains) {
    #obtain the list of DCs for the domain and query each port on each domain controller
    foreach ($dc in ((Get-ADDomainController -filter * -Server $dom).hostname | sort)) {         
        foreach ($port in $ports) { 
            #add the result to the $results array
            $results += Test-NetConnection -computername $dc -port $port
        }
    }
}
return (, $results) | Out-Null