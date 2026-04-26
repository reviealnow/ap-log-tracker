from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml


DEFAULT_CONFIG = Path("config/config.yaml")


class ConfigError(ValueError):
    pass


def load_config(path: str | Path = DEFAULT_CONFIG) -> dict[str, Any]:
    config_path = Path(path)
    if not config_path.exists():
        raise ConfigError(
            f"Config file not found: {config_path}. Copy config/config.example.yaml "
            "to config/config.yaml and fill in your environment values."
        )

    with config_path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}

    if not isinstance(data, dict):
        raise ConfigError("Config root must be a YAML mapping.")

    return data


def require_value(config: dict[str, Any], dotted_key: str) -> Any:
    cursor: Any = config
    for part in dotted_key.split("."):
        if not isinstance(cursor, dict) or part not in cursor:
            raise ConfigError(f"Missing required config key: {dotted_key}")
        cursor = cursor[part]
    if cursor is None or cursor == "":
        raise ConfigError(f"Required config value is empty: {dotted_key}")
    return cursor


def output_dir(config: dict[str, Any]) -> Path:
    configured = config.get("control_machine", {}).get("output_dir") or "output"
    return Path(configured)


def dump_json(path: str | Path = DEFAULT_CONFIG) -> str:
    return json.dumps(load_config(path), separators=(",", ":"))


if __name__ == "__main__":
    print(dump_json())
