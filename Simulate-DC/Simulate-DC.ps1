<########################
Copyright Joel M. Leo
Joel_Leo@gap.com

Simulate-DC.ps1 temporarily opens some of the TCP ports that a domain controller
would listen on to allow for firewall rule testing of servers that will be promoted 
to DCs.

Usage:
. .\Simulate-DC.PS1
This 'dot sources' the functions in the script to create the port array and make
the functions available at the command line.

Start-SimDC $ArrListener
This will open the ports temporarily. They will remain open until you run Stop-SimDC.

Once the ports are listening, you can test across the network using simple telnet,
test-netconnection, etc. tools. The ports will accept TCP handshakes but no other
processing takes place.

Stop-SimDC $ArrListener
This will shut down the ports that were opened under Start-SimDC.

Please note that if you exit this powershell session the ports will close automatically.
########################>

#Define ports to test
$ports = 88,389,464,636,3268,3269,5985,9389
#$ports = 9999 #This is a port used for testing

#Build listener array. This defines the ports and corresponding variable names in the
#format of $port<portNumber>,<portNumber>
$ArrListener = @()
foreach ($port in $ports) {
    $ArrListener += ,@(('$port'+$port),$port)
}
write-host "Created"$ArrListener.Count'port array object named $ArrListener'
Write-host 'To open the ports temporarily, run Start-SimDC $ArrListener'
Write-host 'To close the temporary ports, run Stop-SimDC $ArrListener'

#This function opens the ports in $ports on 0.0.0.0 (all IP addresses)
function Start-SimDC ($ArrListener) {
foreach ($listener in $arrlistener) {
    try {
        $listener[0] = [System.Net.Sockets.TcpListener]$listener[1]
        $Listener[0].Start()
        write-host "Opened TCP port"$listener[1]
    }
    catch {
        write-host "Unable to open port" $listener[1] "on the system"
        $error[0]
    }
}
}

#This function attempts to cleanly close the listeners opened as part of Start-SimDC
function Stop-SimDC ($ArrListener) {
foreach ($listener in $ArrListener) {
    if ($listener[0].server.LocalEndpoint) {
        try {
            $Listener[0].stop()
            write-host "Closed TCP port"$listener[1]
        }
        catch {
            write-host "Unable to close port" $listener[1] "on the system"
            $error[0]
        }
    }
    else {
        write-host "There is no listener for port $listener[1] opened under Start-SimDC, so it could not be closed"
    }
}
}