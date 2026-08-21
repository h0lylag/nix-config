#!/usr/bin/env python3
"""One-shot read-only SMART snapshot writer."""

from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCHEMA = "smartmon-helper/v1"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_scan(output: str) -> list[dict[str, str | None]]:
    """Parse smartctl --scan-open output, preserving order and type hints."""
    devices: list[dict[str, str | None]] = []
    seen: set[str] = set()
    for line in output.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = line.split()
        path = fields[0]
        if not path.startswith("/dev/") or path in seen:
            continue
        device_type: str | None = None
        for index, field in enumerate(fields[:-1]):
            if field in {"-d", "--device"}:
                device_type = fields[index + 1]
                break
        devices.append({"path": path, "scan_type": device_type})
        seen.add(path)
    return devices


def _nested(mapping: Any, *keys: str) -> Any:
    for key in keys:
        if not isinstance(mapping, dict):
            return None
        mapping = mapping.get(key)
    return mapping


def summarize(raw: dict[str, Any]) -> dict[str, Any]:
    """Extract stable fields while retaining full smartctl JSON in each item."""
    nvme_health = raw.get("nvme_smart_health_information_log") or {}
    temperature = _nested(raw, "temperature", "current")
    if temperature is None:
        temperature = nvme_health.get("temperature")

    error_count = _nested(raw, "ata_smart_error_log", "summary", "count")
    if error_count is None:
        error_count = nvme_health.get("num_err_log_entries")

    smart_status = raw.get("smart_status") or {}
    passed = smart_status.get("passed")
    return {
        "model": raw.get("model_name") or raw.get("model_family"),
        "serial": raw.get("serial_number"),
        "firmware": raw.get("firmware_version"),
        "wwn": raw.get("wwn"),
        "smart_passed": passed,
        "temperature_c": temperature,
        "percentage_used": nvme_health.get("percentage_used"),
        "media_errors": nvme_health.get("media_errors"),
        "error_log_entries": error_count,
    }


def _query_status(raw: dict[str, Any] | None, returncode: int) -> str:
    if raw is None:
        return "error"
    passed = _nested(raw, "smart_status", "passed")
    if passed is False:
        return "failed"
    if returncode:
        return "warning"
    if passed is True:
        return "ok"
    return "unknown"


