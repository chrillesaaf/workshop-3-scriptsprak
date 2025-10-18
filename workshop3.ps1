#Read Json-data
$data = Get-Content -Path "ad_export.json" -Raw  -Encoding UTF8 | ConvertFrom-Json

# Set up date variables
$now = Get-Date
$formattedNow = $now.ToString("yyyy-MM-dd HH:mm")
$dateFormat = "yyyy-MM-dd HH:mm"
$30_days = $now.AddDays(30)
$more_than_30_days = $now.AddDays(-30)

# Filter users with expiring accounts
$expiringUsers = foreach ($user in $data.users) {
    if ($user.accountExpires) {
        $expiryDate = [datetime]::Parse($user.accountExpires)
        if ($expiryDate -ge $now -and $expiryDate -le $30_days) {
            $user
        }
    }
}
$expiringCount = $expiringUsers.Count

# Filter users who haven't logged in for 30+ days
$inactiveUsers = foreach ($user in $data.users) {
    if ($user.lastLogon) {
        $lastLogonDate = [datetime]::Parse($user.lastLogon)
        if ($lastLogonDate -lt $more_than_30_days) {
            $daysInactive = ($now - $lastLogonDate).Days
            $user | Add-Member -NotePropertyName DaysInactive -NotePropertyValue $daysInactive
            $user
        }
    }
}
$inactiveCount = $inactiveUsers.Count

# Create an empty hashtable to store department counts
$department_counts = @{}

# Loop through all users
foreach ($user in $data.users) {
    $dept = $user.department

    if ($dept) {
        if ($department_counts.ContainsKey($dept)) {
            $department_counts[$dept] += 1
        }
        else {
            $department_counts[$dept] = 1
        }
    }
}

#Make report
$report = @"
===================================================================================
ACTIVE DIRECTORY AUDIT REPORT
===================================================================================
Generated: $formattedNow
Domain: $($data.domain)
Export Date: $($data.export_date)
`nEXECUTIVE SUMMARY
------------------------------------------------------------------------------------
⚠ CRITICAL: $expiringCount user account(s) expiring within 30 days
⚠ WARNING: $inactiveCount user account(s) have not logged in for over 30 days

`nINACTIVE USERS (No login >30 days)
----------------------------------------------------------------------------------------
Username       Name                    Department    Last Login           Days Inactive`n
"@

# Sort the inactive users by DaysInactive descending
$sortedInactiveUsers = $inactiveUsers | Sort-Object -Property DaysInactive -Descending
foreach ($user in $sortedinactiveUsers) {
    $user.lastLogon = [datetime]::Parse($user.lastLogon).ToString($dateFormat)
    $report += "{0,-15}{1,-24}{2,-14}{3,-13}{4,8}`n" -f `
        $user.samAccountName, $user.displayName, $user.department, $user.lastLogon, $user.DaysInactive
}
$report += @"
`nUSER COUNT PER DEPARTMENT
-------------------------------------------------------`n
"@

foreach ($dept in $department_counts.Keys) {
    $report += "{0,-12}{1,8} users`n" -f $dept, $department_counts[$dept]
}
$report += @"
`nCOMPUTER STATUS
-------------------------------------------------------`n
"@
#Save report
$report | Out-File -FilePath "ad_audit_report.txt" -Encoding UTF8
