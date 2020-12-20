# This script sets the tag on Virtual Machines

$tenantId = 'd892a081-1f19-49f6-94c3-2ef56720126e'
$subscriptionId = 'b15f8260-5873-453c-a871-d30cf51bd779'


$swoMonitor = @{"swoMonitor"="0"}
$swoBackup = @{"swoBackup"="0"}
$swoPatch = @{"swoPatch"="0"}
$swoAntimalware = @{"swoAntimalware"="0"}





# Set Azure Context
Set-AzContext -Tenant '$tenantId' -Subscription '$subscriptionId'

