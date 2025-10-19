#Read Json-data
$data = Get-Content -Path "ad_export.json" -Raw  -Encoding UTF8 | ConvertFrom-Json

# Set up variables
$now = Get-Date
$formattedNow = $now.ToString("yyyy-MM-dd HH:mm")
$dateFormat = "yyyy-MM-dd HH:mm"
$specificDate = Get-Date "2025-10-14"
$less_than_7_days_ver2 = $specificDate.AddDays(-7)
$more_than_30_days_ver2 = $specificDate.AddDays(-30)
$30_days = $now.AddDays(30)
$more_than_30_days = $now.AddDays(-30)
$total_computers = $data.computers.Count
$active_computers = 0
$inactive_computers = 0
$osGroups = $data.computers | Group-Object -Property operatingSystem
$siteGroups = $data.users | Group-Object -Property site | Sort-Object Count -Descending

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

# Count computers
foreach ($computer in $data.computers) {
    if ($computer.lastLogon) {
        $lastLogon = [datetime]::Parse($computer.lastLogon)
        if ($lastLogon -ge $less_than_7_days_ver2) {
            $active_computers++
        }
        elseif ($lastLogon -lt $more_than_30_days_ver2) {
            $inactive_computers++
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
-------------------------------------------------------
Total Computers: $total_computers
Active (seen <7 days): $active_computers
Inactive (>30 days): $inactive_computers`n
"@

$report += @"
`nCOMPUTERS BY OPERATING SYSTEM
-------------------------------------------------------`n
"@
#Loop through each OS group
foreach ($group in $osGroups) {
    $os = $group.Name
    $count = $group.Count
    if ($total_computers -gt 0) {
        $percent = [math]::Round(($count / $total_computers) * 100)
    }
    else {
        $percent = 0
    }
    if ($os -like "Windows 10*") {
        $report += "{0,-25}{1,3} ({2}%) ⚠ Needs upgrade`n" -f $os, $count, $percent
    }
    else {
        $report += "{0,-25}{1,3} ({2}%)`n" -f $os, $count, $percent
    }
}
$report += @"
`nCOMPUTERS BY SITE
-------------------------------------------------------`n
"@

foreach ($group in $siteGroups) {
    $site = $group.Name
    $count = $group.Count
    $report += "{0,-18}{1,3} computer(s)`n" -f $site, $count
}

#Save report
$report | Out-File -FilePath "ad_audit_report.txt" -Encoding UTF8
