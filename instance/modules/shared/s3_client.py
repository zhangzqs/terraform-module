#!/usr/bin/env python3
"""Stdlib-only S3-compatible client used by the agent and local executor."""

from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import os
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Iterable


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _hmac_sha256(key: bytes, msg: str) -> bytes:
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()


def _aws_quote(value: str, safe: str = '-_.~/') -> str:
    return urllib.parse.quote(value, safe=safe)


def _canonical_query_string(query: str) -> str:
    if not query:
        return ''
    pairs = urllib.parse.parse_qsl(query, keep_blank_values=True)
    encoded = []
    for key, value in pairs:
        encoded.append((urllib.parse.quote(key, safe='-_.~'), urllib.parse.quote(value, safe='-_.~')))
    encoded.sort()
    return '&'.join(f'{key}={value}' for key, value in encoded)


def _strip_ns(tag: str) -> str:
    return tag.rsplit('}', 1)[-1]


def _iter_local_name(root: ET.Element, local_name: str) -> Iterable[ET.Element]:
    for element in root.iter():
        if _strip_ns(element.tag) == local_name:
            yield element


def _normalize_endpoint(endpoint_url: str) -> str:
    if not endpoint_url:
        raise ValueError('endpoint_url is required')
    if not endpoint_url.startswith(('http://', 'https://')):
        endpoint_url = f'https://{endpoint_url}'
    parsed = urllib.parse.urlsplit(endpoint_url)
    path = parsed.path.rstrip('/')
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path, '', ''))


def _to_bytes(value: bytes | str) -> bytes:
    if isinstance(value, bytes):
        return value
    return value.encode('utf-8')


def _env_first(*names: str) -> str:
    for name in names:
        value = os.getenv(name)
        if value:
            return value
    return ''


@dataclass(frozen=True)
class S3Config:
    endpoint_url: str
    access_key_id: str
    secret_access_key: str
    session_token: str | None = None
    region: str | None = None
    timeout: float = 30.0


class S3Error(RuntimeError):
    def __init__(self, status: int, message: str, body: str = ''):
        super().__init__(f'S3 request failed: {status} {message}')
        self.status = status
        self.body = body


