# Linux Setup

## Prerequisites

- Bash
- OpenSSH client
- Python 3.10+
- Network reachability to the Raspberry Pi over SSH
- Optional TFTP server and writable TFTP root

## Install Dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp config/config.example.yaml config/config.yaml
chmod +x scripts/linux/*.sh scripts/pi/*.sh
```

Edit `config/config.yaml`.

The Linux scripts resolve the repository root automatically, so they can be launched from the repo root or by absolute path from another working directory.

## Run Collection

```bash
scripts/linux/collect_logs.sh config/config.yaml
python3 analyzer/analyze_logs.py --config config/config.yaml
```

## Continuous Monitoring

```bash
scripts/linux/monitor_pipeline.sh config/config.yaml
```

The monitor writes `monitor_history.log` and sleeps for `monitor.interval_minutes` between cycles.
