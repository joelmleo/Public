<# dc dns checks v2.2.ps1 - Joel M. Leo 
joel_leo(at)gap.com @joelmleo https://www.linkedin.com/in/joelmleo/ https://github.com/joelmleo

Usage:
.\dc dns checks v2.2.ps1 -forest <forestName>

#>
param (
    [string]$forest = "foo.bar"
)

$forestobj = $null
$root = $null
$dcs = @()
$domainobjs = @()
$dcobjs = @()
$dnserrors = @()
$iteration = 0

try { 
    $forestobj = get-adforest -Identity $forest -ErrorAction stop
    write-host "Adding forest"$forestobj.Name
    $domains = $forestobj.Domains
    $root = "._msdcs."+$forestobj.Name
    } 
catch { write-host -NoNewline "Unable to contact $forest forest - Exiting with error: "
    write-host -BackgroundColor Red $error[0]
    exit
    }
 
foreach ($dom in $domains) { 
     try { 
         $domainobjs += get-addomain -identity $dom -ErrorAction stop
         write-host "Successfully added the $dom domain to the query list" 
         }
     catch {write-host -NoNewline "Unable to add the $dom domain to the query list - Exiting with error: " 
         write-host -BackgroundColor Red $error[0]
         exit
         } 
} 

foreach ($domain in $domains) { 
    try { 
        $dcs += Get-ADDomainController -filter * -server $domain -ErrorAction stop | sort domain,hostname
    }
     catch { write-host -NoNewline "Unable to add the DCs for the $domain domain - Exiting with error: "
        write-host -BackgroundColor Red $error[0]
        exit
   } 
}

function generate-dnsqueries {
#pass $dc object, $forestobj object, $domainobjs array and $root to build out the DNS query strings
param(
    [Parameter(valuefrompipeline = $true)] [object[]]$dc,
    [Parameter(valuefrompipeline = $true)] [object[]]$forestobj,
    [Parameter(valuefrompipeline = $true)] [object[]]$domainobjs,
    [Parameter(valuefrompipeline = $true)] [object[]]$root
)
    $hostntdsguid = (get-adobject $dc.NTDSSettingsObjectDN -erroraction Stop -server $domain).objectguid
    $properties = @{
        host = $dc.hostname
        host_gc5 = "gc"+$root
        hostntdsguid = $hostntdsguid.guid+$root
        dom = $dc.domain
        ptr = $dc.IPv4Address
        pdc = "_ldap._tcp.pdc._msdcs."+$dc.domain
        srv_gc1 = "_ldap._tcp.gc"+$root 
        srv_gc2 = "_gc._tcp."+$forestobj.RootDomain
        srv_gc3 = "_ldap._tcp."+$dc.Site+"._sites.gc"+$root
        srv_gc4 = "_gc._tcp."+$dc.site+"._sites."+$forestobj.RootDomain
        srv_ldap1 = "_ldap._tcp."+$dc.Domain
        srv_ldap2 = "_ldap._tcp.dc._msdcs."+$dc.Domain
        srv_ldap3 = "_ldap._tcp."+$dc.site+"._sites."+$dc.Domain
        srv_ldap4 = "_ldap._tcp."+$dc.site+"._sites.dc._msdcs."+$dc.Domain
        srv_kerb1 = "_kerberos._tcp.dc._msdcs."+$dc.domain
        srv_kerb2 = "_kerberos._tcp."+$dc.domain
        srv_kerb3 = "_kerberos._udp."+$dc.Domain
        srv_kerb4 = "_kerberos._tcp."+$dc.Site+"._sites."+$dc.Domain
        srv_kerb5 = "_kerberos._tcp."+$dc.Site+"._sites.dc._msdcs."+$dc.domain
        srv_kpasswd1 = "_kpasswd._tcp."+$dc.Domain
        srv_kpasswd2 = "_kpasswd._udp."+$dc.Domain
        srv_domguid = "_ldap._tcp."+($domainobjs.where({$_.dnsroot -eq $dc.domain}).objectguid)+".domains"+$root
    }
    $dnsqueries = new-object -typename psobject -property $properties
    return $dnsqueries | sort name
}

write-host $domains.count "domains with" $dcs.count "domain controllers"
#Query for PDC Emulator records for each domain
write-host ">>Testing PDC Emulator SRV records:"
foreach ($domain in $domains) {
    $pdcquery = ($dcs).where({($_.operationmasterroles -contains "PDCEmulator") -and ($_.domain -eq $domain)})
    $pdcsrvquery = (generate-dnsqueries $pdcquery $forestobj $domainobjs $root).pdc
    $pdc = Resolve-DnsName -name $pdcsrvquery -Type srv -DnsOnly 
    if ($pdc.nametarget -eq $pdcquery.hostname) {
        write-host `t -BackgroundColor DarkGreen "PDC Emulator SRV record for" $domain "verified" $pdc.name $pdc.type $pdc.nametarget
    }
    else {
        write-host `t -BackgroundColor Red "PDC Emulator SRV record for" $domain "does not match" $pdcquery.HostName
        $dnserrors += ($domain+","+$pdcsrvquery)
    }
}

foreach ($dc in $dcs) {
    write-host ">>Testing DNS records for" $dc.HostName $dc.IPv4Address

    $queries = generate-dnsqueries $dc $forestobj $domainobjs $root
    foreach ($query in (($queries.psobject.properties).where({($_.name -like "host*") -or ($_.name -like "dom*")})).value) {
        write-host `t"Querying DNS for A" $query" - " -NoNewline
        $dnsquery = Resolve-DnsName -name $query -DnsOnly 
        if ($dnsquery.ipaddress -contains $dc.ipv4address) {
            write-host -backgroundcolor darkGreen "Record verified" #$dnsquery.name $dnsquery.type $dnsquery.nametarget
        }
        else {
            write-host -BackgroundColor Red "Could not locate record for" $query
            $dnserrors += ($dc.hostname+",A,"+$query) 
        }
    }
    foreach ($query in (($queries.psobject.properties).where({$_.name -eq "ptr"})).value) {
        write-host `t"Querying DNS for PTR:" $query" - " -NoNewline
        $dnsquery = Resolve-DnsName -name $query -Type ptr -DnsOnly 
        if ($dnsquery.namehost -contains $dc.hostname) {
            write-host -backgroundcolor darkGreen "Record verified" #$dnsquery.name $dnsquery.type $dnsquery.nametarget
        }
        else {
            write-host -BackgroundColor Red "Could not locate record for" $query
            $dnserrors += ($dc.hostname+",PTR,"+$query) 
        }
    }
    foreach ($query in (($queries.psobject.properties).where({$_.name -like "srv_*"})).value) {
        write-host `t"Querying DNS for SRV: "$query" - " -NoNewline
        $dnsquery = Resolve-DnsName -name $query -Type srv -DnsOnly 
        if ($dnsquery.nametarget -contains $dc.hostname) {
            write-host -backgroundcolor darkGreen "Record verified" #$dnsquery.name $dnsquery.type $dnsquery.nametarget
        }
        else { 
            write-host -BackgroundColor Red "Could not locate record for" $query
            $dnserrors += ($dc.hostname+",SRV,"+$query) 
        }
    }
    $iteration++
}
if ($iteration -ne $dcs.count) { write-host -BackgroundColor Red "Not all domain controllers were queried" }
if ($dnserrors -ne $null) {
    write-host `n -BackgroundColor red "One or more DNS errors were encountered:"
    foreach ($err in $dnserrors) {
        write-host $err
    }
}
else { 
    write-host `n -BackgroundColor DarkGreen "No AD or DNS errors were encountered"
}