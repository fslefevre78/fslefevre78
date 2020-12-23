# This script sets the tag on Virtual Machines
$tenantId = 'd892a081-1f19-49f6-94c3-2ef56720126e'
$subscriptionId = '85429adb-9e97-44af-9da0-a01bb221407e'

# Query COSMOS DB
# add necessary assembly

Add-Type -AssemblyName System.Web

# generate authorization key
Function Generate-MasterKeyAuthorizationSignature
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$verb,
		[Parameter(Mandatory=$true)][String]$resourceLink,
		[Parameter(Mandatory=$true)][String]$resourceType,
		[Parameter(Mandatory=$true)][String]$dateTime,
		[Parameter(Mandatory=$true)][String]$key,
		[Parameter(Mandatory=$true)][String]$keyType,
		[Parameter(Mandatory=$true)][String]$tokenVersion
	)

	$hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
	$hmacSha256.Key = [System.Convert]::FromBase64String($key)

	$payLoad = "$($verb.ToLowerInvariant())`n$($resourceType.ToLowerInvariant())`n$resourceLink`n$($dateTime.ToLowerInvariant())`n`n"
	$hashPayLoad = $hmacSha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($payLoad))
	$signature = [System.Convert]::ToBase64String($hashPayLoad);

	[System.Web.HttpUtility]::UrlEncode("type=$keyType&ver=$tokenVersion&sig=$signature")
}

# query
Function Query-CosmosDb
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$true)][String]$EndPoint,
		[Parameter(Mandatory=$true)][String]$DataBaseId,
		[Parameter(Mandatory=$true)][String]$CollectionId,
		[Parameter(Mandatory=$true)][String]$MasterKey,
		[Parameter(Mandatory=$true)][String]$Query
	)

	$Verb = "POST"
	$ResourceType = "docs";
	$ResourceLink = "dbs/$DatabaseId/colls/$CollectionId"

	$dateTime = [DateTime]::UtcNow.ToString("r")
	$authHeader = Generate-MasterKeyAuthorizationSignature -verb $Verb -resourceLink $ResourceLink -resourceType $ResourceType -key $MasterKey -keyType "master" -tokenVersion "1.0" -dateTime $dateTime
	$queryJson = @{query=$Query} | ConvertTo-Json
	$header = @{authorization = $authHeader; "x-ms-documentdb-isquery" = "True"; "x-ms-documentdb-query-enablecrosspartition"="True"; "x-ms-version" = "2018-12-31"; "x-ms-date" = $dateTime }
	$contentType= "application/query+json"
	$queryUri = "$EndPoint$ResourceLink/docs"

	$result = Invoke-RestMethod -Method $Verb -ContentType $contentType -Uri $queryUri -Headers $header -Body $queryJson

	$result | ConvertTo-Json -Depth 10
}

# fill the target cosmos database endpoint uri, database id, collection id and masterkey
$CosmosDBEndPoint = "https://swomcdev.documents.azure.com:443/"
$DatabaseId = "msdb"
$CollectionId = "managedCustomer"
$MasterKey = "pGEVzXsP34MMsWWTM0YEK7G7htkXjlsM22qwCuoUnyohVDXg7XUsRGmfyWPC3lQdP7hNXVsOvnf8B3vJEwZsLQ=="

# query string
$querySite24x7 = "SELECT a.id, a.tagValue, a.enforce, a.exclude FROM c JOIN a in c.site24x7.tagPolicy WHERE a.id='$($subscriptionId)'"
$queryCommvault = "SELECT a.id, a.tagValue, a.enforce, a.exclude FROM c JOIN a in c.commvault.tagPolicy WHERE a.id='$($subscriptionId)'"
$queryDesktopCentral = "SELECT a.id, a.tagValue, a.enforce, a.exclude FROM c JOIN a in c.desktopCentral.tagPolicy WHERE a.id='$($subscriptionId)'"
$queryTrendMicro = "SELECT a.id, a.tagValue, a.enforce, a.exclude FROM c JOIN a in c.trendMicro.tagPolicy WHERE a.id='$($subscriptionId)'"

# execute
$responseSite24x7  = Query-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -Query $querySite24x7 | ConvertFrom-Json -AsHashtable
$responseCommvault  = Query-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -Query $queryCommvault | ConvertFrom-Json -AsHashtable
$responseDesktopCentral  = Query-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -Query $queryDesktopCentral | ConvertFrom-Json -AsHashtable
$responseTrendMicro  = Query-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -Query $queryTrendMicro | ConvertFrom-Json -AsHashtable

# Set Azure Context
# Set-AzContext -Tenant '$tenantId' -Subscription '$subscriptionId'

# Create VirtualMachine List
$virtualMachine = Get-AzResource -ResourceType 'Microsoft.Compute/VirtualMachines'

# Site24x7 Tag
Write-Host 'Applying tag swoMonitor'

