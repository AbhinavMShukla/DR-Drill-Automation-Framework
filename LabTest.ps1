# ==============================================================================
# AUDITOR-COMPLIANT DR DRILL AUTOMATION & INTERACTIVE REPORTING ENGINE v1.1

# ==============================================================================

Clear-Host
Write-Host "==============================================" -ForegroundColor Green
Write-Host "   DR DRILL INTERACTIVE AUDIT ENGINE v1.1     " -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

# 1. PATH & ENVIRONMENT CONFIGURATION
# ------------------------------------------------------------------------------
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { 
    $ScriptDir = "C:\DR_Drill" 
    Write-Host "[!] Warning: Script root path not detected. Using default location: $ScriptDir" -ForegroundColor Yellow
} 

$DataDir     = "$ScriptDir\Data"
$InputDir    = "$ScriptDir\Input"
$EvidenceDir = "$ScriptDir\Evidence"
$LogDir      = "$ScriptDir\Logs"

if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
if (-not (Test-Path $EvidenceDir)) { New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null }
if (-not (Test-Path "$EvidenceDir\html_report")) { New-Item -ItemType Directory -Path "$EvidenceDir\html_report" -Force | Out-Null }
if (-not (Test-Path "$EvidenceDir\pdf_report")) { New-Item -ItemType Directory -Path "$EvidenceDir\pdf_report" -Force | Out-Null }

$dnsServerFile = "$InputDir\dns_servers.txt"
$csvPath       = "$InputDir\DNS_Change_list.csv" 
$logoPath      = "$DataDir\logo.png"
$watermark     = "$DataDir\watermark.png"
$logCsvPath    = "$LogDir\DNS_Change_History.csv"
$crqFile       = "$InputDir\crq_ticket.txt"

$ProdDNSServer = "PRODDNS01"
$DrDNSServer   = "DRDNS01"

if (-not (Test-Path $csvPath)) {
    Write-Host "`n[CRITICAL ERROR]: DNS Change List CSV file not found!" -ForegroundColor Red
    Read-Host "`nPress Enter to exit..."
    Exit
}

# READ CRQ TICKET FROM TEXT FILE
if (Test-Path $crqFile) {
    $CRQNumber = (Get-Content $crqFile -TotalCount 1).Trim()
} else {
    $CRQNumber = "NOT_SPECIFIED"
}

# FETCH SERVERS FROM TEXT FILE
if (Test-Path $dnsServerFile) {
    $fileContent = Get-Content $dnsServerFile
    foreach ($line in $fileContent) {
        $cleanLine = $line.Trim()
        if ($cleanLine -and $cleanLine.Contains(",")) {
            $parts = $cleanLine.Split(",")
            $ip = $parts[0].Trim()
            $desc = $parts[1].Trim()
            if ($desc -match "Production|Prod") { $ProdDNSServer = "$desc ($ip)" }
            if ($desc -match "DR") { $DrDNSServer = "$desc ($ip)" }
        }
    }
}

# Dynamic DNS Verification Server Menu
$dnsList = @()
if (Test-Path $dnsServerFile) {
    $menuIndex = 1
    $fileContent = Get-Content $dnsServerFile
    Write-Host "`n[1] Select Verification DNS Server for Live NSLOOKUP:" -ForegroundColor Cyan
    foreach ($line in $fileContent) {
        $cleanLine = $line.Trim()
        if ($cleanLine -and $cleanLine.Contains(",")) {
            $parts = $cleanLine.Split(",")
            if ($parts.Count -ge 2) {
                $dnsList += [PSCustomObject]@{ Index = $menuIndex; IP = $parts[0].Trim(); Description = $parts[1].Trim() }
                Write-Host "$menuIndex. Query via $($parts[1].Trim()) ($($parts[0].Trim()))"
                $menuIndex++
            }
        }
    }
}

if ($dnsList.Count -gt 0) {
    $dnsChoice = Read-Host "Enter choice (1 to $($dnsList.Count))"
    $selectedServer = $dnsList | Where-Object { $_.Index -eq $dnsChoice.Trim() }
    $DnsServer = if ($selectedServer) { $selectedServer.IP } else { $dnsList[0].IP }
} else {
    $DnsServer = "172.17.124.15"
}

Write-Host "`n[2] Select DR Drill Stage / Report Type:" -ForegroundColor Cyan
Write-Host "1. Pre DR Drill Report (Verification Only)"
Write-Host "2. Execute DR Failover (With Interactive Dry Run + Update)"
Write-Host "3. Execute Rollback (With Interactive Dry Run + Restore)"
Write-Host "4. Generate Final Consolidated Closeout Report (5-Appendix Complete Ledger)"
$stageChoice = Read-Host "Enter choice (1/2/3/4)"

$ExecuteChange  = $false
$Mode           = "Verification"
$ExecutionMode  = "Verification Only"