class SmartCollector:
    """Enumerate devices and collect read-only JSON SMART data."""

    def __init__(self, smartctl: str = "smartctl", timeout: float = 45.0) -> None:
        self.smartctl = smartctl
        self.timeout = timeout

    def _run(self, arguments: list[str]) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(
                [self.smartctl, *arguments],
                capture_output=True,
                text=True,
                timeout=self.timeout,
                check=False,
            )
        except FileNotFoundError as exc:
            raise RuntimeError(f"smartctl not found: {self.smartctl}") from exc
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(f"smartctl timed out after {self.timeout:g}s") from exc
        except OSError as exc:
            raise RuntimeError(f"smartctl failed to start: {exc}") from exc

    def _device(self, device: dict[str, str | None]) -> dict[str, Any]:
        path = str(device["path"])
        item: dict[str, Any] = {
            "path": path,
            "scan_type": device.get("scan_type"),
            "query_status": "error",
            "summary": None,
            "smartctl": None,
            "stderr": None,
        }
        try:
            arguments = ["--json", "--all"]
            if device.get("scan_type"):
                arguments.extend(["--device", str(device["scan_type"])])
            arguments.append(path)
            result = self._run(arguments)
        except RuntimeError as exc:
            item["error"] = str(exc)
            return item

        item["exit_status"] = result.returncode
        item["stderr"] = result.stderr.strip() or None
        raw: dict[str, Any] | None = None
        if result.stdout.strip():
            try:
                parsed = json.loads(result.stdout)
                if isinstance(parsed, dict):
                    raw = parsed
            except json.JSONDecodeError:
                item["error"] = "smartctl returned invalid JSON"

        item["query_status"] = _query_status(raw, result.returncode)
        if raw is not None:
            item["summary"] = summarize(raw)
            item["smartctl"] = raw
        elif "error" not in item:
            item["error"] = item["stderr"] or "smartctl returned no JSON"
        return item

    def _snapshot(self) -> dict[str, Any]:
        collected_at = utc_now()
        try:
            scan = self._run(["--scan-open"])
        except RuntimeError as exc:
            return {
                "schema": SCHEMA,
                "host": socket.gethostname(),
                "collected_at": collected_at,
                "status": "error",
                "smartctl": self.smartctl,
                "devices": [],
                "summary": {"total": 0, "ok": 0, "warning": 0, "failed": 0, "unknown": 0, "errors": 1},
                "errors": [str(exc)],
            }

        devices = parse_scan(scan.stdout)
        if not devices:
            detail = scan.stderr.strip() or "smartctl scan found no devices"
            return {
                "schema": SCHEMA,
                "host": socket.gethostname(),
                "collected_at": collected_at,
                "status": "error",
                "smartctl": self.smartctl,
                "devices": [],
                "summary": {"total": 0, "ok": 0, "warning": 0, "failed": 0, "unknown": 0, "errors": 1},
                "errors": [detail],
            }

        with ThreadPoolExecutor(max_workers=min(4, len(devices))) as pool:
            collected = list(pool.map(self._device, devices))

        counts = {status: sum(item["query_status"] == status for item in collected) for status in ("ok", "warning", "failed", "unknown", "error")}
        if counts["error"] == len(collected):
            status = "error"
        elif scan.returncode or any(
            counts[key] for key in ("warning", "failed", "unknown", "error")
        ):
            status = "partial"
        else:
            status = "ok"
        errors = []
        if scan.returncode:
            errors.append(
                scan.stderr.strip()
                or f"smartctl scan exited with status {scan.returncode}"
            )
        errors.extend(
            f"{item['path']}: {item['error']}"
            for item in collected
            if item.get("error")
        )
        return {
            "schema": SCHEMA,
            "host": socket.gethostname(),
            "collected_at": collected_at,
            "status": status,
            "smartctl": self.smartctl,
            "scan_exit_status": scan.returncode,
            "devices": collected,
            "summary": {
                "total": len(collected),
                "ok": counts["ok"],
                "warning": counts["warning"],
                "failed": counts["failed"],
                "unknown": counts["unknown"],
                "errors": counts["error"],
            },
            "errors": errors,
        }

    def snapshot(self) -> dict[str, Any]:
        return self._snapshot()


def write_snapshot(path: str | Path, payload: dict[str, Any]) -> None:
    """Write JSON atomically so readers never observe a partial snapshot."""
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.name}.",
        dir=target.parent,
        text=True,
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            os.fchmod(handle.fileno(), 0o640)
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary_name, target)
    except BaseException:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def _env_float(name: str, default: float) -> float:
    try:
        return float(os.environ.get(name, str(default)))
    except ValueError as exc:
        raise SystemExit(f"{name} must be a number") from exc


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=os.environ.get("SMARTMON_OUTPUT"),
        help="write snapshot atomically to this path instead of stdout",
    )
    parser.add_argument("--timeout", type=float, default=_env_float("SMARTMON_TIMEOUT", 45.0))
    parser.add_argument("--smartctl", default=os.environ.get("SMARTMON_SMARTCTL", "smartctl"))
    args = parser.parse_args(argv)

    collector = SmartCollector(smartctl=args.smartctl, timeout=args.timeout)
    payload = collector.snapshot()
    try:
        if args.output:
            write_snapshot(args.output, payload)
        else:
            print(json.dumps(payload, indent=2, sort_keys=True))
    except OSError as exc:
        print(f"smartmon-helper: cannot write snapshot: {exc}", file=sys.stderr)
        return 1
    return 0 if payload["status"] == "ok" else 1


if __name__ == "__main__":
    sys.exit(main())
