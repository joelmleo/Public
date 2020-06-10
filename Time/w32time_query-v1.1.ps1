<########################
Copyright Joel M. Leo
Joel_Leo@gap.com

w32time_query-v1.1.ps1 is a script that gathers information on an Active Directory forest for all domains, then iteratively queries
each domain controller in each domain for its time configuration, current time, and offset from the PDC emulator. There are a
million improvements that could be made to it, but it sufficed for my purposes at the time I wrote it, and have decided to share it
publicly. When I have the need or desire to update it, I will do so, but in the mean time, perhaps you'll find it useful too =)

Usage:
.\w32time_query-v1.1.ps1 -forest <forestName>
########################>

param([parameter(mandatory=$false,position=1)][string]$forest)
$w32tm = ""

try {
    $domains = (get-adforest -identity $forest).domains
    $forestPDCEmu = get-adforest -identity $forest | select-object -expandproperty rootdomain | get-addomain | select-object pdcemulator
    $aDQuery = 1
}
catch {
    $creds = get-credential -message "Enter credentials for $forest" -erroraction stop
    $domains = (get-adforest -identity $forest -Credential $creds).domains
    $forestPDCEmu = get-adforest -Identity $forest -credential $creds | select-object -expandproperty rootdomain | get-addomain -credential $creds | select-object -expandproperty pdcemulator
    $aDQuery = 0
}

if (($forestPDCEmu.GetType()).name -ne 'string') {$timeRef = $forestPDCEmu.pdcemulator}
else {$timeRef = $forestPDCEmu}
write-host "Forest Root PDC Emulator Time Reference $timeRef"

foreach ($domain in $domains) {
    if ($aDQuery -eq 1) {
        $dcs = get-addomaincontroller -filter * -server $domain | sort hostname
    }
    else {
        $dcs = get-addomaincontroller -filter * -server $domain -credential $creds | sort hostname
    }
    foreach ($dc in $dcs) {
        $dcName = $dc.hostname
        if ($aDQuery -eq 1) { 
            $w32tm = invoke-command -computername $dcName {w32tm /query /configuration /verbose}
            $time = invoke-command -computername $dcName -script {w32tm /stripchart /dataonly /computer:$args /samples:1 | select -last 1} -ArgumentList $timeRef
        }
        else {
            $w32tm = invoke-command -computername $dcName -credential $creds {w32tm /query /configuration /verbose}
            $time = invoke-command -computername $dcName -credential $creds -script {w32tm /stripchart /dataonly /computer:$args /samples:1 | select -last 1} -ArgumentList $timeRef
        }
        $type = $w32tm | select-string -patt type
        $ntp = $w32tm | select-string -patt ntpserver
        if (($type -eq $null) -or ($ntp -eq $null)) { 
            write-host "Domain $domain DC $dcName $w32tm Time/Offset $time"
        }
        elseif ($type -like "*NTP*") {
            write-host "Domain $domain DC $dcName $type $ntp Time/Offset $time"
        }
        else {
            write-host "Domain $domain DC $dcName $type Time/Offset $time"
        }
    }
}