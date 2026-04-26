# AP / Mesh Node Console Log Observability Pipeline

Production-oriented tooling for collecting AP or mesh node console logs through a Raspberry Pi serial-console collector, preserving raw logs, extracting CPU and memory metrics, generating CSV/PNG artifacts, and writing Markdown reports for long-run analysis.

No lab IP addresses or credentials are hardcoded. Copy `config/config.example.yaml` to `config/config.yaml` and fill in your environment-specific values.

## Architecture

```text
[Control Machine / PC / TFTP Server]
IP: <configured_by_user>
    |
    | SSH / SCP
    v
[Raspberry Pi / Console Collector]
IP: <configured_by_user>
    |
    | Serial Console / Minicom
    v
[DUT / AP / Mesh Node]
IP: <configured_by_user>
```

## Quick Start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp config/config.example.yaml config/config.yaml
```

Edit `config/config.yaml`, then start capture on the Raspberry Pi:

```bash
scripts/pi/start_minicom_capture.sh /dev/ttyUSB0 115200 ~/minicom.cap
```

Collect and analyze from Linux:

```bash
scripts/linux/collect_logs.sh config/config.yaml
python3 analyzer/analyze_logs.py --config config/config.yaml
```

Collect and analyze from Windows PowerShell:

```powershell
.\scripts\windows\collect_logs.ps1 -ConfigPath config\config.yaml
python analyzer\analyze_logs.py --config config\config.yaml
```

Run continuous monitoring:

```bash
scripts/linux/monitor_pipeline.sh config/config.yaml
```

```powershell
.\scripts\windows\monitor_pipeline.ps1 -ConfigPath config\config.yaml
```

## Configuration

`config/config.yaml` controls all environment-specific values:

- `control_machine.tftp_server_ip`: TFTP server IP used by the Pi-side `tftp` client when available.
- `control_machine.tftp_root`: Local TFTP root to mirror collected files into. Leave empty if not used.
- `control_machine.output_dir`: Local output directory for raw logs, CSVs, graphs, and reports.
- `raspberry_pi.host`, `username`, `ssh_port`: SSH target for the Pi collector.
- `raspberry_pi.minicom_capture_path`: Capture file created by minicom on the Pi.
- `raspberry_pi.remote_log_dir`: Pi-side directory where timestamped logs are staged.
- `dut.ip`, `label`, `mark`, `firmware_version`: Used in timestamped filenames and reports.
- `dut.sysmon_command`: DUT command to start CPU/memory console output.
- `monitor.interval_minutes`: Collection cadence for monitor scripts.
- `monitor.keep_minicom_cap_after_upload`: Keep or remove the Pi capture file after successful collection.
- `metrics`: CPU and memory metrics to parse.

## DUT SysMon Usage

Start your DUT's CPU/memory telemetry so output reaches the serial console. The default command is configurable:

```text
sh /mnt/data/sysMon001.sh __s __h
```

Use the firmware's supported command if it differs, and update `dut.sysmon_command` for documentation consistency.

## Expected Outputs

- `output/raw/`: raw timestamped DUT console logs plus split CPU/metric text files.
- `output/csv/`: CPU and memory CSV files.
- `output/graphs/`: CPU usage PNG and one PNG per memory metric.
- `output/reports/`: Markdown report with min/max/avg/start/end/delta summaries.
- `monitor_history.log`: monitor-cycle status history.

Raw log filenames follow:

```text
<firmware_version>-<MMdd_HHmmss>-log-<dut_label>-<mark>-DUT_<dut_ip>.txt
```

## Example Use Cases

- Mesh node tracking: run `monitor_pipeline` every 10 minutes during overnight mesh stability tests.
- Roaming AP resource tracking: collect CPU and memory trends while clients roam between APs.
- Firmware regression monitoring: compare CSV summaries and graphs between firmware versions.
- Crash/debug preservation: keep timestamped console logs for kernel warnings, watchdogs, and panic traces.

## Platform Notes

Windows uses PowerShell plus OpenSSH `ssh`/`scp`. Linux uses Bash plus OpenSSH. Both scripts read the same YAML config through Python/PyYAML.

See `docs/` for setup and troubleshooting details.
