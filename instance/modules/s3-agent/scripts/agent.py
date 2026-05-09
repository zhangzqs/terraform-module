#!/usr/bin/env python3
"""S3 command agent."""

from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from s3_client import S3Client


def _run_shell(command_body: str) -> tuple[int, str]:
    proc = subprocess.run(
        command_body,
        shell=True,
        executable='/bin/bash',
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    return proc.returncode, proc.stdout or ''


def _run_shell_script(command_body: str) -> tuple[int, str]:
    with tempfile.NamedTemporaryFile('w', delete=False, suffix='.sh', encoding='utf-8') as handle:
        handle.write(command_body)
        script_path = handle.name
    try:
        proc = subprocess.run(
            ['/bin/bash', script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        return proc.returncode, proc.stdout or ''
    finally:
        try:
            os.unlink(script_path)
        except FileNotFoundError:
            pass


def _run_command(command_type: str, command_body: str) -> tuple[int, str]:
    if command_type == 'shell':
        return _run_shell(command_body)
    if command_type == 'shell-script':
        return _run_shell_script(command_body)
    return 1, 'Unknown command type: %s\n' % command_type


def _execute_pending_commands(client: S3Client, bucket: str, instance_id: str) -> None:
    prefix = f'commands/{instance_id}/pending/'
    for key in client.list_object_keys(bucket, prefix=prefix):
        command_blob = client.get_object(bucket, key).decode('utf-8')
        command_type, _, command_body = command_blob.partition('\n')
        command_id = Path(key).stem
        exit_code, output = _run_command(command_type, command_body)
        executed_at = dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        result_key = f'results/{instance_id}/{command_id}.json'
        result_payload = json.dumps(
            {
                'command_id': command_id,
                'instance_id': instance_id,
                'exit_code': exit_code,
                'output': output,
                'executed_at': executed_at,
            },
            ensure_ascii=False,
        ).encode('utf-8')
        done_key = key.replace('/pending/', '/done/', 1)
        client.put_object(bucket, result_key, result_payload)
        client.put_object(bucket, done_key, command_blob.encode('utf-8'))
        client.delete_object(bucket, key)
        print(f'[{executed_at}] Done: {command_id} (exit={exit_code})', file=sys.stderr)


def main() -> int:
    if len(sys.argv) != 3:
        print('Usage: agent.py BUCKET INSTANCE_ID', file=sys.stderr)
        return 2

    bucket = sys.argv[1]
    instance_id = sys.argv[2]
    poll_interval = float(os.getenv('POLL_INTERVAL', '3'))
    client = S3Client.from_env(timeout=max(poll_interval, 3.0))
    print(
        f'[{dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")}] '
        f'Agent started: instance={instance_id}, bucket={bucket}, interval={poll_interval}s',
        file=sys.stderr,
    )

    while True:
        try:
            _execute_pending_commands(client, bucket, instance_id)
        except Exception as exc:  # noqa: BLE001
            print(f'[{dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S")}] Error: {exc}', file=sys.stderr)
        time.sleep(poll_interval)


if __name__ == '__main__':
    raise SystemExit(main())
