<#
    .SYNOPSIS
        Installs private and or public modules

    .NOTES
        Version:        1.0.0.0
        Author:         Dom Clayton
        Creation Date:  26/01/2023

    .EXAMPLE
        
    #>

[CmdletBinding()]
Param
(
    [parameter(Mandatory=$false)]
    [string]$private_modules='{}',
    [parameter(Mandatory=$false)]
    [string]$public_modules='{}',
    [parameter(Mandatory=$false)]
    [string]$azdofeed=""
)

# Convert the input parameter strings to hashtables
$private_module_hash = $private_modules | ConvertFrom-Json -AsHashtable
$public_module_hash = $public_modules | ConvertFrom-Json -AsHashtable

# Install modules from a public feed
$public_module_hash.Keys | ForEach-Object {

    $module = $_
    $version = $public_module_hash[$_]

    Write-Host ('Installing module {0}' -f $module)

    if (Get-Module -Name $module){
        $module_version = (Get-InstalledModule -Name $module).Version
        
        if ($module_version -lt $version){
            Try {
                Install-Module -Repository PSGallery -Name $module -MinimumVersion $version -Scope CurrentUser -Confirm:$false -Force -ErrorAction Stop
            }
            Catch {
                Write-Output ('Caught an error: {0}' -f $Error[0].Exception.Message)
            }
        }

    } Else {

        Try {
            Install-Module -Repository PSGallery -Name $module -MinimumVersion $version -Scope CurrentUser -Confirm:$false -Force -ErrorAction Stop
        }
        Catch {
            Write-Output ('Caught an error: {0}' -f $Error[0].Exception.Message)
        }

    }
}

# Install modules from a private feed e.g. AzDo artifact feed
## Reference for internal PowerShell modules - https://ochzhen.com/blog/install-powershell-module-from-azure-artifacts-feed
#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
#
#$accessToken = $env:SYSTEM_ACCESSTOKEN | ConvertTo-SecureString -AsPlainText -Force
#
#$devOpsCred = New-Object System.Management.Automation.PSCredential($env:SYSTEM_ACCESSTOKEN, $accessToken)
#
#Register-PackageSource -Name AzDoRepo -ProviderName 'PowerShellGet' -Location $azdofeed -Trusted -Credential $devOpsCred -Force
# TODO: Register package source seems to be failing the location variable...
#
#$private_module_hash.Keys | ForEach-Object {
#    try {
#        Install-Module -Name $_ -Repository AzDoRepo -Credential $devOpsCred -Verbose
#    }
#    Catch {
#        Write-Output ('Caught an error: {0}' -f $Error[0].Exception.Message)
#    }
#}
#