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
$Query = "SELECT * FROM c WHERE c.id='NL-SCU-666'"

$Query = "SELECT * FROM c WHERE ARRAY_CONTAINS(c.site24x7.tagPolicy, id='85429adb-9e97-44af-9da0-a01bb221407e')"

$Query = "SELECT "





# execute
$response  = Query-CosmosDb -EndPoint $CosmosDBEndPoint -DataBaseId $DataBaseId -CollectionId $CollectionId -MasterKey $MasterKey -Query $Query
$response = $response | ConvertFrom-Json -AsHashtable
$response

Write-Host 'Customername =' $response.Documents.customerName
Write-Host 'Customer SCU =' $response.Documents.id
Write-Host 'Site24x7 Devicekey =' $response.Documents.site24x7.deviceKey
Write-Host 'Azure Subscriptions =' $response.Documents.site24x7.tagPolicy

Write-Host 'swoMonitor Tag Policy for' $sub = $response.Documents.site24x7.tagPolicy."85429adb-9e97-44af-9da0-a01bb221407e" 



