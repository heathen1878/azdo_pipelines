<#
    .SYNOPSIS
        Uses the function Get-AvailableAzDoAgent in Dom.Containers to look for free self-hosted agents. 
        If none are found then a container is started from the container groups which are tagged as DevOpsAgent.

    .NOTES
        Version:        1.0.0.0
        Author:         Dom Clayton
        Creation Date:  26/01/2023

    .EXAMPLE
        
    #>

[CmdletBinding()]
Param
(
    [parameter(Mandatory)]
    [string]
    $azdo_service_account_url
)

Get-AvailableAzDoAgent -azdo_service_account_url $azdo_service_account_url -azdo_personal_access_token $azdo_personal_access_token -pool_name $pool_name
