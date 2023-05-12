# Author: Robin Cormie
# Website: robincormie.dev
# GitHub repository: https://github.com/rcormie/ad-automation-scripts

# The Disable-AD-UserAccounts.ps1 script takes an input CSV file containing a list of email addresses, and for each email address, retrieves the corresponding user account from Active Directory. If the user account is enabled, it is disabled and moved to a specified OU.
# The script logs the results of each action to a text file with the current date appended to the file name. The script can be customized by setting the input CSV file path, target OU path, and log file path variables.

# This script is released under the Apache License, Version 2.0
# For more information, see the file LICENSE.txt in the root directory of this repository

# Set variables for input CSV file and target OU paths
$csvFilePath = "C:\path\to\input\file.csv"
$targetOUPath = "OU=Disabled Users,OU=Transit,OU=Departments,DC=domain,DC=com"
$logFilePath = "\\server\share\Logs\$(Get-Date -Format 'yyyyMMdd').txt"

# Import the CSV file and loop through each email address
Import-Csv $csvFilePath -Header EmailAddress | ForEach-Object {

    # Get the user from Active Directory
    $user = Get-ADUser -Filter "EmailAddress -eq '$($_.EmailAddress)'" -Properties Enabled, GivenName, Surname, DistinguishedName

    # Get the SamAccountName from the user's email address
    $samAccountName = $user.UserPrincipalName.Split("@")[0]

    # If the user account is enabled, disable it
    if ($user.Enabled) {
        Write-Host "Disabling user account '$samAccountName'"
        $disableResult = Disable-ADAccount $user -ErrorAction SilentlyContinue
        if ($disableResult) {
            Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] Failed to disable user account '$samAccountName' with error code '$($disableResult.Exception.ErrorCode)'." | Out-File $logFilePath -Append
        }
        else {
            Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] User account '$samAccountName' was disabled." | Out-File $logFilePath -Append
        }
    }
    else {
        Write-Host "User account '$samAccountName' is already disabled"
    }

    # Move the user account to the target OU
    Write-Host "Moving user account '$samAccountName' from '$($user.DistinguishedName)' to '$targetOUPath'"
    $moveResult = Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOUPath -Verbose -ErrorAction SilentlyContinue
    if ($moveResult) {
        Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] Failed to move user account '$samAccountName' with error code '$($moveResult.Exception.ErrorCode)'." | Out-File $logFilePath -Append
    }
    else {
        Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] User account '$samAccountName' was moved to '$targetOUPath'." | Out-File $logFilePath -Append
    }
}
