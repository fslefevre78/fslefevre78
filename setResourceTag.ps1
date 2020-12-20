# This script sets the tag on Virtual Machines

$tenantId = 'd892a081-1f19-49f6-94c3-2ef56720126e'
$subscriptionId = 'b15f8260-5873-453c-a871-d30cf51bd779'


$swoMonitor = @{"swoMonitor"="0"}
$swoBackup = @{"swoBackup"="0"}
$swoPatch = @{"swoPatch"="0"}
$swoAntimalware = @{"swoAntimalware"="0"}


$virtualMachine = Get-AzResource -ResourceType 'Microsoft.Compute/VirtualMachines'
# $exclude = @('vm-appwin')


# Set Azure Context
# Set-AzContext -Tenant '$tenantId' -Subscription '$subscriptionId'

foreach ($vm in $virtualMachine) {
    if ($null -ne $swoMonitor) {
        if ($swoMonitor.enforcement -eq 'true') {
            if ($exclude -notcontains $vm.Name ) {
                Write-Host 'Policy enforcement is set to true, Tag is replaced on '$vm.Name''
            }
        }
        else {
            if ($exclude -notcontains $vm.Name ) {
                Write-Host 'Tag is updated on '$vm.Name''
            }
        }
    }
    else {
        Write-Host 'No Policy found for '$vm.Name''
    }
}