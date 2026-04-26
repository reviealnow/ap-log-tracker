from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


CPU_RE = re.compile(r"\b(CPU\d+)\b[^0-9+-]*([+-]?\d+(?:\.\d+)?)\s*%")
MEM_RE = re.compile(
    r"\b(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|Active|Inactive|Slab|SReclaimable|SUnreclaim)\b"
    r"[^0-9+-]*([+-]?\d+(?:\.\d+)?)\s*(kB|KB|MB|GB)?",
    re.IGNORECASE,
)
TIMESTAMP_RE = re.compile(
    r"(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}|"
    r"\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2}|"
    r"\d{2}:\d{2}:\d{2})"
)


@dataclass(frozen=True)
class MetricSample:
    sample_index: int
    timestamp: str
    metric: str
    value: float
    unit: str
    line_number: int


def clean_line(line: str) -> str:
    return line.replace("%%", "%").rstrip("\r\n")


def extract_timestamp(line: str) -> str:
    match = TIMESTAMP_RE.search(line)
    return match.group(1) if match else ""


def parse_log(path: str | Path, metric_names: list[str] | None = None) -> tuple[list[MetricSample], list[MetricSample]]:
    raw_path = Path(path)
    wanted = {name.lower() for name in metric_names or []}
    cpu_samples: list[MetricSample] = []
    mem_samples: list[MetricSample] = []

    with raw_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line_number, raw_line in enumerate(handle, start=1):
            line = clean_line(raw_line)
            timestamp = extract_timestamp(line)

            for match in CPU_RE.finditer(line):
                metric = match.group(1)
                if wanted and metric.lower() not in wanted:
                    continue
                cpu_samples.append(
                    MetricSample(len(cpu_samples), timestamp, metric, float(match.group(2)), "%", line_number)
                )

            for match in MEM_RE.finditer(line):
                metric = canonical_memory_name(match.group(1))
                if wanted and metric.lower() not in wanted:
                    continue
                value = normalize_memory_value(float(match.group(2)), match.group(3))
                mem_samples.append(MetricSample(len(mem_samples), timestamp, metric, value, "kB", line_number))

    return cpu_samples, mem_samples


def canonical_memory_name(name: str) -> str:
    names = {
        "memtotal": "MemTotal",
        "memfree": "MemFree",
        "memavailable": "MemAvailable",
        "buffers": "Buffers",
        "cached": "Cached",
        "swapcached": "SwapCached",
        "active": "Active",
        "inactive": "Inactive",
        "slab": "Slab",
        "sreclaimable": "SReclaimable",
        "sunreclaim": "SUnreclaim",
    }
    return names.get(name.lower(), name)


def normalize_memory_value(value: float, unit: str | None) -> float:
    normalized = (unit or "kB").lower()
    if normalized == "mb":
        return value * 1024
    if normalized == "gb":
        return value * 1024 * 1024
    return value
