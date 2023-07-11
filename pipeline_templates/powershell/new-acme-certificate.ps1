<#
    .SYNOPSIS
    This script automates the creation and renewal of certificates using Lets Encrypt.

    .NOTES
    Version:        1.0.0.0
    Author:         Dom Clayton
    Updated:        04/07/2023
    
    The original script can be found here...https://github.com/brent-robinson/posh-acme-azure-example - 

    .EXAMPLE
    Initially certificate requests should go to the staging servers until you're ready for production https://letsencrypt.org/docs/staging-environment/
    New-AcmeCertificate.ps1 -domainNames "'*.domain.com','domain.com'" -contactEmailAddress john.doe@domain.com -storageAccountId 'Azure Resource Id' -keyVaultId 'Azure Resource Id'
    
    To use the production servers for your certificate pass -staging 0.
    New-AcmeCertificate.ps1 -domainNames "'*.domain.com','domain.com'" -contactEmailAddress john.doe@domain.com -storageAccountId 'Azure Resource Id' -keyVaultId 'Azure Resource Id' -Staging 0

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, HelpMessage="The API Token used by Cloudflare")]
    [string]$api_token,
    [Parameter(Mandatory, HelpMessage="Takes an array of strings e.g. 'domain.com', '*.domain.com'")]
    [string[]]$domain_names,
    [Parameter(Mandatory, HelpMessage="A contact email address for where certificate renewals should be sent")]
    [string]$contact_email_address,
    [Parameter(Mandatory, HelpMessage="The storage account resource id where certificate metadata will be stored")]
    [string]$storage_account_id,
    [Parameter(Mandatory, HelpMessage="The key vault resource id where the certificate pfx will be stored")]
    [string]$key_vault_id,
    [Parameter(Mandatory=$false, HelpMessage= "The DNS plugin to use with Posh-ACME - this script supports Azure DNS and Cloudflare")]
    [ValidateSet("Azure", "Cloudflare")]
    [string]$dns_provider="Azure",
    [Parameter(Mandatory=$false, HelpMessage="If using Azure DNS and the public DNS zone is in a different subscription, specify that subscription Id here")]
    [string]$dns_zone_subscription_id=$null,
    [Parameter(Mandatory, HelpMessage="The subscription Id where the storage account and key vault reside")]
    [string]$environment_subscription_id,
    [Parameter(Mandatory=$false)]
    [bool]$staging=$true
)

# Module dependencies
#Requires -Version 6.1
#Requires -Modules @{ModuleName="Az.Accounts"; ModuleVersion="2.5.2"}
#Requires -Modules @{ModuleName="Az.Storage"; ModuleVersion="3.10.0"}
#Requires -Modules @{ModuleName="Posh-ACME"; ModuleVersion="4.9.0"}
#Requires -Modules @{ModuleName="Az.KeyVault"; ModuleVersion="3.4.5"}
#Requires -Modules @{ModuleName="Az.Resources"; ModuleVersion="4.3.0"}

# Prequisites
## Set Error Action Preference
$ErrorActionPreference = 'Stop'

## Load dependent modules
. $PSScriptRoot/new-sas-token.ps1
. $PSScriptRoot/write-to-log.ps1

# Create securestring
$secure_api_token = ConvertTo-SecureString $api_token -AsPlainText -Force

# Create working directory
$wd = Join-Path -Path "." -ChildPath "LE"
Write-Verbose ('Creating working directory: {0}' -f $wd)
New-Item -Path $wd -ItemType Directory -Force | Out-Null
Write-Verbose ('working directory: {0} created' -f $wd)

# Supress progress messages. Azure DevOps doesn't format them correctly (used by New-PACertificate)
Write-Verbose ('Setting progress preference to silently continue to support DevOps')
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Setting progress preference to silently continue to support DevOps')
$global:ProgressPreference = 'SilentlyContinue'

# Set the posh-ACME dns provider plugin attributes
switch ($dns_provider) {
    'Azure' {

        $azureAccessToken = (Get-AzAccessToken).Token

        $pa_plugin_args = @{
            AZSubscriptionId = (Get-AzContext).Subscription.Id
            AZAccessToken    = $azureAccessToken;
        }

        Write-Verbose ('Automatically creating certificate for {0}' -f $domainNames[0])
        

    }
    'Cloudflare' {

        $pa_plugins_args = @{
            CFToken = $secure_api_token
        }

    }
}
# End of prequisites

############################ Checks ############################

# Prep variables
$storage_rg = $storage_account_id.Split('/')[4]
$storage_account = $storage_account_id.Split('/')[8]
$key_vault_rg = $key_vault_id.Split('/')[4]
$key_vault = $key_vault_id.Split('/')[8]

