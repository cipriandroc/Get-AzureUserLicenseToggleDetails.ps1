<#
        .SYNOPSIS
        Retrieves the O365 Licenses assigned to the input users.

        .DESCRIPTION
        Retrieves the O365 Licenses assigned to the input users.
        Takes strings as the UserName in the form of userPrincipalName. Using the alias is supported, it assigns the default domain as the email address.

        .PARAMETER Userlist
        Specifies the user/s that need to be looked up

        .PARAMETER ExportPath
        Specifies the Report export location

        .INPUTS
        None. You cannot pipe objects to Add-Extension.

        .OUTPUTS
        System.String. Add-Extension returns a string with the extension or file name.

        .EXAMPLE
        C:\PS> .\Get-AzureUserLicenseToggleDetails.ps1 -userlist user@domain.com
        Lists the licenses assigned to the specified user, if any, along with their subtoggles.

        .EXAMPLE
        C:\PS> .\Get-AzureUserLicenseToggleDetails.ps1 -userlist user@domain.com,user2@domain.com,user3 -ExportLocation C:\Data\Output
        Lists the licenses for all the three specified users, if any, along with their subtoggles. User3 that's missing the domain is getting the default domain value added
        ExportLocation specifies the location where the report is generated, the script already handles the filename, and adds the date to it as well.
        Warning! It will overwrite the file, append is not enabled. The script also checks for the existing location if specified.
        C:\Data\OUTPUT\09.04_licenseTogglesExport.csv
        Use either C:\<folder> or C:\<folder>\ , the builtin function will detect if there's a backslash or not and handle it.

        .EXAMPLE
        C:\PS> .\Get-AzureUserLicenseToggleDetails.ps1 user
        Lists the licenses assigned to the specified user, if any, along with their subtoggles.
        The -username positional parameter allows the user alias to be placed first, script also adds default domain to form the userPrincipalName in case it's missing.

        .LINK
        Blog Article: https://cipriandroc.wordpress.com/2020/09/05/get-azurelicensetoggledetails-ps1/
		
		.LINK
		GitHub Repo : https://github.com/cipriandroc/Get-AzureUserLicenseToggleDetails.ps1
		
		.NOTES
		This script was created by Ciprian Droc
    #>
[Cmdletbinding()]
Param(
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string[]]$UserList = (Get-Content 'C:\DATA\Input\userlist.txt'),
    [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
    [string]$ExportPath
)

#hardcoded file name based on script scope 
#Export-Filename function adds date to it and generates the full export path based on the $exportpath provided
$filename = 'licenseTogglesExport'

function Export-Filename {
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$FileName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ExportLocation
    )
    $date = (get-date).tostring('MM.dd') 
    $generatefilename = $date + '_' + $filename + '.csv'
    if ($ExportLocation.Substring($ExportLocation.Length - 1) -eq '\') { $ExportItem = "$ExportLocation$generatefilename" }
    else { $ExportItem = "$ExportLocation\$generatefilename" }
    return $ExportItem
}
function Get-AzureUserDetails {
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$user
    )

    $getmaintenant = Get-AzureADTenantDetail | Select-Object -ExpandProperty verifieddomains | Where-Object { $_._default -eq $true } | Select-Object -ExpandProperty name

    foreach ($u in $user) {
        if ($u -notlike '*@*') {
            $u = $u + '@' + $getmaintenant
        }

        $outputProps = [ordered]@{
            "name"              = $u;
            "found"             = $false;
            "DisplayName"       = $null;
            "UserPrincipalName" = $null;
            "ObjectID"          = $null;
        }
        $founduser = Get-MsolUser -UserPrincipalName $u -ErrorAction SilentlyContinue

        If ($founduser) {
            $outputProps.found = $true
            $outputProps.DisplayName = $founduser.displayname
            $outputProps.ObjectID = $founduser.objectid
            $outputProps.UserPrincipalName = $founduser.userprincipalname
        }
        $output = New-Object psobject -Property $outputProps
        $output
    }
}
function Get-CDAzureUserLicenseDetail {
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [array[]]$AzureUser,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]]$ObjectID
    )
    if ($AzureUser) { $collection = $AzureUser }
    if ($ObjectID) { $collection = $ObjectID }

    foreach ($user in $collection) {
        $licenseresults = $null

        if ($AzureUser) {
            if ($user.objectid.guid) { $userObjectID = $user.objectid.guid }
            if ($user.userPrincipalName) { $userPrincipalName = $user.userPrincipalName }
            else { $userPrincipalName = $user.name }
        }
        if ($ObjectID) {
            $userObjectID = $user
            $MSOLObjectID = [System.guid]::New($userObjectID)
            $MSOLUser = Get-MsolUser -ObjectId $MSOLObjectID -ErrorAction SilentlyContinue
            if ($MSOLUser) { $userPrincipalName = $MSOLUser.userPrincipalName }
            else { $userPrincipalName = "error: invalid ObjectID" }
        }

        $licenseProps = [ordered]@{
            "userPrincipalName"  = $userPrincipalName;
            "userObjectID"       = $userObjectID;
            "LicenseObjectId"    = $null;
            "AppliesTo"          = $null;
            "ProvisioningStatus" = $null;
            "ServicePlanId"      = $null;
            "ServicePlanName"    = $null;
        }

        if ($userObjectID) {
            $userlicenses = Get-AzureADUserLicenseDetail -ObjectId $userObjectID
        }
    
        if (!$userObjectID) {
            $licenseProps.userObjectID = "error! user not found"
            $licenseresults = New-Object psobject -Property $licenseProps
        }
        if (!$userlicenses) {
            $licenseresults = New-Object psobject -Property $licenseProps 
        }
        if ($userlicenses) {
            $licenseresults = foreach ($license in $userlicenses) { $license | Select-Object -ExpandProperty serviceplans -Property objectid }
            $licenseresults | Add-Member -NotePropertyName "userObjectID" -NotePropertyValue $userObjectID
            $licenseresults | Add-Member -NotePropertyName "userPrincipalName" -NotePropertyValue $userPrincipalName
            $licenseresults = $licenseresults | Select-Object userPrincipalName, userObjectID, @{name = "LicenseObjectId"; e = { $_.ObjectID } }, AppliesTo, ProvisioningStatus, ServicePlanId, ServicePlanName
        }

        $licenseresults
        Remove-Variable -Name userObjectID, userPrincipalName, userName, MSOLObjectID, MSOLUser, userlicenses -ErrorAction SilentlyContinue
    }		
}		

$AzureUsers = Get-AzureUserDetails -user $userlist
$userlicensedetails = Get-CDAzureUserLicenseDetail -AzureUser $AzureUsers

if (!$userlicensedetails) { Write-Warning "No licenses found" }
$userlicensedetails | Format-Table -AutoSize

if ($exportpath) { 
    if (Test-Path $exportpath) {
        Write-Output "Exporting results to $exportpath"
        $exportlocation = Export-Filename -FileName $filename -ExportLocation $exportpath 
        $userlicensedetails | Export-Csv -Path $exportlocation -NoTypeInformation 
    }
    else { Write-Warning "$exportpath not found! Results have not been exported!" }
}
else { Write-Warning "No -exportpath parameter provided, results have not be exported" }

