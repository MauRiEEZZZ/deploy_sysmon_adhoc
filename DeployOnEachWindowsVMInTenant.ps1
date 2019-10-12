[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $tenantId,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $scriptPath
)
function InvokeAZSubscriptionVMRunCommand {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $tenantId,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $subscriptionId,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $resourceGroup,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $vmName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $scriptPath
    )
    
    try{
        Write-Verbose -Message "Running script to invoke command on $vmName"

        Set-AzContext -Tenant $tenantId  -Subscription $subscriptionId -Scope CurrentUser

        Write-Verbose -Message "Changed context script to Subscription ID $subscriptionId and $tenantID"

        Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -VMName $vmName -CommandId 'RunPowerShellScript' -ScriptPath $scriptPath -Verbose
        Write-Verbose -Message "$scriptPath was invoked on $vmName"
    }
    catch {
        Write-Error "Unable to set context to $subscriptionId with message:" -ErrorAction Stop

    }

}
        
try{
    $currContext = Get-AzContext
    if($currContext){
        if($context.Tenant.ToString() -ne $tenantId){
            $currContext = Set-AzContext -Tenant $tenantId -Subscription $currContext.Subscription -Scope CurrentUser 
            Write-Verbose -Message "Changed context to Tenant ID $tenantId"
        }
    }
}
catch{
    Write-Error "Unable to change the context to $(tenantId) with message: $($errorResult.message)" -ErrorAction Stop
}
try{
    $vms = Search-AzGraph -Query "where type =~ 'microsoft.compute/virtualmachines'| where properties.osProfile contains 'windowsConfiguration' | project subscriptionId, resourceGroup, name, location"
    $count = $vms.Count
    Write-Verbose "Found $count VMs in Tenant $tenantId"
}
catch{
    Write-Error "Unable to search Graph on $(tenantId) with message: $($errorResult.message)" -ErrorAction Stop
}
foreach($vm in $vms) {
    InvokeAZSubscriptionVMRunCommand -tenantId $tenantId -subscriptionId $vm.subscriptionId -resourceGroup $vm.resourceGroup -vmName $vm.name -scriptPath .\compressedSysmonAsString.ps1 
}

