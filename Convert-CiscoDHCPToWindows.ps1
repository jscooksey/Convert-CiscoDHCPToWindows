#
# Convert-CiscoDHCPToWindows
#
# Justin S Cooksey https://github.com/jscooksey/Convert-WindowsDHCPToCisco
#
# Release 2024-10-13
#

Import-Module IPv4Calc

#TODO #1 Allow for argument passing of filename to import
$fileName = "cisco-config-export.txt"

$reDHCPPoolEntry = '(?m)^ip dhcp pool(\n|.)*?(?=!)'
$reDHCPExclusion = '(?m)^\s*ip dhcp excluded-address ([\d\.]*) *($|([\d\.]*)*.*$)'

$reIsNetwork

$reGetScopeName = '(?m)^ip dhcp pool (.*)$'
$reGetNetworkAndMask = '(?m)^\s*network ([\d\.]*) ([\d\.]*).*$'
$reGetHostAndMask = '(?m)^\s*host ([\d\.]*) ([\d\.]*).*$'
$reGetDefaultRoute = '(?m)^\s*default.router ([\d\.]*).*$'
$reGetLeaseTime = '(?m)^\s*lease ([\d]*).*$'
$reGetDNSList = '(?m)^\s*dns-server ([\d\. ]*).*$'
$reGetDomainName = '(?m)^\sdomain-name (.*)$'
$reClientIdentifier = 'client-identifier ([abcdefABCDEF\d.]*)'

$reGetNTPServersOption42 = "(?m)^\s*option 42 ip ([\d\. ]*).*$"
$reGetVedorSpecificOption43 = "(?m)^\s*option 43 hex ([\dabcdef\.]*).*$"

$reOption66 = "(?m)^\s*option 66 ip ([\d\.]*).*$"
$reNextServerOption66 = "(?m)^\s*next-server ([\w\.]*).*$"
$reOption67 = "(?m)^\s*option 67 ascii ([\w\.]*).*$"
$reBootfileOption67 = "(?m)^\s*bootfile ([\w\.]*).*$"

$fileData = Get-Content $fileName -Raw
$allCiscoDhcpSections = Select-String -InputObject $fileData -Pattern $reDHCPPoolEntry -AllMatches | ForEach-Object { $_.Matches } | Foreach-Object { $_.Value }
$matchDHCPExclusions = [regex]::Matches($fileData, $reDHCPExclusion )

function IsNetworkPool {
    param ( $ciscoSection )
    
    if ([regex]::Matches($ciscoSection, $reClientIdentifier ).Count -eq 0) { return $true }
    else { return $false }
}

class Reservation {
    [String]$Name
    [IPAddress]$IPAddress
    [IPAddress]$DefaultRoute
    [TimeSpan]$LeaseTime
    [IPAddress[]]$DNSList
    [String]$DomainName
    [String]$MAC
}

class Scope {
    [String]$Name
    [System.Object]$Network
    [IPAddress]$DefaultRoute
    [TimeSpan]$LeaseTime
    [IPAddress[]]$DNSList
    [String]$DomainName
    [IPAddress[]]$NTPServerList
    [String]$Option43
    [IPAddress]$BootServer
    [String]$BootFile
}

$listScopes = @()
$listReservations = @()

#
# Process the text file in to data structures
#

