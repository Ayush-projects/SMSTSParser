# SMSTS Log Parser with Windows Forms UI
# Author: Ayush Addhyayan
# Version: 2.0
# Description: Enterprise-grade SMSTS log parser with detailed analysis and modern UI

# Ensure we're running in STA mode for Windows Forms
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    Write-Host "This script requires STA mode. Please run PowerShell with -STA parameter."
    exit
}

# Load required assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import required modules
Import-Module Microsoft.PowerShell.Utility
Import-Module Microsoft.PowerShell.Management

# Global variables
$script:logContent = $null
$script:analysisResults = @{
    SuccessSteps = @()
    FailedSteps = @()
    Warnings = @()
    Errors = @()
    Timeline = @()
    PerformanceMetrics = @{}
}

# Global form controls
$script:form = $null
$script:btnAnalyze = $null
$script:btnExport = $null
$script:tabSummary = $null
$script:tabDetails = $null
$script:tabTimeline = $null

function Initialize-UI {
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Text = "SMSTS Log Parser"
    $script:form.Size = New-Object System.Drawing.Size(1200,800)
    $script:form.StartPosition = "CenterScreen"
    
    # Create main layout
    $mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $mainLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $mainLayout.ColumnCount = 2
    $mainLayout.RowCount = 1
    $mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 30)))
    $mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 70)))
    
    # Left Panel - Controls
    $leftPanel = New-Object System.Windows.Forms.Panel
    $leftPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    
    # File Selection Button
    $btnSelectFile = New-Object System.Windows.Forms.Button
    $btnSelectFile.Text = "Select SMSTS Log File"
    $btnSelectFile.Location = New-Object System.Drawing.Point(10, 10)
    $btnSelectFile.Size = New-Object System.Drawing.Size(200, 30)
    $btnSelectFile.Add_Click({ Select-LogFile })
    
    # Analysis Button
    $script:btnAnalyze = New-Object System.Windows.Forms.Button
    $script:btnAnalyze.Text = "Analyze Log"
    $script:btnAnalyze.Location = New-Object System.Drawing.Point(10, 50)
    $script:btnAnalyze.Size = New-Object System.Drawing.Size(200, 30)
    $script:btnAnalyze.Enabled = $false
    $script:btnAnalyze.Add_Click({ Analyze-SMSTSLog })
    
    # Export Button
    $script:btnExport = New-Object System.Windows.Forms.Button
    $script:btnExport.Text = "Export Analysis"
    $script:btnExport.Location = New-Object System.Drawing.Point(10, 90)
    $script:btnExport.Size = New-Object System.Drawing.Size(200, 30)
    $script:btnExport.Enabled = $false
    $script:btnExport.Add_Click({ Export-Analysis })
    
    # Add controls to left panel
    $leftPanel.Controls.Add($btnSelectFile)
    $leftPanel.Controls.Add($script:btnAnalyze)
    $leftPanel.Controls.Add($script:btnExport)
    
    # Right Panel - Results
    $rightPanel = New-Object System.Windows.Forms.TabControl
    $rightPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    
    # Create tabs
    $script:tabSummary = New-Object System.Windows.Forms.TabPage
    $script:tabSummary.Text = "Summary"
    
    $script:tabDetails = New-Object System.Windows.Forms.TabPage
    $script:tabDetails.Text = "Detailed Analysis"
    
    $script:tabTimeline = New-Object System.Windows.Forms.TabPage
    $script:tabTimeline.Text = "Timeline"
    
    # Add tabs to control
    $rightPanel.TabPages.Add($script:tabSummary)
    $rightPanel.TabPages.Add($script:tabDetails)
    $rightPanel.TabPages.Add($script:tabTimeline)
    
    # Add panels to main layout
    $mainLayout.Controls.Add($leftPanel, 0, 0)
    $mainLayout.Controls.Add($rightPanel, 1, 0)
    
    # Add main layout to form
    $script:form.Controls.Add($mainLayout)
    
    return $script:form
}

function Select-LogFile {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "SMSTS Log Files (*.log)|*.log|All Files (*.*)|*.*"
    $openFileDialog.Title = "Select SMSTS Log File"
    
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:logContent = Get-Content $openFileDialog.FileName
        $script:btnAnalyze.Enabled = $true
        Update-Status "Log file loaded successfully"
    }
}

function Analyze-SMSTSLog {
    if ($null -eq $script:logContent) {
        Show-Message "Please select a log file first" "Error"
        return
    }
    
    # Clear previous results
    $script:analysisResults = @{
        SuccessSteps = @()
        FailedSteps = @()
        Warnings = @()
        Errors = @()
        Timeline = @()
        PerformanceMetrics = @{}
    }
    
    # Analyze log content
    foreach ($line in $script:logContent) {
        # Success steps
        if ($line -match '<!\[LOG\[Success\]') {
            $script:analysisResults.SuccessSteps += [PSCustomObject]@{
                Time = [datetime]::ParseExact($matches.Date + " " + $matches.Time, "MM-dd-yyyy HH:mm:ss.fff", $null)
                Message = $matches.Message
            }
        }
        
        # Failed steps
        if ($line -match '<!\[LOG\[Error\]') {
            $script:analysisResults.FailedSteps += [PSCustomObject]@{
                Time = [datetime]::ParseExact($matches.Date + " " + $matches.Time, "MM-dd-yyyy HH:mm:ss.fff", $null)
                Message = $matches.Message
                ErrorCode = $matches.ErrorCode
            }
        }
        
        # Warnings
        if ($line -match '<!\[LOG\[Warning\]') {
            $script:analysisResults.Warnings += [PSCustomObject]@{
                Time = [datetime]::ParseExact($matches.Date + " " + $matches.Time, "MM-dd-yyyy HH:mm:ss.fff", $null)
                Message = $matches.Message
            }
        }
    }
    
    # Update UI with results
    Update-AnalysisUI
    $script:btnExport.Enabled = $true
}

