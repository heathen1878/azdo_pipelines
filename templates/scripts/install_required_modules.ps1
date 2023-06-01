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
        [string]
        $private_modules="",
        [parameter(Mandatory=$false)]
        [string]
        $public_modules="",
        [parameter(Mandatory=$false)]
        [string]
        $azdofeed=""
    )
    
    # Convert the input parameter strings to hashtables
    $private_modules = $private_modules | ConvertFrom-Json -AsHashtable
    $public_modules = $public_modules | ConvertFrom-Json -AsHashtable
    
    # Install modules from a public feed
    $public_modules.Keys | ForEach-Object {
    
        if (Get-Module -Name $_){
            $module_version = (Get-InstalledModule -Name $_).Version
            
            if ($module_version -lt $public_modules[$_]){
                Try {
                    Install-Module -Repository PSGallery -Name $_ -MinimumVersion $public_modules[$_] -Scope CurrentUser -Confirm:$false -Force -ErrorAction Stop
                }
                Catch {
                    Write-Output ('Caught an error: {0}' -f $Error[0].Exception.Message)
                }
            }
            
        }
    }
    
    # Install modules from a private feed e.g. AzDo artifact feed
    # Reference for internal PowerShell modules - https://ochzhen.com/blog/install-powershell-module-from-azure-artifacts-feed
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $accessToken = $env:SYSTEM_ACCESSTOKEN | ConvertTo-SecureString -AsPlainText -Force
    
    $devOpsCred = New-Object System.Management.Automation.PSCredential($env:SYSTEM_ACCESSTOKEN, $accessToken)
    
    Register-PackageSource -Name AzDoRepo -ProviderName 'PowerShellGet' -Location $azdofeed -Trusted -Credential $devOpsCred -Force
    
    $private_modules.Keys | ForEach-Object {
        try {
            Install-Module -Name $_ -Repository AzDoRepo -Credential $devOpsCred -Verbose
        }
        Catch {
            Write-Output ('Caught an error: {0}' -f $Error[0].Exception.Message)
        }
    }
    