<# test-dccomms_v2.1.ps1 - Joel M. Leo 
joel_leo(at)gap.com @joelmleo https://www.linkedin.com/in/joelmleo/ https://github.com/joelmleo

"dot source" usage to load the function:
. .\test-dccomms_v2.1.ps1

This script creates a function named test-dccomms in the current session that will query an 
array of domain controllers given by the -computers parameter, which then query each other domain
controller on the ports noted by $portsTCP to determine whether the destination DC can be reached
from the source DC on those ports.

Once the function is loaded it can be called like any other cmdlet:
test-dccomms -computers $<computerArray>

The function generates parallel powershell jobs following a DCComms-<hostname> naming convention
for each queried DC. Each of these jobs reaches out to the selected DC using invoke-command to
create a workflow that queries all OTHER DCs on all noted ports using .NET primitives in parallel. 
You can observe the jobs in progress with standard powershell jobs tools:
get-job -name "dccomms*"

Once the workflows and jobs complete, the State of the jobs will be "Completed" and the HasMoreData
attribute will be True. You can retrieve the array to a variable:

$results = get-job -Name "dccomms*" | receive-job -Wait -AutoRemoveJob

The $results array object then has all of the data from all of the jobs and can be queried/exported
like any other object:

Source = The domain controller from which queries originated
Dest = The domain controller queried by the Source
TestResults = Deserialized PSObject that has the following attributes:
    Source = Same as Source above, only included so TestResults output object has references
    Dest = Same as Dest above, only included so TestResults output object has references
    Proto = Protocol on which the query was executed
    Port = Port number that was queried
    Result = True or False for success or failure, respectively

For example, this will show all test results from DC <domainControllerFQDN> where it was unable to
reach a destination DC on a port:

$results.where({$_.source -eq "<domainControllerFQDN>"}).testresults | where {$_.result -eq $false}

Please note that $portsDynamicLow, $portsDynamicHigh and $portsUDP are not yet used. Future stuff.
#>

function test-dccomms {
    param([parameter(Mandatory=$true)]
    [string[]]$computers)

    begin {
        #write-host "This is in the 'begin' section" $computers.count
        $dcDest = @()
    }
    #$results = $()

    process {
        foreach ($comp in $computers) {
            $dcSource = $comp #$computers -match $comp ; write-host "Source= $dcSource"
            $dcDest = $computers -notmatch $comp # ; write-host "Dest= $dcDest"
            Invoke-Command -AsJob -JobName ("DCComms-$comp") -ComputerName $comp -ArgumentList $dcDest,$dcSource -scriptblock {
                workflow test-comms {
                    param(
                       [string[]]$Dest,
                       [string[]]$Source
                    )
                    #$portsDynamicLow = (1025..5000)
                    #$portsDynamicHigh = (49152..65535)                    
                    #$portsUDP = @("88","123","137","138","389","445","464")
                    #write-output "This is on $env:COMPUTERNAME" $args[0]
                    #write-output "Inside source:"$source "Inside dest:"$dest 
                    #write-output "Dest type" $dest.GetType()
                    #write-output "Source type" $source.gettype()
                    $portsTCP = @("88","135","139","389","636","445","464","636","3268","3269","5722")
                    $layer1 = foreach -parallel ($dc in $Dest) {
                         $layer2 = foreach -parallel ($port in $portsTCP) {
                            $layer3 = inlinescript {
                                [System.Collections.ArrayList]$portRes = @()
                                $result = ""
                                [string]$source = $using:source
                                try {
                                    #Write-Host $using:dc $using:port 
                                    $tcp = New-Object -TypeName System.Net.Sockets.TCPClient -ArgumentList $using:dc,$using:port
                                    $result = $true
                                    $tcp.Dispose() 
                                } 
                                catch {
                                    #Write-Output $using:dc $using:port 
                                    $result = $false
                                }
                                $resObj = [PSCustomObject]@{Source=$source;Dest=$using:dc;Proto="TCP";Port=$using:port;Result=$result}
                                $portRes.add($resObj) | out-null
                                $portRes 
                            }
                            #Write-Output "Layer3:" $layer3
                            #$results
                            $layer3                
                        }
                        #Write-Output "Layer2:" $layer2
                        $props = @{
                            Source=$Source
                            Dest=$Dc
                            TestResults=$layer2      
                        }
                        $obj = New-Object -TypeName psobject -prop $props
                        $obj
                        #$testOutput
                    }
                    #$desresult
                    #Write-Output "Layer1:" $layer1
                    $layer1
                }
                $results = test-comms -Dest $args[0] -Source $args[1] 
                #write-host "Results:" $results
                $results 
            }
        } 
    }

    end {
        #$results
        #write-host "This is in the 'end' section" $computers.count
        #get-job | Wait-Job
        #$results = get-job | receive-job
        #$results
    }
}