switch ($stageChoice) {
    "1" { 
        $ReportName = "Pre-Drill DNS Resolution Report"; $TitleTag = "Evidence of DNS Records Verification Prior to Drill Execution"; $ExecutionMode = "Verification Only"
        $ConclusionText = "The DNS records included in the DR Drill scope were successfully validated. The environment was confirmed to be ready for the planned DR Drill activities."
        $PurposeText = "This report documents the results of DNS Lookup of all the hosts which planned for DR mbaseline verification activities performed prior to the Disaster Recovery (DR) Drill. The objective was to check and establish an unalterable pre-drill baseline of core infrastructure DNS A records."
        $ScopeText = "<li>Verification of DNS A records listed in the approved DR Drill scope.</li><li>Validation of DNS resolution from the designated verification DNS server.</li>"
        $SummaryText = "<li>DNS A records were reviewed against the approved DR Drill inventory.</li><li>Post-change DNS resolution validation was performed for all in-scope records to establish a clear baseline.</li>"
    }
    "2" { 
        $ReportName = "Post DR Drill Report"; $TitleTag = "Evidence of DNS change to DR Failover"; $ExecuteChange = $true; $Mode = "Failover"; $ExecutionMode = "Failover Mode"
        $ConclusionText = "The DNS failover activities were completed and validated successfully. The majority of in-scope records resolved to the expected DR IP addresses, demonstrating the effectiveness of the DR failover process."
        $PurposeText = "This report documents the activities performed during the Disaster Recovery (DR) Drill, including DNS failover execution and subsequent validation checks."
        $ScopeText = "<li>Execution of DNS failover from Production to DR environment.</li><li>Validation of DNS resolution from the designated verification DNS server.</li>"
        $SummaryText = "<li>DNS updates were executed only when the current DNS record matched the expected source IP address.</li><li>Post-change DNS resolution validation was performed for all in-scope records.</li>"
    }
    "3" { 
        $ReportName = "Rollback after DR Drill Report"; $TitleTag = "Evidence of Successful Reversion to Primary Environment"; $ExecuteChange = $true; $Mode = "Rollback"; $ExecutionMode = "Rollback Mode"
        $ConclusionText = "The rollback activities were completed successfully, and the DNS records were restored to their designated Production IP addresses."
        $PurposeText = "This report documents the activities performed during the Disaster Recovery (DR) Drill, including DNS rollback execution and subsequent validation checks."
        $ScopeText = "<li>Execution of DNS rollback to Production environment.</li><li>Validation of DNS resolution from the designated verification DNS server.</li>"
        $SummaryText = "<li>DNS updates were executed to restore records back to production IPs.</li><li>Post-change DNS resolution validation was performed for all restored records.</li>"
    }
    "4" { 
        $ReportName = "DR Drill Closeout Report"; $TitleTag = "Failover Validation, Rollback Verification, and Key Outcomes"; $ExecutionMode = "Consolidated Summary"
        $ConclusionText = "The end-to-end operational lifecycle of the Disaster Recovery (DR) Drill has been successfully concluded. Validation and reconciliation performed across baseline discovery, failover execution, and primary site rollback confirm the infrastructure has been restored to its intended operational state."
        $PurposeText = "This Master Closeout Report provides a consolidated record of all activities performed throughout the Disaster Recovery (DR) Drill lifecycle. The report incorporates five historical lifecycle phases as appendices, providing complete traceability."
        $ScopeText = "Consolidated review of all infrastructure phases:<li> Pre-Drill DNS Verification<li>Failover Execution (From Production to DR) <li>Post Failover DNS Verification, <li>Rollback Execution (from DR to Production) <li>Post-Rollback DNS Verification.</li>"
        $SummaryText = "All state transitions and configuration changes were validated against recorded execution logs and verification checkpoints. Activities were performed in accordance with approved DR procedures, ensuring that each transition occurred under verified conditions and that infrastructure services were successfully restored to their intended operational state."
    }
}

$timestamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$reportDate   = Get-Date -Format "dd-MMM-yyyy"

$HtmlFile     = "$EvidenceDir\html_report\${ReportName}_$timestamp.html"
$PdfFile      = "$EvidenceDir\pdf_report\${ReportName}_$timestamp.pdf"

$edgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edgePath)) { $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" }

try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $ExecutedBy = (Get-ADUser $env:USERNAME -Properties DisplayName).DisplayName
} catch {
    $ExecutedBy = (Get-CimInstance Win32_UserAccount | Where-Object { $_.Name -eq $env:USERNAME }).FullName
}
if (-not $ExecutedBy) { $ExecutedBy = $env:USERNAME }

$csvRecords = Import-Csv -Path $csvPath
$firstRow = $csvRecords[0]
$domainHeader = ($firstRow.psobject.Properties.Name | Where-Object { $_ -match "DomainName|Domain|FQDN|Hostname" }) | Select-Object -First 1

$TotalRecords = $csvRecords.Count
$UpdatedCount = 0; $SkippedCount = 0; $FailedCount = 0
$PassCount    = 0; $FailCount    = 0

# TIMESTAMPS FOR LIFECYCLE TRACKING
$PreCheckTime   = "Pending"
$ExecutionTime  = "Pending"
$PostCheckTime  = "Pending"
$TimelineHtml   = ""

# LIVE EXECUTION LOG READERS
$Table1Results = @()
$Table2Results = @()
$Table3Results = @()
$FailureExceptions = @()

# OPTION 4 FIVE-APPENDIX HISTORICAL LEDGERS
$Opt4_AppA = @()
$Opt4_AppB = @()
$Opt4_AppC = @()
$Opt4_AppD = @()
$Opt4_AppE = @()


