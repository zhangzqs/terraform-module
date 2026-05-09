#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARED = ROOT / "mqtt-instance" / "modules" / "shared"
sys.path.insert(0, str(SHARED))

from mqtt_crypto import pack_message, unpack_message  # noqa: E402


def make_cert(workdir: Path, name: str) -> tuple[str, str]:
    key_path = workdir / f"{name}.key.pem"
    cert_path = workdir / f"{name}.cert.pem"
    subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key_path),
            "-out",
            str(cert_path),
            "-days",
            "1",
            "-subj",
            f"/CN={name}",
        ],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return cert_path.read_text(encoding="utf-8"), key_path.read_text(encoding="utf-8")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        workdir = Path(td)
        sender_cert, sender_key = make_cert(workdir, "sender")
        recipient_cert, recipient_key = make_cert(workdir, "recipient")

        payload = {
            "message_type": "command",
            "task_uuid": "test-task",
            "nonce": "abc123",
            "sent_at": "2026-05-10T00:00:00Z",
            "command_type": "shell",
            "command": "echo hello",
        }

        package = pack_message(payload, sender_cert, sender_key, recipient_cert)
        restored = unpack_message(package, recipient_cert, recipient_key, sender_cert)
        assert restored == payload, json.dumps(restored, ensure_ascii=False)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