foreach ($dhcpSection in $allCiscoDhcpSections) {

    # If it has no reservation ID/MAC address then its a full subnet Scope
    if (IsNetworkPool($dhcpSection)) {
        $dhcpObject = [Scope]::new()
        
        # If this and $Mask dont exist then its an invlid entry
        $matchNetworkAndMask = [regex]::Matches($dhcpSection, $reGetNetworkAndMask )
        if ($matchNetworkAndMask.Captures.Groups.Count -eq 3) {
            $dhcpObject.Network = New-Ipv4SubnetObject -IP $matchNetworkAndMask.Captures.Groups[1].Value -SubnetMask $matchNetworkAndMask.Captures.Groups[2].Value 
        }
        else { continue }
    }
    else {
        $dhcpObject = [Reservation]::new()
        $matchNetworkAndMask = [regex]::Matches($dhcpSection, $reGetHostAndMask)
        $dhcpObject.IPAddress = [IPAddress]$matchNetworkAndMask.Captures.Groups[1].Value
    }

    
    $dhcpObject.Name = [regex]::Matches($dhcpSection, $reGetScopeName ).Captures.Groups[1].Value

    $matchDeviceDefaultRoute = [regex]::Matches($dhcpSection, $reGetDefaultRoute ) 
    if ($matchDeviceDefaultRoute.Count -ne 0) {
        $dhcpObject.DefaultRoute = [IPAddress]$matchDeviceDefaultRoute.Captures.Groups[1].Value 
    }

    $matchLeaseTime = [regex]::Matches($dhcpSection, $reGetLeaseTime )
    if ($matchLeaseTime.Count -ne 0) {
        $dhcpObject.LeaseTime = New-TimeSpan -Days $matchLeaseTime.Captures.Groups[1].Value
    }
    if ($dhcpObject.LeaseTime -eq 0) { $dhcpObject.LeaseTime = New-TimeSpan -Days 8 }

    $matchesDomainName = [regex]::Matches($dhcpSection, $reGetDomainName )
    if ($matchesDomainName.Count -ne 0) {
        $dhcpObject.DomainName = $matchesDomainName.Captures.Groups[1].Value 
    }

    $matchDNSList = [regex]::Matches($dhcpSection, $reGetDNSList )
    if ($matchDNSList.Count -ne 0) {
        $dhcpObject.DNSList = @(($matchDNSList.Captures.Groups[1].Value).Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)) 
    }
    
    #
    # Process additional DHCP options
    #

    # Process Option 42 - NTP Server settings
    $matchNTPServers = [regex]::Matches($dhcpSection, $reGetNTPServersOption42 )
    if ($matchNTPServers.Count -ne 0) {
        $dhcpObject.NTPServerList = @(($matchNTPServers.Captures.Groups[1].Value).Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)) 
    }

    # Process Option 43 - Vendor Specific (UniFi WiFi)
    $matchOption43 = [regex]::Matches($dhcpSection, $reGetVedorSpecificOption43 )
    if ($matchOption43.Count -ne 0) {
        $dhcpObject.Option43 = $matchOption43.Captures.Groups[1].Value 
    }

    # Process Option 66 - Boot Server
    $matchBootServer = [regex]::Matches($dhcpSection, $reOption66 )
    if ($matchBootServer.Count -ne 0) {
        $dhcpObject.BootServer = $matchBootServer.Captures.Groups[1].Value 
    }

    # Process next-server - Boot Server
    $matchBootServer = [regex]::Matches($dhcpSection, $reNextServerOption66 )
    if ($matchBootServer.Count -ne 0) {
        $dhcpObject.BootServer = $matchBootServer.Captures.Groups[1].Value 
    }

    # Process Option 67 - Boot File
    $matchBootFile = [regex]::Matches($dhcpSection, $reOption67 )
    if ($matchBootFile.Count -ne 0) {
        $dhcpObject.BootFile = $matchBootFile.Captures.Groups[1].Value 
    }

    # Process bootfile - Boot File
    $matchBootFile = [regex]::Matches($dhcpSection, $reBootfileOption67 )
    if ($matchBootFile.Count -ne 0) {
        $dhcpObject.BootFile = $matchBootFile.Captures.Groups[1].Value 
    }

    # Process device MAC Address for device reverations
    $matchDeviceMAC = [regex]::Matches($dhcpSection, $reClientIdentifier ) 
    if ($matchDeviceMAC -ne 0) {
        $rawMAC = [string]($matchDeviceMAC.Captures.Groups[1].Value).Replace(".", "")
        if ($rawMAC.Length -eq 14 ) { $rawMAC = $rawMAC.Substring(2) }
        $dhcpObject.MAC = $rawMAC -split '(..)' -ne '' -join '-'
    }
    
    if (IsNetworkPool($dhcpSection)) { $listScopes += $dhcpObject }
    else { $listReservations += $dhcpObject }
}

#
# Create all Pools/Scopes
#

foreach ($scope in $listScopes) {
    Add-DhcpServerv4Scope -Name $scope.Name -Description $scope.Name -SubnetMask $scope.Network.SubnetMask -LeaseDuration $scope.LeaseTime -StartRange $scope.Network.FirstAddress -EndRange $scope.Network.LastAddress
    if($scope.DefaultRoute) {
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -Router $scope.DefaultRoute -Force
    }
    if($scope.DNSList) {
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -DnsServer $scope.DNSList -Force
    }
    if($scope.DomainName) {
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -DnsDomain $scope.DomainName -Force
    }
    if($scope.NTPServerList){
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -DnsDomain $scope.DomainName -Force
    }
    if($scope.Option43) {
        $strValue = $scope.Option43.Replace(".","")
        $endIndex = ($strValue.Length / 2) - 1

        $listValue = @()
        foreach($index in 0..$endIndex){
            $strByte = "0x" + $strValue[$index*2] + $strValue[$index*2+1]
            $intValue = [System.Convert]::ToInt16($strByte,16)
            $listValue += $intvalue
        }
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -OptionId 43 -Value $listValue -Force
    }
    if($scope.BootServer) {
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -OptionId 66 -Value $scope.BootServer -Force
    }
    if($scope.BootFile) {
        Set-DhcpServerv4OptionValue -ScopeId $scope.Network.NetworkAddress -OptionId 67 -Value $scope.BootFile -Force
    }
}

#
# Process Exclusions in to the scopes
#

foreach ($matchExclusion in $matchDHCPExclusions) {
    $startIP = [ipaddress]$matchExclusion.Captures.Groups[1].Value.Trim()
    $endIP = $startIP
    # If we have a range end IP then get it ni to a variable
    if ($matchExclusion.Captures.Groups[2].Value.Length -gt 6) { 
        $endIP = [ipaddress]$matchExclusion.Captures.Groups[2].Value.Trim()
    }

    Write-Host " Exclude: $startIP - $endIP"

    foreach ($scope in $listScopes) {
        if (Test-IPv4InSubnet -IP $startIP -SubnetCIDR $scope.Network.CIDRNotation) {
            Write-Host "  + Creating exclusion in ScopeID $($scope.Network.NetworkAddress)"  -ForegroundColor Green
            Add-DhcpServerv4ExclusionRange -ScopeId $scope.Network.NetworkAddress -StartRange $startIP -EndRange $endIP
        }
    }
}

#
# Process Reservations
#

foreach($reservation in $listReservations) {
    foreach ($scope in $listScopes) {
        if (Test-IPv4InSubnet -IP $reservation.IPAddress -SubnetCIDR $scope.Network.CIDRNotation) {
            Write-Host " IP: $($reservation.IPAddress) MAC: $($reservation.MAC) Name: $($reservation.Name)"
            Write-Host "  + Creating reservation in ScopeID $($scope.Network.NetworkAddress)"  -ForegroundColor Green
            Add-DhcpServerv4Reservation -ScopeId $scope.Network.NetworkAddress -IPAddress $reservation.IPAddress -ClientId $reservation.MAC -Name $reservation.Name -Description $reservation.Name
        }
    }
}

Write-Host "  ... COMPLETED ... "