# 2. OPERATIONAL ENGINE & INTERACTIVE DRY RUN GATEKEEPER
# ------------------------------------------------------------------------------
if ($stageChoice -ne "4") {
    
    $PreCheckTime = Get-Date -Format "dd-MMM-yyyy HH:mm:ss"
    
    Write-Host "`n[⚙] Processing Network Resource Records..." -ForegroundColor Cyan
    foreach ($row in $csvRecords) {
        $fqdn = $row.$domainHeader
        if (-not $fqdn) { continue }
        $prodIP = $row.ProductionIP.Trim()
        $drIP   = $row.DR_IP.Trim()
        
        $t1Expected = if ($ExecutionMode -match "Rollback") { $drIP } else { $prodIP }
        try {
            $Resolve1 = Resolve-DnsName -Name $fqdn -Server $DnsServer -ErrorAction Stop
            $allIPs1 = $Resolve1 | Where-Object { $_.IPAddress } | ForEach-Object { $_.IPAddress.Trim() }
            $vStatus1 = if ($allIPs1 -contains $t1Expected) { "PASS" } else { "FAIL" }
            
            $envTags1 = @()
            foreach ($ip in $allIPs1) {
                if ($ip -eq $prodIP) { $envTags1 += "Production" }
                elseif ($ip -eq $drIP) { $envTags1 += "DR Zone" }
                else { $envTags1 += "Unknown" }
            }
            $resolvedEnv1 = $envTags1 -join " / "
            $actualIPs1   = $allIPs1 -join "<br>"
            
            $Table1Results += [PSCustomObject]@{ FQDN = $fqdn; Expected = $t1Expected; Actual = $actualIPs1; Env = $resolvedEnv1; Verify = $vStatus1 }
        } catch {
            $Table1Results += [PSCustomObject]@{ FQDN = $fqdn; Expected = $t1Expected; Actual = "Query Failed"; Env = "Timeout/Host Down"; Verify = "FAIL" }
            $vStatus1 = "FAIL"
        }
    }

    if ($ExecuteChange) {
        Write-Host "`n[🔍] RUNNING INTERACTIVE DRY RUN (PRE-FLIGHT VALIDATION CHECK)..." -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Yellow
        
        $DryRunLedger = @()
        foreach ($row in $csvRecords) {
            $fqdn = $row.$domainHeader
            if (-not $fqdn) { continue }
            $prodIP = $row.ProductionIP.Trim()
            $drIP   = $row.DR_IP.Trim()
            
            $sourceIP = if ($Mode -eq "Failover") { $prodIP } else { $drIP }
            $targetIP = if ($Mode -eq "Failover") { $drIP } else { $prodIP }
            $parts = $fqdn.Split(".")
            $hostname = $parts[0]
            $zoneName = ""
            
            $currentIP = "Query Failed"
            $Possible  = "Yes"
            $Reason    = "DNS Record can be change"

            try {
                for ($i = 1; $i -lt $parts.Length; $i++) {
                    $testZone = ($parts[$i..($parts.Length-1)]) -join "."
                    if (Get-DnsServerZone -Name $testZone -ErrorAction SilentlyContinue) { $zoneName = $testZone; break }
                }
                if (-not $zoneName) { $zoneName = ($parts[1..($parts.Length-1)]) -join "." }

                $currentRecords = Get-DnsServerResourceRecord -ZoneName $zoneName -Name $hostname -RRType "A" -ErrorAction SilentlyContinue
                if ($currentRecords) {
                    $anyRecordIPs = $currentRecords | ForEach-Object { $_.RecordData.IPv4Address.ToString().Trim() }
                    $currentIP = $anyRecordIPs -join ", "
                    
                    if ($anyRecordIPs -contains $targetIP) {
                        $Possible = "No"
                        $Reason   = "Skipped: Target IP ($targetIP) already active."
                    } elseif (-not ($anyRecordIPs -contains $sourceIP)) {
                        $Possible = "Warning"
                        $Reason   = "Source IP Mismatch! Active IP is $currentIP (Expected: $sourceIP)."
                    }
                } else {
                    $Possible = "No"
                    $Reason   = "Record '$hostname' not found inside Zone '$zoneName'."
                }
            } catch {
                $Possible = "No"
                $Reason   = $_.Exception.Message
            }

            $DryRunLedger += [PSCustomObject]@{
                "FQDN / Hostname"  = $fqdn
                "Current Active IP" = $currentIP
                "Required Target"  = $targetIP
                "Change Possible?" = $Possible
                "Auditor Reason"   = $Reason
            }
        }

        $DryRunLedger | Format-Table -AutoSize -Wrap
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Yellow

        $UserConfirmation = Read-Host "[?] Do you want to execute these changes inside Active Directory DNS? (Y/N)"
        if ($UserConfirmation.ToUpper().Trim() -ne "Y") {
            Write-Host "`n[X] CRITICAL: Change Execution Aborted by User. No modifications were made." -ForegroundColor Red
            Read-Host "`nPress Enter to exit..."
            Exit
        }
        
        Write-Host "`n[🚀] Confirmation Approved! Initiating Live Modification Engine..." -ForegroundColor Green
        $ExecutionTime = Get-Date -Format "dd-MMM-yyyy HH:mm:ss"
        
        foreach ($row in $csvRecords) {
            $fqdn = $row.$domainHeader
            if (-not $fqdn) { continue }
            $prodIP = $row.ProductionIP.Trim()
            $drIP   = $row.DR_IP.Trim()
            
            $sourceIP = if ($Mode -eq "Failover") { $prodIP } else { $drIP }
            $targetIP = if ($Mode -eq "Failover") { $drIP } else { $prodIP }
            $parts = $fqdn.Split(".")
            $hostname = $parts[0]
            $zoneName = ""
            $ExecResult = "PENDING"; $Reason = ""

            try {
                for ($i = 1; $i -lt $parts.Length; $i++) {
                    $testZone = ($parts[$i..($parts.Length-1)]) -join "."
                    if (Get-DnsServerZone -Name $testZone -ErrorAction SilentlyContinue) { $zoneName = $testZone; break }
                }
                if (-not $zoneName) { $zoneName = ($parts[1..($parts.Length-1)]) -join "." }

                $currentRecords = Get-DnsServerResourceRecord -ZoneName $zoneName -Name $hostname -RRType "A" -ErrorAction SilentlyContinue
                $matchingRecord = $currentRecords | Where-Object { $_.RecordData.IPv4Address -eq $sourceIP }
                $anyRecordIPs   = $currentRecords | ForEach-Object { $_.RecordData.IPv4Address.ToString().Trim() }

                if ($matchingRecord) {
                    Remove-DnsServerResourceRecord -ZoneName $zoneName -Name $hostname -RRType "A" -RecordData $sourceIP -Force -ErrorAction Stop
                    Add-DnsServerResourceRecordA -Name $hostname -ZoneName $zoneName -IPv4Address $targetIP -ErrorAction Stop
                    $ExecResult = "Changed"; $UpdatedCount++
                    $Reason = if ($Mode -eq "Failover") { "Changed to DR." } else { "Restored to Prod." }
                    
                    $logEntry = [PSCustomObject]@{
                        FQDN            = $fqdn
                        Old_IP          = $sourceIP
                        New_IP          = $targetIP
                        Change_DateTime = (Get-Date -Format "dd-MMM-yyyy HH:mm:ss")
                        Changed_By      = $ExecutedBy
                    }
                    $logEntry | Export-Csv -Path $logCsvPath -Append -NoTypeInformation
                    
                } elseif ($anyRecordIPs -contains $targetIP) {
                    $ExecResult = "SKIPPED"; $SkippedCount++
                    $Reason = if ($Mode -eq "Failover") { "Already on DR Zone." } else { "Already on Prod. Zone." }
                } else {
                    $ExecResult = "SKIPPED"; $Reason = "IP mismatch/stale entry."; $SkippedCount++
                }
            } catch {
                $ExecResult = "FAILED"; $Reason = $_.Exception.Message; $FailedCount++
            }
            $Table2Results += [PSCustomObject]@{ FQDN = $fqdn; SourceIP = $sourceIP; TargetIP = $targetIP; Result = $ExecResult; Reason = $Reason }
        }
    }

    if ($stageChoice -ne "1") {
        $PostCheckTime = Get-Date -Format "dd-MMM-yyyy HH:mm:ss"
        
        foreach ($row in $csvRecords) {
            $fqdn = $row.$domainHeader
            if (-not $fqdn) { continue }
            $prodIP = $row.ProductionIP.Trim()
            $drIP   = $row.DR_IP.Trim()
            
            $t3Expected = if ($ExecutionMode -match "Failover") { $drIP } else { $prodIP }
            
            try {
                $Resolve3 = Resolve-DnsName -Name $fqdn -Server $DnsServer -ErrorAction Stop
                $allIPs3 = $Resolve3 | Where-Object { $_.IPAddress } | ForEach-Object { $_.IPAddress.Trim() }
                $vStatus3 = if ($allIPs3 -contains $t3Expected) { "PASS" } else { "FAIL" }

                $envTags3 = @()
                foreach ($ip in $allIPs3) {
                    if ($ip -eq $prodIP) { $envTags3 += "Production" }
                    elseif ($ip -eq $drIP) { $envTags3 += "DR Zone" }
                    else { $envTags3 += "Unknown" }
                }
                $resolvedEnv3 = $envTags3 -join " / "
                $actualIPs3   = $allIPs3 -join "<br>"

                if ($vStatus3 -eq "PASS") { $PassCount++ } 
                else { 
                    $FailCount++
                    $FailureExceptions += [PSCustomObject]@{ FQDN = $fqdn; Expected = $t3Expected; Actual = $actualIPs3; Reason = "DNS replication pending or record mismatch." }
                }
                $Table3Results += [PSCustomObject]@{ FQDN = $fqdn; Expected = $t3Expected; Actual = $actualIPs3; Env = $resolvedEnv3; Verify = $vStatus3 }
            } catch {
                $vStatus3 = "FAIL"; $FailCount++
                $FailureExceptions += [PSCustomObject]@{ FQDN = $fqdn; Expected = $t3Expected; Actual = "--"; Reason = "Timeout / host unresolvable." }
                $Table3Results += [PSCustomObject]@{ FQDN = $fqdn; Expected = $t3Expected; Actual = "Query Failed"; Env = "Timeout/Host Down"; Verify = "FAIL" }
            }
        }
    } else {
        foreach ($r in $Table1Results) {
            if ($r.Verify -eq "PASS") { $PassCount++ } else { 
                $FailCount++
                $FailureExceptions += [PSCustomObject]@{ FQDN = $r.FQDN; Expected = $r.Expected; Actual = $r.Actual; Reason = "Pre-check resolution mismatched or host down." }
            }
        }
    }
} else {
    Write-Host "`n[🔍] Parsing historical HTML logs for 5-Appendix Consolidated Ledger..." -ForegroundColor Yellow
    
    $LatestPreFile      = Get-ChildItem -Path $EvidenceDir\html_report -Filter "Pre DR Drill Report_*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $LatestFailoverFile = Get-ChildItem -Path $EvidenceDir\html_report -Filter "Post DR Drill Report_*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $LatestRollbackFile = Get-ChildItem -Path $EvidenceDir\html_report -Filter "Rollback after DR Drill Report_*.html" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    $PreHTML      = if ($LatestPreFile) { Get-Content $LatestPreFile.FullName -Raw } else { "" }
    $FailoverHTML = if ($LatestFailoverFile) { Get-Content $LatestFailoverFile.FullName -Raw } else { "" }
    $RollbackHTML = if ($LatestRollbackFile) { Get-Content $LatestRollbackFile.FullName -Raw } else { "" }

    $PreCheckTime  = if ($LatestPreFile) { $LatestPreFile.LastWriteTime.ToString("dd-MMM-yyyy HH:mm:ss") } else { "No Log Found" }
    $FailoverTime  = if ($LatestFailoverFile) { $LatestFailoverFile.LastWriteTime.ToString("dd-MMM-yyyy HH:mm:ss") } else { "No Log Found" }
    $RollbackTime  = if ($LatestRollbackFile) { $LatestRollbackFile.LastWriteTime.ToString("dd-MMM-yyyy HH:mm:ss") } else { "No Log Found" }

    # DYNAMIC 1ST PAGE TIMELINE FOR OPTION 4
    $TimelineHtml = @"
<div class='section-box'>
    <div class='section-title-top'>DR Drill Phase Execution Timeline</div>
    <table class='info-table' style='margin-bottom: 0;'><tr style="background-color:#d9eaf7; color:#1f4e79;">
    <td style="width:70%; padding:8px; border:1px solid #b7c9d6;"><strong>Activity</strong></td>
    <td style="padding:8px; border:1px solid #b7c9d6;"><strong>Timeline</strong></td></tr>
    <tr style='background-color: #f8f9fa;'><td style='width:70%;'><strong>Phase 1: Pre-Drill Verification Production IP Baseline</strong></td><td><strong>$PreCheckTime</strong></td></tr>
    <tr style='background-color: #ffffff;'><td><strong>Phase 2: DR Failover Execution (Change to DR)</strong></td><td><strong>$FailoverTime</strong></td></tr>
    <tr style='background-color: #f8f9fa;'><td><strong>Phase 3: Rollback Primary Restoration (Changes revert to Production) </strong></td><td><strong>$RollbackTime</strong></td></tr>
    </table>
</div>
"@

    foreach ($row in $csvRecords) {
        $fqdn = $row.$domainHeader
        if (-not $fqdn) { continue }
        $prodIP = $row.ProductionIP.Trim()
        $drIP   = $row.DR_IP.Trim()

        $fqdnEscaped = [regex]::Escape($fqdn)
        $prodIPEscaped = [regex]::Escape($prodIP)
        $drIPEscaped = [regex]::Escape($drIP)

        # App A
        $t1Status = "NO LOG"; $t1Actual = "--"; $t1Env = "--"; $t1Class = "status-skip"
        $patternA = "<td>$fqdnEscaped<\/td><td>$prodIPEscaped<\/td><td>([\s\S]*?)<\/td><td[^>]*>([\s\S]*?)<\/td><td class='(status-pass|status-fail|status-skip)'>([^<]*)<\/td>"
        if ($PreHTML -and ($PreHTML -match $patternA)) {
            $t1Actual = $Matches[1]; $t1Env = $Matches[2]; $t1Class = $Matches[3]; $t1Status = $Matches[4]
        }

        # App B
        $t2Status = "NO LOG"; $t2Remarks = "--"; $t2Class = "status-skip"
        $patternB = "<td>$fqdnEscaped<\/td><td>$prodIPEscaped<\/td><td>$drIPEscaped<\/td><td class='(status-pass|status-skip|status-fail)'>([^<]*)<\/td><td>([\s\S]*?)<\/td>"
        if ($FailoverHTML -and ($FailoverHTML -match $patternB)) {
            $t2Class = $Matches[1]; $t2Status = $Matches[2]; $t2Remarks = $Matches[3]
        }

        # App C
        $t3Status = "NO LOG"; $t3Actual = "--"; $t3Env = "--"; $t3Class = "status-skip"
        $patternC = "Appendix C: DNS Verification Results[\s\S]*?<td>$fqdnEscaped<\/td><td>$drIPEscaped<\/td><td>([\s\S]*?)<\/td><td[^>]*>([\s\S]*?)<\/td><td class='(status-pass|status-fail|status-skip)'>([^<]*)<\/td>"
        if ($FailoverHTML -and ($FailoverHTML -match $patternC)) {
            $t3Actual = $Matches[1]; $t3Env = $Matches[2]; $t3Class = $Matches[3]; $t3Status = $Matches[4]
        }

        # App D
        $t4Status = "NO LOG"; $t4Remarks = "--"; $t4Class = "status-skip"
        $patternD = "<td>$fqdnEscaped<\/td><td>$drIPEscaped<\/td><td>$prodIPEscaped<\/td><td class='(status-pass|status-skip|status-fail)'>([^<]*)<\/td><td>([\s\S]*?)<\/td>"
        if ($RollbackHTML -and ($RollbackHTML -match $patternD)) {
            $t4Class = $Matches[1]; $t4Status = $Matches[2]; $t4Remarks = $Matches[3]
        }

        # App E
        $t5Status = "NO LOG"; $t5Actual = "--"; $t5Env = "--"; $t5Class = "status-skip"
        $patternE = "Appendix C: DNS Verification Results[\s\S]*?<td>$fqdnEscaped<\/td><td>$prodIPEscaped<\/td><td>([\s\S]*?)<\/td><td[^>]*>([\s\S]*?)<\/td><td class='(status-pass|status-fail|status-skip)'>([^<]*)<\/td>"
        if ($RollbackHTML -and ($RollbackHTML -match $patternE)) {
            $t5Actual = $Matches[1]; $t5Env = $Matches[2]; $t5Class = $Matches[3]; $t5Status = $Matches[4]
        }

        if ($t5Status -eq "PASS") { $PassCount++ } elseif ($t5Status -eq "FAIL") { $FailCount++ } else { $SkippedCount++ }

        $Opt4_AppA += [PSCustomObject]@{ FQDN = $fqdn; Expected = $prodIP; Actual = $t1Actual; Env = $t1Env; Status = $t1Status; Class = $t1Class }
        $Opt4_AppB += [PSCustomObject]@{ FQDN = $fqdn; Source = $prodIP; Target = $drIP; Status = $t2Status; Remarks = $t2Remarks; Class = $t2Class }
        $Opt4_AppC += [PSCustomObject]@{ FQDN = $fqdn; Expected = $drIP; Actual = $t3Actual; Env = $t3Env; Status = $t3Status; Class = $t3Class }
        $Opt4_AppD += [PSCustomObject]@{ FQDN = $fqdn; Source = $drIP; Target = $prodIP; Status = $t4Status; Remarks = $t4Remarks; Class = $t4Class }
        $Opt4_AppE += [PSCustomObject]@{ FQDN = $fqdn; Expected = $prodIP; Actual = $t5Actual; Env = $t5Env; Status = $t5Status; Class = $t5Class }
    }
}