# Check whether the storage account exists
try {
    Get-AzStorageAccount -ResourceGroupName $storage_rg -Name $storage_account | Out-Null
    Write-Verbose ("{0} found in {1}" -f $storage_account, $environment_subscription_id)
}
catch { 
    Write-Error ("{0} not found in {1}" -f $storage_account, $environment_subscription_id)
}

# Check whether the Key Vault exists
try {
    Get-AzKeyVault -ResourceGroupName $key_vault_rg -VaultName $key_vault | Out-Null
    Write-Verbose ("{0} found in {1}" -f $key_vault, $environment_subscription_id)
}
catch { 
    Write-Error ("{0} not found in {1}" -f $key_vault, $environment_subscription_id)
}

# Check whether AzCopy is installed
If (Get-Command azcopy){
    Write-Verbose ('AzCopy found')
} Else {
    Write-Error ('AzCopy not found')
}

# Get the storage account SAS token
# requires New-SASToken function.
try {
    $blob_endpoint, $sas_token = New-SASToken -containerName 'letsencrypt' -storageAccountName $storage_account -resourceGroupName $storage_rg -perms 'rwdl' -errorAction Stop
    Write-Verbose ('Generating a SAS token for: {0}' -f $blob_endpoint)

    # Sync contents of storage container to working directory
    azcopy sync (-join($blob_endpoint,$sas_token)) $wd | Out-Null
    Write-Verbose ('Blobs being synched from {0} on {1}' -f $blob_endpoint, (-Join((get-date).DayOfWeek, ' at ', (Get-Date).ToShortTimeString())))
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Blobs being synched from {0} at {1}' -f $blob_endpoint, (-Join((get-date).DayOfWeek, ' at ', (Get-Date).ToShortTimeString())))
}
catch {
    Write-Error ('{0}' -f $Error[0])
}

############################ End of Checks ############################

############################ Flow #####################################
# Set Posh-ACME working directory
Write-Verbose ('Setting POSHACME_HOME to {0}' -f $wd)
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Setting POSHACME_HOME to {0}' -f $wd)
$env:POSHACME_HOME = $wd
Import-Module Posh-ACME -Force

# Configure ACME server type
If ($staging){
    Write-Verbose ('Using staging directory LE_STAGE')
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Using staging directory LE_STAGE')
    Set-PAServer -DirectoryUrl LE_STAGE
} Else {    
    Write-Verbose ('Using production directory LE_PROD')
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Using production directory LE_PROD')
    Set-PAServer -DirectoryUrl LE_PROD
}

# The certificate name is always the first name passed into the string array
Write-Verbose ('certificate name: {0}' -f $domain_names[0])
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('certificate name: {0}' -f $domain_names[0])
$certificate_name = $domain_names[0]

# Posh-ACME replaces the * in a wildcard certificate with a !
$certificate_name = $certificate_name.Replace('*','!')
Write-Verbose ('{0} being renamed to {1} to support Post-ACME' -f $domain_names[0], $certificate_name)
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('{0} being renamed to {1} to support Post-ACME' -f $domain_names[0], $certificate_name)

# Configure Posh-ACME account
Write-Verbose ('Checking for a Lets Encrypt account in the working directory {0}' -f $wd)
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Checking for a Lets Encrypt account in the working directory {0}' -f $wd)
if (-not (Get-PAAccount)) {
    
    New-PAAccount -Contact $contact_email_address -AcceptTOS
    Write-Verbose ('New account {0} with id: {1} created' -f $((Get-PAAccount).Contact), (Get-PAAccount).Id)
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('New account {0} with id: {1} created' -f $((Get-PAAccount).Contact.Substring(7)), (Get-PAAccount).Id)

} Else {

    Write-Verbose ('Found account {0} with id: {1}' -f $(Get-PAAccount).Contact, (Get-PAAccount).Id)
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Found account {0} with id: {1}' -f $((Get-PAAccount).Contact.Substring(7)), (Get-PAAccount).Id)

}

