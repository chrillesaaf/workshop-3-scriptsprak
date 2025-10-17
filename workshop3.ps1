#Read Json-data
$data = Get-Content -Path "ad_export.json" -Raw  -Encoding UTF8 | ConvertFrom-Json

$now = Get-Date
$formattedNow = $now.ToString("yyyy-MM-dd HH:mm")

#Make report
$report = @"
===================================================================================
ACTIVE DIRECTORY AUDIT REPORT
===================================================================================
Generated: $formattedNow
Domain: $($data.domain)
Export Date: $($data.export_date)
"@


#Save report
$report | Out-File -FilePath "ad_audit_report.txt"
