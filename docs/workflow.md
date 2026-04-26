# Workflow

1. Install Python dependencies on the control machine with `pip install -r requirements.txt`.
2. Copy `config/config.example.yaml` to `config/config.yaml`.
3. Fill in control machine, Raspberry Pi, DUT, firmware, TFTP, and monitor values.
4. Connect the Raspberry Pi serial adapter to the DUT console.
5. Start minicom capture on the Pi with `scripts/pi/start_minicom_capture.sh`.
6. Start the DUT sysMon command so CPU and memory lines appear on console.
7. Run one collection cycle from Windows or Linux.
8. Run `analyzer/analyze_logs.py`, or use a monitor script to collect and analyze continuously.

The collection stage copies `minicom.cap` into the Pi remote log directory, renames it with firmware/DUT/timestamp metadata, normalizes duplicate percent signs, splits CPU and metric lines, optionally uploads staged files with TFTP, and retrieves artifacts to the control machine.

The analyzer stage detects the newest raw DUT log, parses CPU and memory samples, writes CSV files, creates matplotlib PNG graphs, and writes a Markdown engineering report.