$SuccessRate = if ($TotalRecords -gt 0) { [Math]::Round(($PassCount / $TotalRecords) * 100, 2) } else { 0.00 }


# 3. HTML STRUCTURING PIPELINE & CSS ENGINE
# ------------------------------------------------------------------------------
$cssLogoPath = $watermark.Replace('\', '/')

# SETUP DYNAMIC ANCHOR ROUTING CHANNELS
$PassLink = "#post-check-section"
$FailLink = "#exceptions-section"
$SkipLink = "#execution-section"

if ($stageChoice -eq "1") {
    $PassLink = "#pre-check-section"
    $SkipLink = "#exceptions-section"
} elseif ($stageChoice -eq "4") {
    $PassLink = "#rollback-check-section"
    $FailLink = "#rollback-check-section"
    $SkipLink = "#execution-section"
}

$css = @"
<style>
@page { 
    size: A4 portrait; 
    margin: 20mm 15mm 20mm 15mm;
      }
/* Fixed Bottom-Left Logo for Table Pages to avoid overlaps */
.fixed-logo-bottom {
    position: fixed;
    bottom: 1mm;
    left: -1mm;
    height: 45px;
    opacity: 0.6;
    z-index: 9999;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
}
body::before {
    content: "";
    position: fixed;
    bottom: 0px;         
    right: 0px;        
    width: 90px;        
    height: 90px;       
    background-image: url('$cssLogoPath'); 
    background-repeat: no-repeat;
    background-position: center;
    background-size: contain;
    opacity: 0.6;    
    z-index: -1000;   
    pointer-events: none;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
}

body { 
    font-family: 'Segoe UI', Arial, sans-serif; 
    background-color: transparent !important; 
    margin: 0; 
    color: #2C3E50; 
    font-size: 11px; 
    line-height: 1.5;
    -webkit-print-color-adjust: exact !important;
    print-color-adjust: exact !important;
}

/* COVER PAGE SPECIFIC STYLES */
.cover-logo {
    height: 75px;
    margin-bottom: 30px;
}
.cover-wrapper {
    height: 75vh;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    text-align: center;
    border: 1px solid #2c3e50;
    border-radius: 4px;
    padding: 30px;
    margin-top: 5mm;
}
.cover-title {
    font-size: 24px;
    font-weight: bold;
    text-transform: uppercase;
    color: #2c3e50;
    margin-bottom: 5px;
    letter-spacing: 0.5px;
}
.cover-subtitle {
    font-size: 12px;
    color: #7f8c8d;
    text-transform: uppercase;
    font-weight: 600;
    margin-bottom: 40px;
    border-bottom: 1px solid #2c3e50;
    padding-bottom: 12px;
    width: 65%;
}
.cover-meta-box {
    text-align: left;
    background-color: #f8f9fa;
    border: 1px solid #e2e8f0;
    border-radius: 4px;
    padding: 15px 20px;
    width: 65%;
    margin-bottom: 30px;
}
.cover-meta-item {
    font-size: 13px;
    margin-bottom: 6px;
    color: #34495e;
}
.cover-meta-label {
    font-weight: bold;
    color: #2c3e50;
    display: inline-block;
    width: 160px;
}
.cover-scope-box {
    width: 65%;
    text-align: left;
}
.cover-scope-title {
    font-weight: bold;
    margin-bottom: 5px;
    text-transform: uppercase;
    color: #2c3e50;
    font-size: 11px;
}

/* DETAILS PAGE STYLES */
.title-block { text-align: center; margin-bottom: 20px; background: transparent !important; }
.title-block h1 { margin: 0; color: #2c3e50; font-size: 18px; text-transform: uppercase; letter-spacing: 0.5px; font-weight: bold; }
.title-block p { margin: 4px 0 0 0; font-size: 10px; color: #7f8c8d; font-weight: bold; text-transform: uppercase; }

.section-box { border: 1px solid #e2e8f0; border-radius: 4px; padding: 10px 12px; margin-bottom: 12px; background-color: transparent !important; page-break-inside: avoid; }
.section-title-top { font-size: 11px; color: #2c3e50; font-weight: bold; text-transform: uppercase; margin-bottom: 4px; border-bottom: 1px solid #e2e8f0; padding-bottom: 2px; }
.section-box p { margin: 0 0 4px 0; text-align: justify; }
.section-box ul { margin: 2px 0 0 0; padding-left: 15px; }
.section-box li { margin-bottom: 2px; }

.dashboard { display: flex; justify-content: space-between; margin-bottom: 15px; gap: 6px; background: transparent !important; page-break-inside: avoid; }
.dashboard a { flex: 1 1 0; text-decoration: none; color: inherit !important; display: block; }
.card { border-radius: 3px; padding: 6px; text-align: center; color: #ffffff !important; font-weight: bold; font-size: 10px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); height: 100%; box-sizing: border-box; }

.card-pass { background: linear-gradient(135deg, #27ae60, #2ec46f); }
.card-fail { background: linear-gradient(135deg, #c0392b, #e74c3c); }
.card-skip { background: linear-gradient(135deg, #d35400, #f39c12); }
.card-rate { background: linear-gradient(135deg, #2980b9, #3498db); }
.card-value { font-size: 15px; font-weight: bold; margin-top: 1px; display: block; color: #ffffff !important; }
.section-title { font-size: 11px; color: #2c3e50; margin-top: 15px; margin-bottom: 6px; border-left: 3px solid #2c3e50; padding-left: 6px; font-weight: bold; text-transform: uppercase; scroll-margin-top: 25px; }

.info-table { width: 100%; border-collapse: collapse; margin-bottom: 12px; font-size: 10.5px; background-color: transparent !important; }
.info-table th { background-color: #2c3e50 !important; color: #fff !important; padding: 5px 7px; font-weight: 600; text-align: left; border: 1px solid #ddd; text-transform: uppercase; font-size: 9.5px; }
.info-table td { padding: 5px 7px; border: 1px solid #ddd; vertical-align: middle; }

.status-pass { background-color: #d4edda !important; color: #155724 !important; font-weight: bold; text-align: center; }
.status-fail { background-color: #f8d7da !important; color: #721c24 !important; font-weight: bold; text-align: center; }
.status-skip { background-color: #fff3cd !important; color: #856404 !important; font-weight: bold; text-align: center; }

.sign-section { margin-top: 30px; display: flex; justify-content: space-between; font-size: 11px; page-break-inside: avoid; background: transparent !important; }
.sign-column { width: 28%; border-top: 1px solid #333; text-align: center; padding-top: 5px; font-weight: bold; color: #2c3e50; }
.page-break { page-break-before: always; }
</style>
"@

# BASE HTML TEMPLATE STRUCTURE
$htmlBody = @"
<div class='cover-wrapper'>
    <img class='cover-logo' src='$logoPath' alt='Corporate Logo'>
    <div class='cover-title'>$ReportName</div>
    <div class='cover-subtitle'>$TitleTag</div>
    
    <div class='cover-meta-box'>
        <div class='cover-meta-item'><span class='cover-meta-label'>Change Request (CRQ):</span> <span style='font-weight:bold; color:#2c3e50;'>$CRQNumber</span></div>
        <div class='cover-meta-item'><span class='cover-meta-label'>Generation Date:</span> <span>$reportDate</span></div>
        <div class='cover-meta-item'><span class='cover-meta-label'>Execution Mode:</span> <span>$ExecutionMode</span></div>
        <div class='cover-meta-item'><span class='cover-meta-label'>Executed By:</span> <span>$ExecutedBy</span></div>
        <div class='cover-meta-item'><span class='cover-meta-label'>Total DNS Records:</span> <span>$TotalRecords</span></div>
        <div class='cover-meta-item'><span class='cover-meta-label'>Automated by:</span> <span>Abhinav Shukla</span></div>
        <div class='cover-meta-item'><span class='cover-meta-label'>Version:</span> <span>v1.1</span></div>
        
    </div>
    <br><br><br><br><br><br>
    <div style="
    width:200px;
    margin:20px auto;
    padding:8px;
    text-align:center;
    border:2px solid #B22222;
    background:#FDECEC;
    color:#B22222;
    font-weight:bold;
    font-size:16px;
    text-transform:uppercase;
">CONFIDENTIAL</div>
</div>

<div class='page-break'></div>

<img class='fixed-logo-bottom' src='$logoPath' alt='Corporate Logo'>

<div class='title-block'>
    <h1>$ReportName</h1>
    <p>$TitleTag</p>
</div><br>

<div class='section-title'>Result Summary Dashboard</div>
<div class='dashboard'>
    <a href='$PassLink'><div class='card card-pass'>PASS / RECOVERED<span class='card-value'>$PassCount</span></div></a>
    <a href='$FailLink'><div class='card card-fail'>FAILURES<span class='card-value'>$FailCount</span></div></a>
    <a href='$SkipLink'><div class='card card-skip'>SKIPPED / UNKNOWN<span class='card-value'>$SkippedCount</span></div></a>
    <div class='card card-rate'>SUCCESS RATE<span class='card-value'>$SuccessRate%</span></div>
</div><br>


<div class='section-box'><div class='section-title-top'>Purpose</div><p>$PurposeText</p></div><br>
<div class='section-box'><div class='section-title-top'>Scope</div><ul>$ScopeText</ul></div><br>
<div class='section-box'><div class='section-title-top'>Change Summary</div><ul>$SummaryText</ul></div><br>

<div class='section-title'>Infrastructure Environments</div>
<table class='info-table'><tr><td><strong>Query run on Server:</strong> $DnsServer</td><td><strong>DR DNS Server:</strong> $DrDNSServer</td><td><strong>Production DNS Server:</strong> $ProdDNSServer</td></tr></table>

$TimelineHtml

<div class='page-break'></div>
"@

# 4. APPENDICES GENERATION WITH 25-ROW LIMIT & CONTINUOUS S.No.
# ------------------------------------------------------------------------------
if ($stageChoice -ne "4") {
    
    # Appendix A
    $htmlBody += "<section id='pre-check-section'><div class='section-title'>Appendix A: Pre-Change DNS Status Verification ($PreCheckTime)</div>"
    $htmlBody += "<table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Source IP</th><th>Actual Resolved IP</th><th>Resolution Zone</th><th>Verification</th></tr>"
    
    $rowCountA = 0
    $sNoA = 1
    foreach ($r in $Table1Results) {
        if ($rowCountA -gt 0 -and $rowCountA % 30 -eq 0) {
            $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Source IP</th><th>Actual Resolved IP</th><th>Resolution Zone</th><th>Verification</th></tr>"
        }
        $vClass = if ($r.Verify -eq "PASS") { "status-pass" } else { "status-fail" }
        $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td style='font-weight:600;'>{4}</td><td class='{5}'>{6}</td></tr>" -f $sNoA, $r.FQDN, $r.Expected, $r.Actual, $r.Env, $vClass, $r.Verify
        $rowCountA++
        $sNoA++
    }
    $htmlBody += "</table></section>"

    if ($ExecuteChange) {
        # Appendix B
        $htmlBody += "<div class='page-break'></div><section id='execution-section'><div class='section-title'>Appendix B: Change Execution Details ($ExecutionTime)</div>"
        $htmlBody += "<table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Source IP</th><th>Target IP</th><th>Execution Result</th><th>Remarks</th></tr>"
        
        $rowCountB = 0
        $sNoB = 1
        foreach ($r in $Table2Results) {
            if ($rowCountB -gt 0 -and $rowCountB % 30 -eq 0) {
                $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Source IP</th><th>Target IP</th><th>Execution Result</th><th>Remarks</th></tr>"
            }
            $eClass = if ($r.Result -eq "UPDATED") { "status-pass" } elseif ($r.Result -eq "SKIPPED") { "status-skip" } else { "status-fail" }
            $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td class='{4}'>{5}</td><td>{6}</td></tr>" -f $sNoB, $r.FQDN, $r.SourceIP, $r.TargetIP, $eClass, $r.Result, $r.Reason
            $rowCountB++
            $sNoB++
        }
        $htmlBody += "</table></section>"

        # Appendix C
        $htmlBody += "<div class='page-break'></div><section id='post-check-section'><div class='section-title'>Appendix C: DNS Verification Results ($PostCheckTime)</div>"
        $htmlBody += "<table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected IP</th><th>Actual Resolved IP</th><th>Resolution Zone</th><th>Verification</th></tr>"
        
        $rowCountC = 0
        $sNoC = 1
        foreach ($r in $Table3Results) {
            if ($rowCountC -gt 0 -and $rowCountC % 30 -eq 0) {
                $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected IP</th><th>Actual Resolved IP</th><th>Resolution Zone</th><th>Verification</th></tr>"
            }
            $vClass = if ($r.Verify -eq "PASS") { "status-pass" } else { "status-fail" }
            $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td style='font-weight:600;'>{4}</td><td class='{5}'>{6}</td></tr>" -f $sNoC, $r.FQDN, $r.Expected, $r.Actual, $r.Env, $vClass, $r.Verify
            $rowCountC++
            $sNoC++
        }
        $htmlBody += "</table></section>"
    }

    # Exception Log
    $exceptionHeaderName = if ($stageChoice -eq "1") { "Appendix B: Failures and Exceptions Log ($PreCheckTime)" } else { "Appendix D: Failures and Exceptions Log ($PostCheckTime)" }
    $htmlBody += "<div class='page-break'></div><section id='exceptions-section'><div class='section-title'>{0}</div>" -f $exceptionHeaderName
    
    if ($FailureExceptions.Count -gt 0) {
        $htmlBody += "<table class='info-table'><thead><tr style='background-color: #c0392b;'><th style='color: #fff;'>S.No.</th><th style='color: #fff;'>🔴 FQDN / Hostname</th><th style='color: #fff;'>Expected IP</th><th style='color: #fff;'>Actual Resolved IP</th><th style='color: #fff;'>Root Cause / Remarks</th></tr></thead><tbody>"
        $rowCountEx = 0
        $sNoEx = 1
        foreach ($ex in $FailureExceptions) {
            if ($rowCountEx -gt 0 -and $rowCountEx % 30 -eq 0) {
                $htmlBody += "</tbody></table></section><div class='page-break'></div><section><table class='info-table'><thead><tr style='background-color: #c0392b;'><th style='color: #fff;'>S.No.</th><th style='color: #fff;'>🔴 FQDN / Hostname</th><th style='color: #fff;'>Expected IP</th><th style='color: #fff;'>Actual Resolved IP State</th><th style='color: #fff;'>Root Cause / Remarks</th></tr></thead><tbody>"
            }
            $htmlBody += "<tr><td>{0}</td><td style='font-weight:bold; color:#c0392b;'>{1}</td><td>{2}</td><td style='color:#721c24; font-weight:bold;'>{3}</td><td><em>{4}</em></td></tr>" -f $sNoEx, $ex.FQDN, $ex.Expected, $ex.Actual, $ex.Reason
            $rowCountEx++
            $sNoEx++
        }
        $htmlBody += "</tbody></table>"
    } else {
        $htmlBody += "<p style='color:#27ae60; font-weight:bold; margin:0; font-size:11px;'>✔ Zero exceptions encountered. Infrastructure alignment fully compliant.</p>"
    }
    $htmlBody += "</section>"
} 
else {
    # MASTER 5-APPENDIX LEDGER COMPLIANCE ENGINE (OPTION 4)
    
    # App A
    $htmlBody += "<section id='pre-check-section'><div class='section-title'>Appendix A: Pre-Drill Verification Baseline Log ($PreCheckTime)</div><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Prod. IP</th><th>Actual Resolved IP</th><th>Resolutione Zone</th><th>Status</th></tr>"
    $rCount = 0; $sNo = 1
    foreach ($r in $Opt4_AppA) { 
        if ($rCount -gt 0 -and $rCount % 30 -eq 0) { $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Prod. IP</th><th>Actual Resolved IP</th><th>Resolutione Zone</th><th>Status</th></tr>" }
        $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td style='font-weight:600;'>{4}</td><td class='{5}'>{6}</td></tr>" -f $sNo, $r.FQDN, $r.Expected, $r.Actual, $r.Env, $r.Class, $r.Status
        $rCount++; $sNo++
    }
    $htmlBody += "</table></section><div class='page-break'></div>"

    # App B
    $htmlBody += "<section id='execution-section'><div class='section-title'>Appendix B: Live DR Failover Execution Ledger ($FailoverTime)</div><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Source Prod IP</th><th>Target DR IP</th><th>Execution Result</th><th>Remarks</th></tr>"
    $rCount = 0; $sNo = 1
    foreach ($r in $Opt4_AppB) { 
        if ($rCount -gt 0 -and $rCount % 30 -eq 0) { $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Source Prod IP</th><th>Target DR IP</th><th>Execution Result</th><th>Remarks</th></tr>" }
        $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td class='{4}'>{5}</td><td>{6}</td></tr>" -f $sNo, $r.FQDN, $r.Source, $r.Target, $r.Class, $r.Status, $r.Remarks
        $rCount++; $sNo++
    }
    $htmlBody += "</table></section><div class='page-break'></div>"

    # App C
    $htmlBody += "<section id='post-check-section'><div class='section-title'>Appendix C: DNS Resolution Verification Status after Failover ($FailoverTime)</div><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected DR IP</th><th>Actual Resolved IP</th><th>Resolution Zone</th><th>Verification</th></tr>"
    $rCount = 0; $sNo = 1
    foreach ($r in $Opt4_AppC) { 
        if ($rCount -gt 0 -and $rCount % 30 -eq 0) { $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected DR IP</th><th>Actual Resolved IP</th><th>Resolution Zone</th><th>Verification</th></tr>" }
        $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td style='font-weight:600;'>{4}</td><td class='{5}'>{6}</td></tr>" -f $sNo, $r.FQDN, $r.Expected, $r.Actual, $r.Env, $r.Class, $r.Status
        $rCount++; $sNo++
    }
    $htmlBody += "</table></section><div class='page-break'></div>"

    # App D
    $htmlBody += "<section id='rollback-exec-section'><div class='section-title'>Appendix D: Live Rollback Restoration Ledger ($RollbackTime)</div><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Source DR IP</th><th>Target Prod IP</th><th>Execution Result</th><th>Remarks</th></tr>"
    $rCount = 0; $sNo = 1
    foreach ($r in $Opt4_AppD) { 
        if ($rCount -gt 0 -and $rCount % 30 -eq 0) { $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Source DR IP</th><th>Target Prod IP</th><th>Execution Result</th><th>Remarks</th></tr>" }
        $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td class='{4}'>{5}</td><td>{6}</td></tr>" -f $sNo, $r.FQDN, $r.Source, $r.Target, $r.Class, $r.Status, $r.Remarks
        $rCount++; $sNo++
    }
    $htmlBody += "</table></section><div class='page-break'></div>"

    # App E
    $htmlBody += "<section id='rollback-check-section'><div class='section-title'>Appendix E: Final Production DNS Resolution Status after Rollback ($RollbackTime)</div><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Production IP</th><th>Actual Resolved IP State</th><th>Resolved Environment</th><th>Final Reconciliation Status</th></tr>"
    $rCount = 0; $sNo = 1
    foreach ($r in $Opt4_AppE) { 
        if ($rCount -gt 0 -and $rCount % 30 -eq 0) { $htmlBody += "</table></section><div class='page-break'></div><section><table class='info-table'><tr><th>S.No.</th><th>FQDN / Hostname</th><th>Expected Production IP</th><th>Actual Resolved IP State</th><th>Resolved Environment</th><th>Final Reconciliation Status</th></tr>" }
        $htmlBody += "<tr><td>{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td style='font-weight:600;'>{4}</td><td class='{5}'>{6}</td></tr>" -f $sNo, $r.FQDN, $r.Expected, $r.Actual, $r.Env, $r.Class, $r.Status
        $rCount++; $sNo++
    }
    $htmlBody += "</table></section><div class='page-break'></div>"
}

# SIGNATURE SECTION AT THE VERY END OF THE DOCUMENT - ONLY FOR OPTION 4
if ($stageChoice -eq "4") {
    $htmlBody += @"
<div><B>Conclusion: </b>$ConclusionText<br><br></div>

<div class='title-block' style='margin-top: 20mm;'>
    <h1>Audit Closeout Sign-off</h1>
    <p>Authorized Infrastructure Verification Signatures</p>
</div>
<br><br><br>
<div class='sign-section'>
    <div class='sign-column'>Executed By:<br><span style='font-weight:normal; color:#555; font-size:10px;'>$ExecutedBy</span></div>
    <div class='sign-column'>Reviewed By:<br><span style='font-weight:normal; color:#555; font-size:10px;'>IT Infrastructure Manager</span></div>
    <div class='sign-column'>Approved By:<br><span style='font-weight:normal; color:#555; font-size:10px;'>Head of Department</span></div>
</div>



"@
}

# Compile and Save HTML File
$rawHtml = ConvertTo-Html -Head $css -Body $htmlBody
($rawHtml -replace '&lt;br&gt;', '<br>') | Out-File $HtmlFile -Encoding UTF8

# --- LIVE OUTPUT AND RENDERING PIPELINE ---
Write-Host "`n[🌐] HTML Report compiled successfully: $HtmlFile" -ForegroundColor Green

if (Test-Path $edgePath) {
    Write-Host "[🖨️] Compiling Audit PDF via Headless Edge..." -ForegroundColor Yellow
    
    
    $edgeArgs = "--headless=new --disable-gpu --print-to-pdf --print-to-pdf=`"$PdfFile`" `"$HtmlFile`""
       
    Start-Process -FilePath $edgePath -ArgumentList $edgeArgs -Wait
    
    if (Test-Path $PdfFile) {
        Write-Host "[✔] PDF generated successfully: $PdfFile" -ForegroundColor Green
        Start-Process $PdfFile
    } else {
        Write-Host "[!] Warning: PDF creation failed. Falling back to HTML." -ForegroundColor Yellow
        Start-Process $HtmlFile
    }
} else {
    Start-Process $HtmlFile
}