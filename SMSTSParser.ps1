# SMSTS Log Parser
# Author: Assistant
# Version: 3.0
# Description: Modern SMSTS log parser with advanced analysis capabilities

#Requires -Version 7.0
#Requires -RunAsAdministrator

using namespace System.Windows.Forms
using namespace System.Drawing

# Import required modules
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
Import-Module Microsoft.PowerShell.Management -ErrorAction Stop

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuration
$script:Config = @{
    LogPath = Join-Path $PSScriptRoot "logs"
    TempPath = Join-Path $PSScriptRoot "temp"
    ReportPath = Join-Path $PSScriptRoot "reports"
    LogFile = Join-Path $PSScriptRoot "logs\parser.log"
}

# Create necessary directories
@($Config.LogPath, $Config.TempPath, $Config.ReportPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:Config.LogFile -Value $logMessage
    
    switch ($Level) {
        'Error' { Write-Host $logMessage -ForegroundColor Red }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

# SMSTS Log Analysis Class
class SMSTSAnalyzer {
    [hashtable]$AnalysisResults
    [string]$LogContent
    [datetime]$StartTime
    [datetime]$EndTime
    [int]$TotalSteps
    [int]$SuccessSteps
    [int]$FailedSteps
    [int]$WarningCount
    [array]$ErrorCodes
    [array]$PerformanceMetrics
    
    SMSTSAnalyzer() {
        $this.AnalysisResults = @{
            SuccessSteps = @()
            FailedSteps = @()
            Warnings = @()
            Errors = @()
            Timeline = @()
            PerformanceMetrics = @{}
        }
        $this.ErrorCodes = @()
        $this.PerformanceMetrics = @()
    }
    
    [void]AnalyzeLog([string]$LogPath) {
        try {
            Write-Log "Starting analysis of log file: $LogPath"
            $this.LogContent = Get-Content -Path $LogPath -Raw
            $this.ParseLogContent()
            $this.CalculateMetrics()
            Write-Log "Analysis completed successfully"
        }
        catch {
            Write-Log "Error analyzing log: $_" -Level Error
            throw
        }
    }
    
    [void]ParseLogContent() {
        $lines = $this.LogContent -split "`n"
        foreach ($line in $lines) {
            if ($line -match '<!\[LOG\[(Success|Error|Warning)\]') {
                $timestamp = [datetime]::ParseExact($matches.Date + " " + $matches.Time, "MM-dd-yyyy HH:mm:ss.fff", $null)
                $message = $matches.Message
                
                switch ($matches[1]) {
                    'Success' {
                        $this.AnalysisResults.SuccessSteps += [PSCustomObject]@{
                            Time = $timestamp
                            Message = $message
                        }
                        $this.SuccessSteps++
                    }
                    'Error' {
                        $this.AnalysisResults.FailedSteps += [PSCustomObject]@{
                            Time = $timestamp
                            Message = $message
                            ErrorCode = $matches.ErrorCode
                        }
                        $this.FailedSteps++
                        if ($matches.ErrorCode) {
                            $this.ErrorCodes += $matches.ErrorCode
                        }
                    }
                    'Warning' {
                        $this.AnalysisResults.Warnings += [PSCustomObject]@{
                            Time = $timestamp
                            Message = $message
                        }
                        $this.WarningCount++
                    }
                }
                
                $this.AnalysisResults.Timeline += [PSCustomObject]@{
                    Time = $timestamp
                    Type = $matches[1]
                    Message = $message
                }
            }
        }
    }
    
    [void]CalculateMetrics() {
        $this.TotalSteps = $this.SuccessSteps + $this.FailedSteps
        $this.StartTime = ($this.AnalysisResults.Timeline | Sort-Object Time | Select-Object -First 1).Time
        $this.EndTime = ($this.AnalysisResults.Timeline | Sort-Object Time | Select-Object -Last 1).Time
        
        # Calculate performance metrics
        $this.AnalysisResults.PerformanceMetrics = @{
            TotalDuration = $this.EndTime - $this.StartTime
            SuccessRate = if ($this.TotalSteps -gt 0) { ($this.SuccessSteps / $this.TotalSteps) * 100 } else { 0 }
            AverageStepDuration = if ($this.TotalSteps -gt 0) { ($this.EndTime - $this.StartTime).TotalSeconds / $this.TotalSteps } else { 0 }
        }
    }
}

# UI Class
class SMSTSParserUI {
    [Form]$MainForm
    [SMSTSAnalyzer]$Analyzer
    [Button]$SelectFileButton
    [Button]$AnalyzeButton
    [Button]$ExportButton
    [TabControl]$TabControl
    [TabPage]$SummaryTab
    [TabPage]$DetailsTab
    [TabPage]$TimelineTab
    
    SMSTSParserUI() {
        $this.Analyzer = [SMSTSAnalyzer]::new()
        $this.InitializeUI()
    }
    
    [void]InitializeUI() {
        $this.MainForm = New-Object Form
        $this.MainForm.Text = "SMSTS Log Parser"
        $this.MainForm.Size = New-Object Size(1200, 800)
        $this.MainForm.StartPosition = [FormStartPosition]::CenterScreen
        
        # Create controls
        $this.CreateControls()
        $this.SetupLayout()
    }
    
    [void]CreateControls() {
        # Buttons
        $this.SelectFileButton = New-Object Button
        $this.SelectFileButton.Text = "Select Log File"
        $this.SelectFileButton.Size = New-Object Size(200, 30)
        $this.SelectFileButton.Add_Click({ $this.SelectLogFile() })
        
        $this.AnalyzeButton = New-Object Button
        $this.AnalyzeButton.Text = "Analyze Log"
        $this.AnalyzeButton.Size = New-Object Size(200, 30)
        $this.AnalyzeButton.Enabled = $false
        $this.AnalyzeButton.Add_Click({ $this.AnalyzeLog() })
        
        $this.ExportButton = New-Object Button
        $this.ExportButton.Text = "Export Report"
        $this.ExportButton.Size = New-Object Size(200, 30)
        $this.ExportButton.Enabled = $false
        $this.ExportButton.Add_Click({ $this.ExportReport() })
        
        # Tabs
        $this.TabControl = New-Object TabControl
        $this.TabControl.Dock = [DockStyle]::Fill
        
        $this.SummaryTab = New-Object TabPage
        $this.SummaryTab.Text = "Summary"
        
        $this.DetailsTab = New-Object TabPage
        $this.DetailsTab.Text = "Details"
        
        $this.TimelineTab = New-Object TabPage
        $this.TimelineTab.Text = "Timeline"
    }
    
    [void]SetupLayout() {
        $leftPanel = New-Object Panel
        $leftPanel.Dock = [DockStyle]::Left
        $leftPanel.Width = 220
        
        $leftPanel.Controls.Add($this.SelectFileButton)
        $leftPanel.Controls.Add($this.AnalyzeButton)
        $leftPanel.Controls.Add($this.ExportButton)
        
        $this.TabControl.TabPages.Add($this.SummaryTab)
        $this.TabControl.TabPages.Add($this.DetailsTab)
        $this.TabControl.TabPages.Add($this.TimelineTab)
        
        $this.MainForm.Controls.Add($leftPanel)
        $this.MainForm.Controls.Add($this.TabControl)
    }
    
    [void]SelectLogFile() {
        $dialog = New-Object OpenFileDialog
        $dialog.Filter = "SMSTS Log Files (*.log)|*.log|All Files (*.*)|*.*"
        $dialog.Title = "Select SMSTS Log File"
        
        if ($dialog.ShowDialog() -eq [DialogResult]::OK) {
            try {
                $this.Analyzer.AnalyzeLog($dialog.FileName)
                $this.AnalyzeButton.Enabled = $true
                Write-Log "Log file selected: $($dialog.FileName)"
            }
            catch {
                Write-Log "Error selecting log file: $_" -Level Error
                [MessageBox]::Show("Error loading log file: $_", "Error", [MessageBoxButtons]::OK, [MessageBoxIcon]::Error)
            }
        }
    }
    
    [void]AnalyzeLog() {
        try {
            $this.UpdateUI()
            $this.ExportButton.Enabled = $true
            Write-Log "Analysis completed successfully"
        }
        catch {
            Write-Log "Error during analysis: $_" -Level Error
            [MessageBox]::Show("Error during analysis: $_", "Error", [MessageBoxButtons]::OK, [MessageBoxIcon]::Error)
        }
    }
    
    [void]UpdateUI() {
        $this.UpdateSummaryTab()
        $this.UpdateDetailsTab()
        $this.UpdateTimelineTab()
    }
    
    [void]UpdateSummaryTab() {
        $this.SummaryTab.Controls.Clear()
        
        $summaryText = @"
Analysis Summary
---------------
Total Steps: $($this.Analyzer.TotalSteps)
Successful Steps: $($this.Analyzer.SuccessSteps)
Failed Steps: $($this.Analyzer.FailedSteps)
Warnings: $($this.Analyzer.WarningCount)

Performance Metrics
------------------
Total Duration: $($this.Analyzer.AnalysisResults.PerformanceMetrics.TotalDuration)
Success Rate: $([math]::Round($this.Analyzer.AnalysisResults.PerformanceMetrics.SuccessRate, 2))%
Average Step Duration: $([math]::Round($this.Analyzer.AnalysisResults.PerformanceMetrics.AverageStepDuration, 2)) seconds

Error Analysis
-------------
Unique Error Codes: $($this.Analyzer.ErrorCodes.Count)
"@
        
        $label = New-Object Label
        $label.Text = $summaryText
        $label.AutoSize = $true
        $label.Location = New-Object Point(10, 10)
        
        $this.SummaryTab.Controls.Add($label)
    }
    
    [void]UpdateDetailsTab() {
        $this.DetailsTab.Controls.Clear()
        
        $listView = New-Object ListView
        $listView.Dock = [DockStyle]::Fill
        $listView.View = [View]::Details
        $listView.Columns.Add("Time", 150)
        $listView.Columns.Add("Status", 100)
        $listView.Columns.Add("Message", 500)
        
        foreach ($step in $this.Analyzer.AnalysisResults.Timeline) {
            $item = New-Object ListViewItem($step.Time.ToString())
            $item.SubItems.Add($step.Type)
            $item.SubItems.Add($step.Message)
            $listView.Items.Add($item)
        }
        
        $this.DetailsTab.Controls.Add($listView)
    }
    
    [void]UpdateTimelineTab() {
        $this.TimelineTab.Controls.Clear()
        
        $chart = New-Object Chart
        $chart.Dock = [DockStyle]::Fill
        
        # Add chart implementation here
        
        $this.TimelineTab.Controls.Add($chart)
    }
    
    [void]ExportReport() {
        $dialog = New-Object SaveFileDialog
        $dialog.Filter = "HTML Report (*.html)|*.html|CSV Report (*.csv)|*.csv"
        $dialog.Title = "Export Analysis Report"
        
        if ($dialog.ShowDialog() -eq [DialogResult]::OK) {
            try {
                switch ([System.IO.Path]::GetExtension($dialog.FileName)) {
                    '.html' { $this.ExportHTMLReport($dialog.FileName) }
                    '.csv' { $this.ExportCSVReport($dialog.FileName) }
                }
                Write-Log "Report exported successfully to: $($dialog.FileName)"
            }
            catch {
                Write-Log "Error exporting report: $_" -Level Error
                [MessageBox]::Show("Error exporting report: $_", "Error", [MessageBoxButtons]::OK, [MessageBoxIcon]::Error)
            }
        }
    }
    
    [void]ExportHTMLReport([string]$Path) {
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>SMSTS Log Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .success { color: green; }
        .failure { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary { background-color: #f9f9f9; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>SMSTS Log Analysis Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Steps: $($this.Analyzer.TotalSteps)</p>
        <p>Successful Steps: $($this.Analyzer.SuccessSteps)</p>
        <p>Failed Steps: $($this.Analyzer.FailedSteps)</p>
        <p>Warnings: $($this.Analyzer.WarningCount)</p>
        <p>Success Rate: $([math]::Round($this.Analyzer.AnalysisResults.PerformanceMetrics.SuccessRate, 2))%</p>
        <p>Total Duration: $($this.Analyzer.AnalysisResults.PerformanceMetrics.TotalDuration)</p>
    </div>
    
    <h2>Detailed Analysis</h2>
    <table>
        <tr>
            <th>Time</th>
            <th>Status</th>
            <th>Message</th>
        </tr>
"@
        
        foreach ($step in $this.Analyzer.AnalysisResults.Timeline) {
            $class = switch ($step.Type) {
                'Success' { 'success' }
                'Error' { 'failure' }
                'Warning' { 'warning' }
            }
            $html += "<tr class='$class'><td>$($step.Time)</td><td>$($step.Type)</td><td>$($step.Message)</td></tr>"
        }
        
        $html += @"
    </table>
</body>
</html>
"@
        
        $html | Out-File -Path $Path -Encoding UTF8
    }
    
    [void]ExportCSVReport([string]$Path) {
        $csvData = $this.Analyzer.AnalysisResults.Timeline | ForEach-Object {
            [PSCustomObject]@{
                Time = $_.Time
                Status = $_.Type
                Message = $_.Message
            }
        }
        
        $csvData | Export-Csv -Path $Path -NoTypeInformation
    }
    
    [void]Show() {
        $this.MainForm.ShowDialog()
    }
}

# Main execution
try {
    Write-Log "Starting SMSTS Log Parser"
    $ui = [SMSTSAnalyzerUI]::new()
    $ui.Show()
    Write-Log "Application closed successfully"
}
catch {
    Write-Log "Fatal error: $_" -Level Error
    [MessageBox]::Show("Fatal error: $_", "Error", [MessageBoxButtons]::OK, [MessageBoxIcon]::Error)
} 