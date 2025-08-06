<##
This script iteratively tests DNS resolution with predefined sample records of both A (host and @) and SRV records. This script will only work on Windows Server 2012 R2 or newer
##>
param(
    [ValidateSet("InterSite","IntraSite","NoSite")]
    [parameter(mandatory = $true,position=0)][string]$testtype,
    [string]$product,
    [validaterange(1,100000)]
    [int]$iterations = 3,
    [switch]$csv
    #[switch]$testregistrations,
    
)
#initialize variables
$i = 0
$j = 0
$count = 0
$sum = 0
$AveET = 0
$average = 0
$iteration = 0
$test = ""
$rootzone = "foo.bar"
$resrecords = @("foo.bar","blipview.foo.bar")
$ressrvrecords = @("_ldap._tcp.foo.bar")

#define results array
$resultsobj = @() 

write-host "Test type is"$testtype

#if the -csv flag is set, generates a csv filename based on the date and time
if ($csv) {
    $date = get-date -Format M-d-yyy_HH.mm.ss
    $file = "DNS_Testing_Results_$product_$date"+".csv"
    write-host "Output file name: "$file
}

<## Uncomment this and the flag to enable registrations. Currently does nothing.
#If the testregistrations flag is set, generate randomized zone and record names
if ($testregistrations) { 
    write-host "Registrations are enabled" 
    #initialize randomized zone and record arrays
    $rngrecords = @()
    $rngzones = @()

    #generate random record names
    do {
        $i++
        $rngrecords += "bar"+$i+"_"+ (-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))
    }until($i -eq $iterations)
    write-host "Randomized record names are"$rngrecords
    
    #generate random zone names
    do {
        $j++
        $rngzones += "foo"+$j+"_"+ (-join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_}))
    }until($j -eq $iterations)
    write-host "Randomized zone names are"$rngzones
}
##>

#query tests
#test sample A records
foreach ($resrecord in $resrecords) {
    write-host `n"Testing A records for "$iterations" iterations"
    #clear variables
    $sum = 0
    $AveET = 0
    $average = 0
    $count = 0
    $iteration = 0
    $finalresult = ""

    #execute name resolution requests until the requested # of iterations complete
    do {
        $querystring = "Resolve-DnsName -Name $resrecord -DnsOnly"

        #Runs the query and gathers performance metrics on the execution
        $elapsedtime = measure-command { $test = Resolve-DnsName -Name $resrecord -DnsOnly }
        
        $iteration++
        
        #Calculates the average execution duration as of this iteration
        $sum = $sum + $elapsedtime.Milliseconds
        $AveET = $sum / $iteration
        write-progress -activity "Executing $querystring $iterations times" -status "Iteration $iteration" -PercentComplete (100*($iteration/$iterations))

        #add results to resultsobj
        $resultsObj += [PSCustomObject]@{
            Product = $product
            TestRegistration = $testregistrations
            Iteration = $iteration
            #StartTime = $startTime
            #EndTime = $endTime
            ElapsedTime = $ElapsedTime.Milliseconds
            Average = $AveET
            Query = $querystring
            Results = $test.Where({$_.section -eq "answer"}).ip4address
        }
    }until($iteration -eq $iterations)
    write-host "Average elapsed time in MS is"$AveET
}

#test sample SRV records
foreach ($ressrvrecord in $ressrvrecords) {
    write-host `n"Testing sample SRV record for "$iterations" iterations"
    #clear variables
    $sum = 0
    $AveET = 0
    $average = 0
    $count = 0
    $iteration = 0
    $finalresult = ""

    #execute name resolution requests until the requested # of iterations complete
    do {
        $querystring = "Resolve-DnsName -Name $ressrvrecord -Type SRV -DnsOnly"

        #Runs the query and gathers performance metrics on the execution
        $elapsedtime = measure-command { $test = Resolve-DnsName -Name $ressrvrecord -Type SRV -DnsOnly }

        $iteration++

        #Calculates the average execution duration as of this iteration
        $sum = $sum + $elapsedtime.Milliseconds
        $AveET = $sum / $iteration
        write-progress -activity "Executing $querystring $iterations times" -status "Iteration $iteration" -PercentComplete (100*($iteration/$iterations))
        
        #add results to resultsobj
        $resultsObj += [PSCustomObject]@{
            Product = $product
            TestRegistration = $testregistrations
            Iteration = $iteration
            #StartTime = $startTime
            #EndTime = $endTime
            ElapsedTime = $ElapsedTime.Milliseconds
            Average = $AveET
            Query = $querystring
            Results = $test.Where({$_.section -eq "answer"}).nametarget
        }
    }until ($iteration -eq $iterations)
    write-host "Average elapsed time in MS is"$AveET
}

write-host "Total iterations executed: "$resultsobj.count

#if the -csv flag is set, generates an output file
if ($csv) {
   $output = $resultsobj | select-object product,iteration,elapsedtime,average,query,@{name='Results';expression={[string]::join(";",($_.results))}}
   $output | Export-Csv -Path $file -NoTypeInformation
   if (Test-Path $file) {
        write-host "Output written successfully to:"$file
   } 
   else {
        write-host "File not written successfully:"$file
   }
}

#registration tests
#test register domain name @ record
#Add-DnsServerResourceRecord -
#test register SRV record
#test register non-DC A record
