#!/usr/bin/env python3
"""S3 remote executor."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path

from s3_client import S3Client


def _load_command_file(path: str) -> tuple[str, str]:
    content = Path(path).read_text(encoding='utf-8')
    command_type, _, command_body = content.partition('\n')
    return command_type, command_body


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--bucket', required=True)
    parser.add_argument('--instance-id', required=True)
    parser.add_argument('--command-file', required=True)
    parser.add_argument('--result-file', required=True)
    parser.add_argument('--timeout', type=int, default=300)
    parser.add_argument('--poll-interval', type=int, default=3)
    args = parser.parse_args()

    client = S3Client.from_env(timeout=float(args.poll_interval))
    command_type, command_body = _load_command_file(args.command_file)
    command_blob = f'{command_type}\n{command_body}'.encode('utf-8')
    cmd_id = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%d%H%M%S')
    command_key = f'commands/{args.instance_id}/pending/{cmd_id}.cmd'
    result_key = f'results/{args.instance_id}/{cmd_id}.json'

    client.put_object(args.bucket, command_key, command_blob)
    print(f'Command uploaded: {command_key}', file=sys.stderr)

    deadline = time.monotonic() + args.timeout
    while time.monotonic() < deadline:
        if client.head_object(args.bucket, result_key):
            payload = client.get_object(args.bucket, result_key)
            result_path = Path(args.result_file)
            result_path.parent.mkdir(parents=True, exist_ok=True)
            result_path.write_bytes(payload)
            result = json.loads(payload.decode('utf-8'))
            print(f'Result saved: {result_path}', file=sys.stderr)
            return int(result.get('exit_code', 1))
        time.sleep(args.poll_interval)

    raise TimeoutError(f'Timeout after {args.timeout}s')


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f'ERROR: {exc}', file=sys.stderr)
        raise SystemExit(1)
