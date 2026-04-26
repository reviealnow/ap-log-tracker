param(
    [string]$ConfigPath = "config/config.yaml"
)

$ErrorActionPreference = "Stop"

function Write-Stage {
    param([string]$Message)
    Write-Host "[collect] $Message"
}

function Fail {
    param([string]$Message)
    Write-Error $Message
    exit 1
}

function Get-Config {
    param([string]$Path)
    $json = python -c "import sys; sys.path.insert(0,'analyzer'); from config_loader import dump_json; print(dump_json(sys.argv[1]))" $Path
    if ($LASTEXITCODE -ne 0) {
        Fail "Unable to read config from $Path. Install requirements with: pip install -r requirements.txt"
    }
    return $json | ConvertFrom-Json
}

function Require-Value {
    param($Value, [string]$Name)
    if ($null -eq $Value -or "$Value" -eq "") {
        Fail "Missing required config value: $Name"
    }
    return "$Value"
}

function Sanitize-FilePart {
    param([string]$Value, [string]$Fallback)
    if ([string]::IsNullOrWhiteSpace($Value)) { $Value = $Fallback }
    return ($Value -replace '[^\w.\-]+', '_')
}

try {
    $config = Get-Config $ConfigPath

    $piHost = Require-Value $config.raspberry_pi.host "raspberry_pi.host"
    $piUser = Require-Value $config.raspberry_pi.username "raspberry_pi.username"
    $piPort = [int]$config.raspberry_pi.ssh_port
    $capturePath = Require-Value $config.raspberry_pi.minicom_capture_path "raspberry_pi.minicom_capture_path"
    $remoteLogDir = Require-Value $config.raspberry_pi.remote_log_dir "raspberry_pi.remote_log_dir"
    $dutIp = Require-Value $config.dut.ip "dut.ip"
    $dutLabel = Sanitize-FilePart $config.dut.label "DUT-01"
    $dutMark = Sanitize-FilePart $config.dut.mark "01"
    $firmware = Sanitize-FilePart $config.dut.firmware_version "unknown-fw"
    $tftpServerIp = "$($config.control_machine.tftp_server_ip)"
    $tftpRoot = "$($config.control_machine.tftp_root)"
    $outputDir = if ("$($config.control_machine.output_dir)" -ne "") { "$($config.control_machine.output_dir)" } else { "output" }
    $keepCapture = [bool]$config.monitor.keep_minicom_cap_after_upload

    $timestamp = Get-Date -Format "MMdd_HHmmss"
    $fileName = "$firmware-$timestamp-log-$dutLabel-$dutMark-DUT_$dutIp.txt"
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $rawDir = Join-Path $outputDir "raw"
    New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
    if ($tftpRoot -ne "") {
        New-Item -ItemType Directory -Force -Path $tftpRoot | Out-Null
    }

    Write-Stage "Checking Raspberry Pi capture file on $piUser@$piHost"
    $memoryPattern = "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|Active|Inactive|Slab|SReclaimable|SUnreclaim"
    $remoteScript = @"
set -e
mkdir -p "$remoteLogDir"
test -f "$capturePath"
cp "$capturePath" "$remoteLogDir/$fileName"
perl -pi -e 's/%%/%/g' "$remoteLogDir/$fileName"
grep -E 'CPU[0-9]' "$remoteLogDir/$fileName" > "$remoteLogDir/${baseName}_cpu.txt" || true
grep -E '$memoryPattern' "$remoteLogDir/$fileName" > "$remoteLogDir/${baseName}_memory.txt" || true
if [ -n "$tftpServerIp" ]; then
  command -v tftp >/dev/null 2>&1 || exit 31
  cd "$remoteLogDir"
  tftp "$tftpServerIp" -c put "$fileName" || exit 30
  tftp "$tftpServerIp" -c put "${baseName}_cpu.txt" || exit 30
  tftp "$tftpServerIp" -c put "${baseName}_memory.txt" || exit 30
fi
if [ "$keepCapture" = "False" ]; then
  rm -f "$capturePath"
fi
"@
    $remoteScript = $remoteScript -replace "`r", ""
    $remoteScript | ssh -p $piPort "$piUser@$piHost" "bash -s"
    if ($LASTEXITCODE -ne 0) {
        Fail "Remote collection failed. Check SSH, minicom capture path, and optional TFTP client/server access."
    }

    Write-Stage "Copying collected files to $rawDir"
    scp -P $piPort "$piUser@$piHost`:$remoteLogDir/$fileName" $rawDir
    if ($LASTEXITCODE -ne 0) { Fail "SCP failed for raw log." }
    scp -P $piPort "$piUser@$piHost`:$remoteLogDir/${baseName}_cpu.txt" $rawDir
    scp -P $piPort "$piUser@$piHost`:$remoteLogDir/${baseName}_memory.txt" $rawDir

    if ($tftpRoot -ne "") {
        Write-Stage "Mirroring collected files into configured TFTP root: $tftpRoot"
        Copy-Item -Force (Join-Path $rawDir $fileName) $tftpRoot
        Copy-Item -Force (Join-Path $rawDir "${baseName}_cpu.txt") $tftpRoot -ErrorAction SilentlyContinue
        Copy-Item -Force (Join-Path $rawDir "${baseName}_memory.txt") $tftpRoot -ErrorAction SilentlyContinue
    }

    Write-Stage "Done: $fileName"
    exit 0
}
catch {
    Fail $_.Exception.Message
}
