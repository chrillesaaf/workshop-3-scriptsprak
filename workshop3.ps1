#Read Json-data
$data = Get-Content -Path "ad_export.json" -Raw  -Encoding UTF8 | ConvertFrom-Json

$now = Get-Date
$formattedNow = $now.ToString("yyyy-MM-dd HH:mm")
$30_days = $now.AddDays(30)
$more_than_30_days = $now.AddDays(-30)

# Filter users with expiring accounts
$expiringUsers = foreach ($user in $data.users) {
    if ($user.accountExpires) {
        $expiryDate = [datetime]::Parse($user.accountExpires)
        if ($expiryDate -ge $today -and $expiryDate -le $30_days) {
            $user
        }
    }
}

$expiringCount = $expiringUsers.Count

# Filter user who haven´t logged in for 30+ days
$inactiveUsers = foreach ($user in $data.users) {
    if ($user.lastLogon) {
        $lastLogonDate = [datetime]::Parse($user.lastLogon)
        if ($LastLogonDate -lt $more_than_30_days) {
            $user
        }
    }
}

$inactiveCount = $inactiveUsers.Count

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
"@


#Save report
$report | Out-File -FilePath "ad_audit_report.txt" -Encoding UTF8
