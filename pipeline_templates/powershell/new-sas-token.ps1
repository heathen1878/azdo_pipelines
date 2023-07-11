function New-SASToken {

    <#
        .SYNOPSIS
            Generates a SAS token for a provided storage account

        .NOTES
            Version:        1.0.0.0
            Author:         Dom Clayton

        .EXAMPLE
            Using defaults
            $url, $token = New-SASToken -ResourceGroupName RG -StorageAccountName ST -ContainerName CN

            Extend the SAS Token lifetime - the Time in hours is always minus 1 hour to ensure the SAS token is immediately available
            $url, $token = New-SASToken -ResourceGroupName RG -StorageAccountName ST -ContainerName CN -TimeInHours 4

            Generate a SAS token with additional permissions - default is read
            $url, $token = New-SASToken -ResourceGroupName RG -StorageAccountName ST -ContainerName CN -Perms 'rwdl'
    
    #>


    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$resourceGroupName,
        [Parameter(Mandatory)]
        [string]$storageAccountName,
        [Parameter(Mandatory)]
        [string]$containerName,
        [Parameter(Mandatory=$False)]
        [int]$timeInHours = 2,
        [Parameter(Mandatory=$False)]
        [string]$perms='r'
        )

    # Get the storage account context
    Write-Verbose ('Getting the storage account context')
    $context = (Get-AzStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName).Context

    # Check for the the BlobEndPoint property
    Write-Verbose ('Checking context properties')
    If ($null -ne $context.BlobEndPoint){

        # Check whether the container exists
        Write-Verbose ('Checking whether the container {0} exists' -f $containerName)
        $containers = (Get-AzStorageContainer -Context $context).Name

        If ($containerName -notin $containers){

            Write-Warning ('The container {0} does not exist in {1}' -f $containerName, $context.StorageAccountName)
            Break

        }

        # Attempt to generate a SAS Token
        Write-Verbose ('Generating SAS token for {0} with lifetime of: {1} hour(s)' -f $context.StorageAccountName, ($timeInHours -1))
        Try {

            $sasToken = New-AzStorageAccountSASToken `
            -Context $context `
            -Service Blob `
            -ResourceType service,container,object `
            -Permission $perms `
            -StartTime (Get-Date).AddHours(-1) `
            -ExpiryTime (Get-Date).AddHours($timeInHours) -ErrorAction Stop

        }
        Catch {

            Write-Warning $Error[0].Exception.Message
            break

        }

    } Else {

        Write-Warning ('You do not have permissions to list keys on: {0} add at least ''Reader and Data Access''' -f $context.StorageAccountName)
        Break

    }

    Write-Verbose ('Returning storage account Url and SAS Token')
    Return (-join($context.BlobEndPoint, $containerName)), $sasToken

}