# Author: Robin Cormie
# Website: robincormie.dev
# GitHub repository: https://github.com/rcormie/ad-automation-scripts

# The Cleanup-ADUserAccounts Script to remove a user from all security and distribution groups, and log the actions
# The script logs the results of each action to a text file with the current date appended to the file name. The script can be customized by setting the input CSV file path, target OU path, and log file path variables.

# This script is released under the Apache License, Version 2.0
# For more information, see the file LICENSE.txt in the root directory of this repository


# Prompt user for CSV file path
$csvPath = Read-Host "Enter path to CSV file containing email addresses (no header)"

# Import CSV
$emailList = Import-Csv -Path $csvPath -Header "Email"

# Loop through each email address in the list
foreach ($email in $emailList) {   
    Write-Host "Processing user with email: $($email.Email)"

    # Get username from email address
    $username = $email.Email.Split('@')[0]

    try {
        # Get user object from Active Directory based on username
        $user = Get-ADUser -Filter "SamAccountName -eq '$username'" -Properties SamAccountName, EmailAddress -ErrorAction Stop
    }
    catch {
        $errorMessage = "User $($email.Email) does not exist in AD."
        Write-Host "Error: $errorMessage"

        # Log error message to file
        $groupMembershipLogPath = "\\<fileservername>\Logs\$username-groupmembership-$(Get-Date -Format 'yyyy-MM-dd').txt"
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] $errorMessage" | Out-File -Append $groupMembershipLogPath
        continue
    }

    Write-Host "Retrieved user object for email $($email.Email), SamAccountName is $($user.SamAccountName)"

    # Get the log file paths
    $groupMembershipLogPath = "\\<fileservername>\Logs\$($user.SamAccountName.ToLower())-groupmembership-$(Get-Date -Format 'yyyy-MM-dd').txt"
    $adCleanupLogPath = "\\<fileservername>\Logs\$($user.SamAccountName.ToLower())-adcleanup-$(Get-Date -Format 'yyyy-MM-dd').txt"

    # Get list of security and distribution groups the user is a member of (exclude Domain Users group)
    $groupList = Get-ADPrincipalGroupMembership $user | Where-Object { $_.Name -ne "Domain Users" }

    # Log group membership to file
    $groupList.Name | Sort-Object | Out-File -Append $groupMembershipLogPath

    # Loop through each group and remove the user from it
    foreach ($group in $groupList) {
        Write-Verbose "Removing group $($group.Name) from $($user.SamAccountName)"
        Remove-ADGroupMember -Identity $group -Members $user -Confirm:$false -ErrorAction Stop 
    }

    # Log actions to file
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] User $username group memberships log file saved to: $groupMembershipLogPath" | Out-File -Append $adCleanupLogPath
    if ($groupList) {
        $groupNames = $groupList.Name -join ', '
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [SUCCESS] User $username removed from $($groupList.Count) groups: $groupNames" | Out-File -Append $adCleanupLogPath

        Write-Host "Writing cleanup log file to: $adCleanupLogPath"
    }
}
