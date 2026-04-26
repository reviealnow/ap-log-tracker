# Troubleshooting

## `chmod` not recognized on Windows

`chmod` is a Linux/macOS command. On Windows, run the PowerShell scripts directly:

```powershell
.\scripts\windows\collect_logs.ps1 -ConfigPath config\config.yaml
```

## PowerShell execution policy

If PowerShell blocks local scripts, run:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Or launch one command with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\windows\collect_logs.ps1 -ConfigPath config\config.yaml
```

## SSH connection failure

Verify `raspberry_pi.host`, `username`, and `ssh_port`. Test manually:

```bash
ssh -p <port> <user>@<pi-host>
```

## No route to host

The control machine cannot reach the Raspberry Pi. Check cabling, Wi-Fi/VLAN, routing, VPN, and firewall rules. Confirm the Pi IP address is correct in `config/config.yaml`.

## `minicom.cap` not found

Start capture on the Pi and confirm `raspberry_pi.minicom_capture_path` matches:

```bash
scripts/pi/start_minicom_capture.sh /dev/ttyUSB0 115200 ~/minicom.cap
```

## TFTP upload failure

Confirm the Pi has a TFTP client installed and can reach `control_machine.tftp_server_ip`. Also confirm the TFTP server permits writes and its root directory is writable.

## Windows CRLF causing bash `$'\r'` errors

The PowerShell script strips carriage returns before streaming commands to `bash -s`. If you edit Linux scripts on Windows, convert them to LF line endings before running on Linux or the Pi.

## Firewall UDP 69 issue

TFTP uses UDP port 69 plus negotiated transfer ports. Allow TFTP traffic on the control machine firewall, or use SCP retrieval and `control_machine.tftp_root` mirroring instead.

## Python matplotlib not installed

Install dependencies:

```bash
pip install -r requirements.txt
```

If you use a virtual environment, activate it before running monitor scripts.
