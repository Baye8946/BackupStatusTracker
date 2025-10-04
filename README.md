# BackupStatusTracker
A BackupStatus Tracker to help MSPs keep track of data, changes on their Windows machines, and the time of recent backup processes. This script automates backup monitoring, designed for SMBs and MSPs. Tested in Windows Sandbox for reliability in restricted environments.

# Features

1. Checks .bak files in a specified path (e.g., C:\SandboxShare\Backups).
2. Reports disk space using Get-CimInstance.
3. Flags stale backups (older than specified hours).
4. Generates CSV reports for compliance (e.g., HIPAA, PCI-DSS).
5. Sandbox-compatible with local checks to avoid RPC issues.

# Setup

1. Place test.bak in **C:\SandboxShare\Backups**:


```PowerShell

New-Item -Path "C:\SandboxShare\Backups" -ItemType Directory -Force
New-Item -Path "C:\SandboxShare\Backups\test.bak" -ItemType File -Force
(Get-Item "C:\SandboxShare\Backups\test.bak").LastWriteTime = (Get-Date).AddHours(-30)
icacls "C:\SandboxShare\Backups" /grant "Everyone:(OI)(CI)F" /T
```

2. Configure SandboxConfig.wsb to map **C:\SandboxShare** and run the script.

3. Run:
   
 ```Powershell

.\BackupStatusTracker.ps1 -ComputerName $env:COMPUTERNAME -BackupPath C:\SandboxShare\Backups -Verbose -GenerateReport
```

4. View reports:
   
  ```powershell

$latestCsv = Get-ChildItem -Path C:\SandboxShare\BackupReport_*.csv | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Import-Csv -Path $latestCsv.FullName | Format-Table
```

# Debugging Journey
Resolved issues like:

* Execution policy errors with **-ExecutionPolicy Bypass**.
* Invalid BackupPath by creating directories.
* RPC server is unavailable with local Get-CimInstance.
* Syntax errors (try-catch, extra }) using brace matching.
* Missing Get-BackupStatus function with inline logic.
* Import-Csv wildcard issues by selecting the latest CSV.

# Real-World Utility
Automates backup checks for SMBs/MSPs, saving time and ensuring compliance. See my [Medium post](https://medium.com/@bayealfa8/heres-how-i-built-a-powershell-backup-monitoring-tool-using-windows-sandbox-as-a-test-ground-64a702197d30) for details.

# Next Steps
* Add email alerts for stale backups.
* Support remote servers via WinRM.
* Create HTML reports.


