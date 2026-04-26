# Windows Setup

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7+
- OpenSSH Client enabled
- Python 3.10+
- Network reachability from Windows to the Raspberry Pi over SSH
- Optional TFTP server configured if you want TFTP-root mirroring

## Install Dependencies

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item config\config.example.yaml config\config.yaml
```

Edit `config\config.yaml`.

## Run Collection

```powershell
.\scripts\windows\collect_logs.ps1 -ConfigPath config\config.yaml
python analyzer\analyze_logs.py --config config\config.yaml
```

## Continuous Monitoring

```powershell
.\scripts\windows\monitor_pipeline.ps1 -ConfigPath config\config.yaml
```

The monitor writes `monitor_history.log` and continues until stopped with `Ctrl+C`.
