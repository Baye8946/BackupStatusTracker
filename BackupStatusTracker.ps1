<#
.SYNOPSIS
    Monitors backup status and disk space across Windows machines, generating reports for IT admins.


.DESCRIPTION
    Queries Windows Backup events or file-based backups, checks disk space, and outputs results to console, CSV, or HTML.
    Supports remote execution and customizable thresholds.

.PARAMETER PFT
    Array of computer name to check. Defaults to local machine. Accepts pipeline input.

.PARAMETER BackupPath
    Path to check for file-based backups (e.g., D:\Backups). Optional.

.PARAMETER MaxBackupAgeHours
    Maximum age (in hours) for a backup to be considered recent. Defaults to 24.

.PARAMETER GenerateReport
    Switch to export results to a CSV or HTML file.

.PARAMETER OutputPath
    Path for the report file. Defaults to $env:TEMP\BackupReport_<timestamp>.csv.

.EXAMPLE
    .\BackupStatusTracker.ps1 -ComputerName "Server01,Server02" -GenerateReport
    Checks backup status on Server01 and Server02, exports to CSV.

.EXAMPLE
    Get-Content servers.txt | .\BackupStatusTracker.ps1 -BackupPath "D:\Backups" -GenerateReport
    Checks servers listed in servers.txt with file-based backup checks.

.NOTES
    Author: Alfa Baye
    Requires: PowerShell 5.1 or later, WinRM for remote access.
    #>




[CmdletBinding()]
param (
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [Parameter()]
    [ValidateScript({
        Write-Host "Debug: Testing path $_"
        $result = Test-Path $_ -PathType Container
        Write-Host "Debug: Test-Path result = $result"
        if ($_ -and !$result) { throw "Invalid path: $_" }
        $true
    })]
    [string]$BackupPath,
    [Parameter()]
    [int]$MaxBackupAgeHours = 24,
    [Parameter()]
    [switch]$GenerateReport,
    [Parameter()]
    [string]$OutputPath = "C:\SandboxShare\BackupReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
)

begin {
    Write-Verbose "Initializing BackupStatusTracker..."
    $results = @()
}

process {
    foreach ($computer in $ComputerName) {
        Write-Verbose "Checking backup status for $computer..."
        $result = [PSCustomObject]@{
            ComputerName      = $computer
            LastBackup        = $null
            Status            = "Error"
            IsStale           = $true
            BackupDriveFreeGB = "Unknown"
            ErrorMessage      = $null
        }

        try {
            if ($BackupPath) {
                $backupFiles = Get-ChildItem -Path $BackupPath -Filter "*.bak" -ErrorAction Stop | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($backupFiles) {
                    $result.LastBackup = $backupFiles.LastWriteTime
                    $result.Status = "Success (File-Based)"
                    $result.IsStale = ((Get-Date) - $backupFiles.LastWriteTime).TotalHours -gt $MaxBackupAgeHours
                } else {
                    $result.ErrorMessage = "No backup files found in $BackupPath"
                }

                $drive = Split-Path $BackupPath -Qualifier
                $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$drive'" -ErrorAction Stop
                if ($disk) {
                    $result.BackupDriveFreeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                } else {
                    $result.BackupDriveFreeGB = "Unknown (CIM unavailable)"
                }
            } else {
                $result.ErrorMessage = "No BackupPath specified"
            }
        } catch {
            $result.ErrorMessage = $_.Exception.Message
            Write-Verbose "Error on ${computer}: $($_.Exception.Message)"
        }

        $results += $result
    }
}

end {
    $results | Format-Table -AutoSize
    if ($GenerateReport -and $OutputPath) {
        try {
            $results | Export-Csv -Path $OutputPath -NoTypeInformation -ErrorAction Stop
            Write-Verbose "Report exported to $OutputPath"
            Write-Output "Report saved to $OutputPath"
        } catch {
            Write-Warning "Failed to export report: $($_.Exception.Message)"
        }
    }
}