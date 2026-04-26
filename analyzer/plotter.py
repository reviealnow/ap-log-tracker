from __future__ import annotations

import os
import tempfile
from collections import defaultdict
from pathlib import Path

cache_dir = Path(tempfile.gettempdir()) / "ap-log-observability-matplotlib"
cache_dir.mkdir(parents=True, exist_ok=True)
os.environ.setdefault("MPLCONFIGDIR", str(cache_dir))
os.environ.setdefault("XDG_CACHE_HOME", str(cache_dir))

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt

from parser import MetricSample


def plot_cpu(samples: list[MetricSample], output_path: str | Path) -> Path | None:
    if not samples:
        return None
    return _plot_grouped(samples, output_path, "CPU Usage", "Sample", "Usage (%)")


def plot_memory(samples: list[MetricSample], output_dir: str | Path, stem: str) -> list[Path]:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)
    by_metric = _group(samples)
    paths: list[Path] = []
    for metric, metric_samples in sorted(by_metric.items()):
        path = output / f"{stem}_memory_{metric}.png"
        plotted = _plot_grouped(metric_samples, path, f"{metric} Memory", "Sample", "kB")
        if plotted:
            paths.append(plotted)
    return paths


def _plot_grouped(samples: list[MetricSample], output_path: str | Path, title: str, xlabel: str, ylabel: str) -> Path:
    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    plt.figure(figsize=(11, 5.5))
    for metric, metric_samples in sorted(_group(samples).items()):
        x_values = list(range(len(metric_samples)))
        y_values = [sample.value for sample in metric_samples]
        plt.plot(x_values, y_values, marker="o", linewidth=1.5, markersize=2.5, label=metric)
    plt.title(title)
    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.grid(True, linewidth=0.4, alpha=0.4)
    plt.legend()
    plt.tight_layout()
    plt.savefig(output, dpi=150)
    plt.close()
    return output


def _group(samples: list[MetricSample]) -> dict[str, list[MetricSample]]:
    grouped: dict[str, list[MetricSample]] = defaultdict(list)
    for sample in samples:
        grouped[sample.metric].append(sample)
    return grouped