# Get the expiry of the current order, if it exists
$certificate_directory = (-join($wd, '/', (Get-PAServer).Name, '/', (Get-PAAccount).Id, '/', $certificate_name))
Write-Verbose ('Checking for certificate directory {0}' -f $certificate_directory)
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Checking for certificate directory {0}' -f $certificate_directory)
If (Test-Path $certificate_directory){

    # Read order.json and determine the order status
    $order = Get-Content (-join($certificate_directory, '\order.json')) | ConvertFrom-Json

    # Check whether the certificate is due to expire?
    If ((Get-Date).Date -ge $order.CertExpires.AddDays(-20)){
    
        Write-Verbose ('Expiry: {0}' -f $order.CertExpires)
        Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Expiry: {0}' -f $order.CertExpires)
        New-PACertificate -Domain $domain_names -DnsPlugin $dns_provider -PluginArgs $pa_plugins_args
    
    } Else {

        Write-Verbose ('Certificate for {0} valid until {1}' -f $order.MainDomain, $order.CertExpires)
        Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Certificate for {0} valid until {1}' -f $order.MainDomain, $order.CertExpires)
        New-PACertificate -Domain $domain_names -DnsPlugin $dns_provider -PluginArgs $pa_plugins_args

    }

}  Else {

    Write-Verbose ('No existing certificate directory found for {0}' -f $certificate_name)
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('No existing certificate directory found for {0}' -f $certificate_name)
    New-PACertificate -Domain $domain_names -DnsPlugin $dns_provider -PluginArgs $pa_plugins_args
   
}

# Get the pfx password
Write-Verbose ('Retrieving password for certificate {0}' -f $certificate_name)
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Retrieving password for certificate {0}' -f $certificate_name)
$pfx_pass = (Get-PAOrder -Name $certificate_name).PfxPass

# Convert the pfx password to a secure string
$pfx_pass = ConvertTo-SecureString -String $pfx_pass -AsPlainText -Force

# Load the pfx
Write-Verbose ('Loading pfx')
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Loading pfx')
$certificate = Get-PfxCertificate -FilePath (-join($certificate_directory, '\fullchain.pfx')) -Password $pfx_pass

# Get Base64 certificate encoding
Write-Verbose ('Generating BASE64 for certificate {0}' -f $certificate.Thumbprint )
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Generating BASE64 for certificate {0}' -f $certificate.Thumbprint )
$pfx_bytes = Get-Content -Path (-join($certificate_directory, '\fullchain.pfx')) -AsByteStream
$certificate_base64 = [System.Convert]::ToBase64String($pfx_bytes)
$certificate_base64 = ConvertTo-SecureString -String $certificate_base64 -AsPlainText -Force

# Get the current certificate from key vault (if any)
$Key_vault_certificate_name = $certificate_name.Replace(".", "-").Replace("!", "wildcard")

# Check whether there is a certifcate already stored in Key Vault
Write-Verbose ('Checking for certificate {0} in Key Vault {1}' -f $Key_vault_certificate_name, $key_vault)
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Checking for certificate {0} in Key Vault {1}' -f $Key_vault_certificate_name, $key_vault)
If ($Key_vault_certificate = Get-AzKeyVaultCertificate -VaultName $key_vault -Name $Key_vault_certificate_name) {

    # Certificate already exists...Check the thumbprint
    Write-Verbose ('Checking thumbprints of {0} and {1}' -f $Key_vault_certificate_name, $certificate_name)
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Checking thumbprints of {0} and {1}' -f $Key_vault_certificate_name, $certificate_name)
    If ($Key_vault_certificate.Thumbprint -ne $certificate.Thumbprint) {

        Write-Verbose ('Replacing {0} into the key vault {1}' -f $Key_vault_certificate_name, $key_vault)
        Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Replacing {0} into the key vault {1}' -f $Key_vault_certificate_name, $key_vault)
        Import-AzKeyVaultCertificate -VaultName $key_vault -Name $Key_vault_certificate_name -FilePath (-join($certificate_directory, '\fullchain.pfx')) -Password $pfx_pass | Out-Null
    
    }

} Else {

    Write-Verbose ('Adding {0} into the key vault {1}' -f $Key_vault_certificate_name, $key_vault)
    Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Adding {0} into the key vault {1}' -f $Key_vault_certificate_name, $key_vault)
    Import-AzKeyVaultCertificate -VaultName $key_vault -Name $Key_vault_certificate_name -FilePath (-join($certificate_directory, '\fullchain.pfx')) -Password $pfx_pass | Out-Null

}

Write-Verbose ('Blobs being synched to storage account: {0} at {1}' -f $blob_endpoint, (-Join((get-date).DayOfWeek, ' ', (Get-Date).TimeOfDay.Hours, ':', (Get-Date).TimeOfDay.Minutes)))
Write-ToLog -LogFile (-join($wd, '/le.log')) -LogContent ('Blobs being synched to storage account: {0} at {1}' -f $blob_endpoint, (-Join((get-date).DayOfWeek, ' ', (Get-Date).TimeOfDay.Hours, ':', (Get-Date).TimeOfDay.Minutes)))
# Sync working directory back to storage container
azcopy sync $wd (-join($blob_endpoint,$sas_token)) | Out-Null