foreach ($vm in $virtualMachine) {
    if ($null -ne $responseSite24x7.Documents.tagValue) {
        if ($responseSite24x7.Documents.enforce -eq $true) {
            if ($responseSite24x7.Documents.exclude -notcontains $vm.Name) {
                Write-Host 'Policy enforcement is set to true, Tag is replaced on '$vm.Name''
				Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoMonitor"="$($responseSite24x7.Documents.tagValue)"} -Operation Merge
            }
			else {
				Write-Host 'Policy enforcement is ignored as '$vm.Name' is set to exclude'
			}
        }
        else {
            if ($responseSite24x7.Documents.exclude -notcontains $vm.Name ) {
				if ($null -ne $vm.Tags.swoMonitor) {
					Write-Host 'Tag is not updated as it already exists on '$vm.name''
				}
				else {
					Write-Host 'Tag is updated on '$vm.Name''
					Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoMonitor"="$($responseSite24x7.Documents.tagValue)"} -Operation Merge
				}
			}
			else {
				Write-Host 'Policy tag is ignored as '$vm.Name' is set to exclude'
			}
        }
    }
    else {
        Write-Host 'No Policy found for '$vm.Name''
		Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoMonitor"="$($responseSite24x7.Documents.tagValue)"} -Operation Delete 
    }
}

# Commvault Tag
Write-Host 'Applying tag swoBackup'

foreach ($vm in $virtualMachine) {
	if ($null -ne $responseCommvault.Documents.tagValue) {
		if ($responseCommvault.Documents.enforce -eq $true) {
			if ($responseCommvault.Documents.exclude -notcontains $vm.Name) {
				Write-Host 'Policy enforcement is set to true, Tag is replaced on '$vm.Name''
				Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoBackup"="$($responseCommvault.Documents.tagValue)"} -Operation Merge
			}
			else {
				Write-Host 'Policy enforcement is ignored as '$vm.Name' is set to exclude'
			}
		}
		else {
			if ($responseCommvault.Documents.exclude -notcontains $vm.Name ) {
				if ($null -ne $vm.Tags.swoBackup) {
					Write-Host 'Tag is not updated as it already exists on '$vm.name''
				}
				else {
					Write-Host 'Tag is updated on '$vm.Name''
					Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoBackup" = "$($responseCommvault.Documents.tagValue)" } -Operation Merge
				}
			}
			else {
				Write-Host 'Policy tag is ignored as '$vm.Name' is set to exclude'
			}
		}
	}
	else {
		Write-Host 'No Policy found for '$vm.Name''
		Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoBackup"="$($responseCommvault.Documents.tagValue)"} -Operation Delete
	}
} 

# Desktop Central Tag
Write-Host 'Applying tag swoPatch'

foreach ($vm in $virtualMachine) {
	if ($null -ne $responseDesktopCentral.Documents.tagValue) {
		if ($responseDesktopCentral.Documents.enforce -eq $true) {
			if ($responseDesktopCentral.Documents.exclude -notcontains $vm.Name) {
				Write-Host 'Policy enforcement is set to true, Tag is replaced on '$vm.Name''
				Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoPatch"="$($responseDesktopCentral.Documents.tagValue)"} -Operation Merge
			}
			else {
				Write-Host 'Policy enforcement is ignored as '$vm.Name' is set to exclude'
			}
		}
		else {
			if ($responseDesktopCentral.Documents.exclude -notcontains $vm.Name ) {
				if ($null -ne $vm.Tags.swoPatch) {
					Write-Host 'Tag is not updated as it already exists on '$vm.name''
				}
				else {
					Write-Host 'Tag is updated on '$vm.Name''
					Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoPatch"="$($responseDesktopCentral.Documents.tagValue)"} -Operation Merge
				}
			}
			else {
				Write-Host 'Policy tag is ignored as '$vm.Name' is set to exclude'
			}
		}
	}
	else {
		Write-Host 'No Policy found for '$vm.Name''
		Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoPatch"="$($responseDesktopCentral.Documents.tagValue)"} -Operation Delete
	}
}

# TrendMicro Tag
Write-Host 'Applying tag swoAntiMalware'

foreach ($vm in $virtualMachine) {
	if ($null -ne $responseTrendMicro.Documents.tagValue) {
		if ($responseTrendMicro.Documents.enforce -eq $true) {
			if ($responseTrendMicro.Documents.exclude -notcontains $vm.Name) {
				Write-Host 'Policy enforcement is set to true, Tag is replaced on '$vm.Name''
				Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoAntiMalware"="$($responseTrendMicro.Documents.tagValue)"} -Operation Merge
			}
			else {
				Write-Host 'Policy enforcement is ignored as '$vm.Name' is set to exclude'
			}
		}
		else {
			if ($responseTrendMicro.Documents.exclude -notcontains $vm.Name ) {
				if ($null -ne $vm.Tags.swoAntiMalware) {
					Write-Host 'Tag is not updated as it already exists on '$vm.name''
				}
				else {
					Write-Host 'Tag is updated on '$vm.Name''
					Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoAntiMalware"="$($responseTrendMicro.Documents.tagValue)"} -Operation Merge
				}
			}
			else {
				Write-Host 'Policy tag is ignored as '$vm.Name' is set to exclude'
			}
		}
	}
	else {
		Write-Host 'No Policy found for '$vm.Name''
		Update-AzTag -ResourceId $vm.ResourceId -Tag @{"swoAntiMalware"="$($responseTrendMicro.Documents.tagValue)"} -Operation Delete
	}
 }