class S3Client:
    def __init__(self, config: S3Config):
        self.endpoint_url = _normalize_endpoint(config.endpoint_url)
        self.access_key_id = config.access_key_id
        self.secret_access_key = config.secret_access_key
        self.session_token = config.session_token or None
        self.region = config.region or 'us-east-1'
        self.timeout = config.timeout
        parsed = urllib.parse.urlsplit(self.endpoint_url)
        self._base_path = parsed.path.rstrip('/')
        self._netloc = parsed.netloc
        self._scheme = parsed.scheme

    @classmethod
    def from_env(cls, timeout: float = 30.0) -> 'S3Client':
        endpoint_url = _env_first('S3_ENDPOINT_URL', 'OBJECT_STORE_ENDPOINT_URL')
        access_key_id = _env_first('S3_ACCESS_KEY_ID', 'OBJECT_STORE_ACCESS_KEY_ID', 'AWS_ACCESS_KEY_ID')
        secret_access_key = _env_first('S3_SECRET_ACCESS_KEY', 'OBJECT_STORE_SECRET_ACCESS_KEY', 'AWS_SECRET_ACCESS_KEY')
        session_token = _env_first('S3_SESSION_TOKEN', 'OBJECT_STORE_SESSION_TOKEN', 'AWS_SESSION_TOKEN')
        region = _env_first('S3_REGION', 'OBJECT_STORE_REGION', 'AWS_REGION', 'AWS_DEFAULT_REGION')
        return cls(S3Config(
            endpoint_url=endpoint_url,
            access_key_id=access_key_id,
            secret_access_key=secret_access_key,
            session_token=session_token,
            region=region,
            timeout=timeout,
        ))

    def _object_path(self, bucket: str, key: str = '') -> str:
        parts = []
        if self._base_path:
            parts.append(self._base_path.strip('/'))
        parts.append(_aws_quote(bucket, safe='-_.~'))
        if key:
            parts.append(_aws_quote(key, safe='-_.~/'))
        return '/' + '/'.join(part.strip('/') for part in parts if part)

    def _build_url(self, bucket: str, key: str = '', query: dict[str, str] | None = None) -> str:
        query_string = ''
        if query:
            encoded = []
            for name, value in sorted(query.items()):
                encoded.append((urllib.parse.quote(name, safe='-_.~'), urllib.parse.quote(value, safe='-_.~')))
            query_string = '&'.join(f'{name}={value}' for name, value in encoded)
        return urllib.parse.urlunsplit((self._scheme, self._netloc, self._object_path(bucket, key), query_string, ''))

    def _sign_headers(self, method: str, url: str, body: bytes, headers: dict[str, str] | None = None) -> dict[str, str]:
        parsed = urllib.parse.urlsplit(url)
        now = _utc_now()
        amz_date = now.strftime('%Y%m%dT%H%M%SZ')
        datestamp = now.strftime('%Y%m%d')
        payload_hash = _sha256_hex(body)

        signed_headers = {k.lower(): v.strip() for k, v in (headers or {}).items() if v is not None}
        signed_headers['host'] = parsed.netloc
        signed_headers['x-amz-date'] = amz_date
        signed_headers['x-amz-content-sha256'] = payload_hash
        if self.session_token:
            signed_headers['x-amz-security-token'] = self.session_token

        canonical_headers = ''.join(f'{name}:{signed_headers[name]}\n' for name in sorted(signed_headers))
        signed_header_names = ';'.join(sorted(signed_headers))
        canonical_request = '\n'.join([
            method.upper(),
            _canonical_uri(parsed.path),
            _canonical_query_string(parsed.query),
            canonical_headers,
            signed_header_names,
            payload_hash,
        ])
        scope = f'{datestamp}/{self.region}/s3/aws4_request'
        string_to_sign = '\n'.join([
            'AWS4-HMAC-SHA256',
            amz_date,
            scope,
            _sha256_hex(canonical_request.encode('utf-8')),
        ])

        signing_key = _signing_key(self.secret_access_key, datestamp, self.region, 's3')
        signature = hmac.new(signing_key, string_to_sign.encode('utf-8'), hashlib.sha256).hexdigest()
        signed_headers['authorization'] = (
            'AWS4-HMAC-SHA256 '
            f'Credential={self.access_key_id}/{scope}, '
            f'SignedHeaders={signed_header_names}, '
            f'Signature={signature}'
        )
        return signed_headers

    def _request(self, method: str, url: str, body: bytes = b'', headers: dict[str, str] | None = None) -> tuple[int, dict[str, str], bytes]:
        signed = self._sign_headers(method, url, body, headers)
        request = urllib.request.Request(url, data=body if method.upper() in {'PUT', 'POST'} else None, method=method.upper())
        for name, value in signed.items():
            if name == 'host':
                continue
            request.add_header(name, value)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                return response.status, dict(response.headers.items()), response.read()
        except urllib.error.HTTPError as exc:
            payload = exc.read() if exc.fp else b''
            raise S3Error(exc.code, exc.reason, payload.decode('utf-8', 'replace')) from exc

    def list_object_keys(self, bucket: str, prefix: str = '') -> list[str]:
        keys: list[str] = []
        continuation_token: str | None = None
        while True:
            query = {'list-type': '2', 'encoding-type': 'url'}
            if prefix:
                query['prefix'] = prefix
            if continuation_token:
                query['continuation-token'] = continuation_token
            url = self._build_url(bucket, query=query)
            _, _, body = self._request('GET', url)
            root = ET.fromstring(body)
            for element in _iter_local_name(root, 'Key'):
                if element.text:
                    keys.append(urllib.parse.unquote(element.text))
            truncated = next((element.text for element in _iter_local_name(root, 'IsTruncated') if element.text is not None), 'false')
            if truncated.lower() != 'true':
                break
            continuation_token = next((element.text for element in _iter_local_name(root, 'NextContinuationToken') if element.text), None)
            if not continuation_token:
                break
        return keys

    def get_object(self, bucket: str, key: str) -> bytes:
        url = self._build_url(bucket, key=key)
        _, _, body = self._request('GET', url)
        return body

    def put_object(self, bucket: str, key: str, data: bytes | str) -> None:
        url = self._build_url(bucket, key=key)
        self._request('PUT', url, body=_to_bytes(data))

    def delete_object(self, bucket: str, key: str) -> None:
        try:
            url = self._build_url(bucket, key=key)
            self._request('DELETE', url)
        except S3Error as exc:
            if exc.status != 404:
                raise

    def head_object(self, bucket: str, key: str) -> bool:
        try:
            url = self._build_url(bucket, key=key)
            self._request('HEAD', url)
            return True
        except S3Error as exc:
            if exc.status == 404:
                return False
            raise


def _canonical_uri(path: str) -> str:
    if not path:
        return '/'
    if not path.startswith('/'):
        path = '/' + path
    segments = path.split('/')
    quoted = [_aws_quote(segment, safe='-_.~/') for segment in segments if segment]
    return '/' + '/'.join(quoted)


def _signing_key(secret: str, datestamp: str, region: str, service: str) -> bytes:
    k_date = _hmac_sha256(('AWS4' + secret).encode('utf-8'), datestamp)
    k_region = hmac.new(k_date, region.encode('utf-8'), hashlib.sha256).digest()
    k_service = hmac.new(k_region, service.encode('utf-8'), hashlib.sha256).digest()
    return hmac.new(k_service, b'aws4_request', hashlib.sha256).digest()
