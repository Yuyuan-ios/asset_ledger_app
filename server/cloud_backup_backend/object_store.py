from __future__ import annotations

import base64
import email.utils
import hashlib
import hmac
import os
import urllib.error
import urllib.parse
import urllib.request
from typing import Optional

from http_helpers import HttpError


class StorageError(Exception):
    pass


class FileObjectStore:
    """Local object store used by tests and one-machine smoke runs."""

    def __init__(self, root_dir: str):
        self.root_dir = root_dir
        os.makedirs(root_dir, exist_ok=True)

    def put_text(self, key: str, body: str, content_type: str = "application/json") -> None:
        path = self._path_for_key(key)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as file:
            file.write(body)

    def get_text(self, key: str) -> str:
        try:
            with open(self._path_for_key(key), "r", encoding="utf-8") as file:
                return file.read()
        except FileNotFoundError as exc:
            raise HttpError(404, "not_found", "backup object not found") from exc

    def delete_text(self, key: str) -> None:
        try:
            os.remove(self._path_for_key(key))
        except FileNotFoundError:
            return

    def _path_for_key(self, key: str) -> str:
        normalized = os.path.normpath(key).replace("\\", "/")
        if normalized.startswith("../") or normalized == ".." or normalized.startswith("/"):
            raise StorageError("invalid object key")
        return os.path.join(self.root_dir, normalized)


class AliyunOssObjectStore:
    """Tiny OSS REST client using Aliyun OSS Signature V1."""

    def __init__(self, endpoint: str, bucket: str, access_key_id: str, access_key_secret: str):
        if not endpoint or not bucket or not access_key_id or not access_key_secret:
            raise ValueError("OSS endpoint, bucket, access key id, and secret are required")
        self.bucket = bucket
        self.access_key_id = access_key_id
        self.access_key_secret = access_key_secret.encode("utf-8")
        self.scheme, self.host = self._resolve_host(endpoint, bucket)

    @staticmethod
    def _resolve_host(endpoint: str, bucket: str) -> tuple[str, str]:
        raw = endpoint.strip().rstrip("/")
        if "://" not in raw:
            raw = "https://" + raw
        parsed = urllib.parse.urlparse(raw)
        scheme = parsed.scheme or "https"
        host = parsed.netloc or parsed.path
        if not host.startswith(f"{bucket}."):
            host = f"{bucket}.{host}"
        return scheme, host

    def put_text(self, key: str, body: str, content_type: str = "application/json") -> None:
        self._request("PUT", key, body.encode("utf-8"), content_type=content_type)

    def get_text(self, key: str) -> str:
        return self._request("GET", key, None, content_type="").decode("utf-8")

    def delete_text(self, key: str) -> None:
        self._request("DELETE", key, None, content_type="")

    def _request(self, method: str, key: str, body: Optional[bytes], content_type: str) -> bytes:
        safe_key = urllib.parse.quote(key, safe="/")
        url = f"{self.scheme}://{self.host}/{safe_key}"
        date_header = email.utils.formatdate(usegmt=True)
        canonical_resource = f"/{self.bucket}/{key}"
        string_to_sign = f"{method}\n\n{content_type}\n{date_header}\n{canonical_resource}"
        digest = hmac.new(self.access_key_secret, string_to_sign.encode("utf-8"), hashlib.sha1).digest()
        signature = base64.b64encode(digest).decode("ascii")
        headers = {
            "Date": date_header,
            "Host": self.host,
            "Authorization": f"OSS {self.access_key_id}:{signature}",
        }
        if content_type:
            headers["Content-Type"] = content_type
        request = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise StorageError(f"OSS {method} failed: {exc.code} {detail}") from exc
        except urllib.error.URLError as exc:
            raise StorageError(f"OSS {method} failed: {exc}") from exc
