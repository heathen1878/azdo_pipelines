Function Write-ToLog {

	<#
        .SYNOPSIS
            Creates a text log file and then adds content or adds content if the log file already exists

        .NOTES
            Version:        1.0.0.0
            Author:         Dom Clayton

        .EXAMPLE
            Write-ToLog -LogFile fileName -LogContent 'Content'
			    
    #>


    [CmdletBinding()]
	Param
	(
        [parameter(Mandatory)]
	    [string]$LogFile,  
	    [parameter(Mandatory)]
        [string]$LogContent
	)
	
	If (Test-Path $LogFile) {
	
		# Append to the file
		Add-Content -Path $LogFile -Value $LogContent
		
	}
	Else {
	
		# Create the file
		New-Item -ItemType File -Path $LogFile
		Add-Content -Path $LogFile -Value $LogContent
		
	}
}