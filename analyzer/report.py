from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from parser import MetricSample


def write_report(
    source_log: Path,
    cpu_samples: list[MetricSample],
    mem_samples: list[MetricSample],
    cpu_csv: Path | None,
    mem_csv: Path | None,
    cpu_graph: Path | None,
    memory_graphs: list[Path],
    output_path: str | Path,
) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# AP / Mesh Node Console Report",
        "",
        f"- Source log: `{source_log.name}`",
        f"- Generated time: `{datetime.now(timezone.utc).astimezone().isoformat(timespec='seconds')}`",
        f"- CPU samples: `{len(cpu_samples)}`",
        f"- Memory samples: `{len(mem_samples)}`",
        "",
        "## Generated Artifacts",
        "",
    ]
    for label, path in [
        ("CPU CSV", cpu_csv),
        ("Memory CSV", mem_csv),
        ("CPU graph", cpu_graph),
    ]:
        if path:
            lines.append(f"- {label}: `{path}`")
    for path in memory_graphs:
        lines.append(f"- Memory graph: `{path}`")

    lines.extend(["", "## CPU Summary", ""])
    lines.extend(_summary_table(cpu_samples, "%"))
    lines.extend(["", "## Memory Summary", ""])
    lines.extend(_summary_table(mem_samples, "kB"))
    lines.extend(
        [
            "",
            "## Engineering Notes",
            "",
            "- Review CPU deltas for sustained upward trends during roaming, backhaul changes, or mesh reconvergence.",
            "- Compare memory start/end and min/max values across firmware builds to identify leaks or regressions.",
            "- Preserve the raw console log with crash signatures, kernel warnings, and watchdog output for deeper debugging.",
        ]
    )
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return output


def _summary_table(samples: list[MetricSample], unit: str) -> list[str]:
    if not samples:
        return ["No samples found."]
    lines = [
        f"| Metric | Min ({unit}) | Max ({unit}) | Avg ({unit}) | Start ({unit}) | End ({unit}) | Delta ({unit}) |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for metric, values in sorted(_values_by_metric(samples).items()):
        start = values[0]
        end = values[-1]
        lines.append(
            f"| {metric} | {min(values):.2f} | {max(values):.2f} | {sum(values) / len(values):.2f} | "
            f"{start:.2f} | {end:.2f} | {end - start:.2f} |"
        )
    return lines


def _values_by_metric(samples: list[MetricSample]) -> dict[str, list[float]]:
    grouped: dict[str, list[float]] = defaultdict(list)
    for sample in samples:
        grouped[sample.metric].append(sample.value)
    return grouped
