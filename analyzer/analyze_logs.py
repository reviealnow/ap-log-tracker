#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import sys
from datetime import datetime
from pathlib import Path

from config_loader import ConfigError, load_config, output_dir
from parser import MetricSample, parse_log
from plotter import plot_cpu, plot_memory
from report import write_report


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze AP / mesh node console logs.")
    parser.add_argument("--config", default="config/config.yaml", help="Path to YAML config file.")
    parser.add_argument("--raw-dir", help="Raw log directory. Defaults to <output_dir>/raw.")
    parser.add_argument("--log-file", help="Specific raw log file to analyze.")
    args = parser.parse_args()

    try:
        config = load_config(args.config)
    except ConfigError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2

    base_output = output_dir(config)
    raw_dir = Path(args.raw_dir) if args.raw_dir else base_output / "raw"
    csv_dir = base_output / "csv"
    graph_dir = base_output / "graphs"
    report_dir = base_output / "reports"
    for directory in [raw_dir, csv_dir, graph_dir, report_dir]:
        directory.mkdir(parents=True, exist_ok=True)

    source_log = Path(args.log_file) if args.log_file else latest_log(raw_dir)
    if not source_log:
        print(f"[ERROR] No raw log files found in {raw_dir}", file=sys.stderr)
        return 1

    metrics = config.get("metrics") or []
    cpu_samples, mem_samples = parse_log(source_log, metrics)
    run_stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    stem = f"{source_log.stem}_{run_stamp}"

    cpu_csv = write_csv(cpu_samples, csv_dir / f"{stem}_cpu.csv") if cpu_samples else None
    mem_csv = write_csv(mem_samples, csv_dir / f"{stem}_memory.csv") if mem_samples else None
    cpu_graph = plot_cpu(cpu_samples, graph_dir / f"{stem}_cpu.png") if cpu_samples else None
    memory_graphs = plot_memory(mem_samples, graph_dir, stem) if mem_samples else []
    report_path = write_report(
        source_log,
        cpu_samples,
        mem_samples,
        cpu_csv,
        mem_csv,
        cpu_graph,
        memory_graphs,
        report_dir / f"{stem}_report.md",
    )

    print(f"[OK] Source log: {source_log}")
    print(f"[OK] CPU samples: {len(cpu_samples)}")
    print(f"[OK] Memory samples: {len(mem_samples)}")
    print(f"[OK] Report: {report_path}")
    return 0


def latest_log(raw_dir: Path) -> Path | None:
    candidates = [path for path in raw_dir.glob("*.txt") if path.is_file()]
    if not candidates:
        candidates = [path for path in raw_dir.glob("*.log") if path.is_file()]
    return max(candidates, key=lambda path: path.stat().st_mtime) if candidates else None


def write_csv(samples: list[MetricSample], output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["sample_index", "timestamp", "metric", "value", "unit", "line_number"])
        for sample in samples:
            writer.writerow(
                [sample.sample_index, sample.timestamp, sample.metric, f"{sample.value:.6f}", sample.unit, sample.line_number]
            )
    return output_path


if __name__ == "__main__":
    raise SystemExit(main())
