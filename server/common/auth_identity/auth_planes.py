from __future__ import annotations

from enum import Enum


class AuthPlane(str, Enum):
    USER = "USER_AUTH_TOKEN"
    SERVICE = "SERVICE_INTERNAL_TOKEN"
    CLIENT = "EXTERNAL_CLIENT_TOKEN"