function Update-AnalysisUI {
    # Update Summary Tab
    $summaryText = "Analysis Summary`n`n"
    $summaryText += "Total Steps: $($script:analysisResults.SuccessSteps.Count + $script:analysisResults.FailedSteps.Count)`n"
    $summaryText += "Successful Steps: $($script:analysisResults.SuccessSteps.Count)`n"
    $summaryText += "Failed Steps: $($script:analysisResults.FailedSteps.Count)`n"
    $summaryText += "Warnings: $($script:analysisResults.Warnings.Count)`n"
    
    $script:tabSummary.Controls.Clear()
    $summaryLabel = New-Object System.Windows.Forms.Label
    $summaryLabel.Text = $summaryText
    $summaryLabel.AutoSize = $true
    $summaryLabel.Location = New-Object System.Drawing.Point(10, 10)
    $script:tabSummary.Controls.Add($summaryLabel)
    
    # Update Details Tab
    $script:tabDetails.Controls.Clear()
    $detailsListView = New-Object System.Windows.Forms.ListView
    $detailsListView.Dock = [System.Windows.Forms.DockStyle]::Fill
    $detailsListView.View = [System.Windows.Forms.View]::Details
    $detailsListView.Columns.Add("Time", 150)
    $detailsListView.Columns.Add("Status", 100)
    $detailsListView.Columns.Add("Message", 500)
    
    foreach ($step in $script:analysisResults.SuccessSteps) {
        $item = New-Object System.Windows.Forms.ListViewItem($step.Time.ToString())
        $item.SubItems.Add("Success")
        $item.SubItems.Add($step.Message)
        $detailsListView.Items.Add($item)
    }
    
    foreach ($step in $script:analysisResults.FailedSteps) {
        $item = New-Object System.Windows.Forms.ListViewItem($step.Time.ToString())
        $item.SubItems.Add("Failed")
        $item.SubItems.Add($step.Message)
        $detailsListView.Items.Add($item)
    }
    
    $script:tabDetails.Controls.Add($detailsListView)
}

function Export-Analysis {
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "HTML Report (*.html)|*.html|CSV Report (*.csv)|*.csv"
    $saveFileDialog.Title = "Export Analysis Report"
    
    if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $extension = [System.IO.Path]::GetExtension($saveFileDialog.FileName)
        switch ($extension) {
            ".html" { Export-HTMLReport $saveFileDialog.FileName }
            ".csv" { Export-CSVReport $saveFileDialog.FileName }
        }
    }
}

function Export-HTMLReport {
    param($filePath)
    
    $html = @"
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; }
            .success { color: green; }
            .failure { color: red; }
            .warning { color: orange; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }
        </style>
    </head>
    <body>
        <h1>SMSTS Log Analysis Report</h1>
        <h2>Summary</h2>
        <p>Total Steps: $($script:analysisResults.SuccessSteps.Count + $script:analysisResults.FailedSteps.Count)</p>
        <p>Successful Steps: $($script:analysisResults.SuccessSteps.Count)</p>
        <p>Failed Steps: $($script:analysisResults.FailedSteps.Count)</p>
        <p>Warnings: $($script:analysisResults.Warnings.Count)</p>
        
        <h2>Detailed Analysis</h2>
        <table>
            <tr>
                <th>Time</th>
                <th>Status</th>
                <th>Message</th>
            </tr>
"@
    
    foreach ($step in $script:analysisResults.SuccessSteps) {
        $html += "<tr class='success'><td>$($step.Time)</td><td>Success</td><td>$($step.Message)</td></tr>"
    }
    
    foreach ($step in $script:analysisResults.FailedSteps) {
        $html += "<tr class='failure'><td>$($step.Time)</td><td>Failed</td><td>$($step.Message)</td></tr>"
    }
    
    $html += @"
        </table>
    </body>
    </html>
"@
    
    $html | Out-File $filePath -Encoding UTF8
    Show-Message "Report exported successfully" "Success"
}

function Export-CSVReport {
    param($filePath)
    
    $csvData = @()
    foreach ($step in $script:analysisResults.SuccessSteps) {
        $csvData += [PSCustomObject]@{
            Time = $step.Time
            Status = "Success"
            Message = $step.Message
        }
    }
    
    foreach ($step in $script:analysisResults.FailedSteps) {
        $csvData += [PSCustomObject]@{
            Time = $step.Time
            Status = "Failed"
            Message = $step.Message
        }
    }
    
    $csvData | Export-Csv -Path $filePath -NoTypeInformation
    Show-Message "Report exported successfully" "Success"
}

function Show-Message {
    param(
        [string]$message,
        [string]$type = "Info"
    )
    
    $icon = switch ($type) {
        "Error" { [System.Windows.Forms.MessageBoxIcon]::Error }
        "Success" { [System.Windows.Forms.MessageBoxIcon]::Information }
        default { [System.Windows.Forms.MessageBoxIcon]::Information }
    }
    
    [System.Windows.Forms.MessageBox]::Show($message, $type, [System.Windows.Forms.MessageBoxButtons]::OK, $icon)
}

function Update-Status {
    param([string]$message)
    # Implement status bar update logic here
}

# Main execution
try {
    $form = Initialize-UI
    if ($form -ne $null) {
        [void]$form.ShowDialog()
    } else {
        Write-Host "Failed to initialize the form."
    }
} catch {
    Write-Host "Error: $_"
    Write-Host "Stack Trace: $($_.ScriptStackTrace)"
} 