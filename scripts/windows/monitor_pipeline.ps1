param(
    [string]$ConfigPath = "config/config.yaml"
)

$ErrorActionPreference = "Stop"

function Get-Config {
    param([string]$Path)
    $json = python -c "import sys; sys.path.insert(0,'analyzer'); from config_loader import dump_json; print(dump_json(sys.argv[1]))" $Path
    if ($LASTEXITCODE -ne 0) { throw "Unable to read config from $Path" }
    return $json | ConvertFrom-Json
}

$config = Get-Config $ConfigPath
$intervalMinutes = [int]$config.monitor.interval_minutes
if ($intervalMinutes -lt 1) { $intervalMinutes = 10 }
$history = "monitor_history.log"

Write-Host "[monitor] Running every $intervalMinutes minute(s). Press Ctrl+C to stop."
while ($true) {
    $started = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $history -Value "[$started] cycle started"

    & "$PSScriptRoot\collect_logs.ps1" -ConfigPath $ConfigPath
    $collectExit = $LASTEXITCODE
    Add-Content -Path $history -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] collect exit=$collectExit"

    if ($collectExit -eq 0) {
        python analyzer/analyze_logs.py --config $ConfigPath
        $analyzeExit = $LASTEXITCODE
        Add-Content -Path $history -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] analyze exit=$analyzeExit"
    }

    Start-Sleep -Seconds ($intervalMinutes * 60)
}
