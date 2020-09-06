# Get-AzureUserLicenseToggleDetails.ps1
Retrieves the O365 Licenses assigned to the input users. This allows capturing the license assigments and is good for reporting or before making a major change that affects users in the tenant.

More information is detailed in this blog article:
https://cipriandroc.wordpress.com/2020/09/05/get-azurelicensetoggledetails-ps1/

Usage examples:

- EXAMPLE:
C:\PS> .\Get-AzureUserLicenseToggleDetails.ps1 -userlist user@domain.com
Lists the licenses assigned to the specified user, if any, along with their subtoggles.

- EXAMPLE:
C:\PS> .\Get-AzureUserLicenseToggleDetails.ps1 -userlist user@domain.com,user2@domain.com,user3 -ExportLocation C:\Data\Output
Lists the licenses for all the three specified users, if any, along with their subtoggles. User3 that's missing the domain is getting the default domain value added
ExportLocation specifies the location where the report is generated, the script already handles the filename, and adds the date to it as well.
Warning! It will overwrite the file, append is not enabled. The script also checks for the existing location if specified.
C:\Data\OUTPUT\09.04_licenseTogglesExport.csv
Use either C:\<folder> or C:\<folder>\ , the builtin function will detect if there's a backslash or not and handle it.

- EXAMPLE:
C:\PS> .\Get-AzureUserLicenseToggleDetails.ps1 user
Lists the licenses assigned to the specified user, if any, along with their subtoggles.
The -username positional parameter allows the user alias to be placed first, script also adds default domain to form the userPrincipalName in case it's missing.
