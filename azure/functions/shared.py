import os
from datetime import datetime, timedelta
from typing import Optional


def get_env(name: str, default: Optional[str] = None) -> str:
    v = os.environ.get(name, default)
    if v is None:
        raise RuntimeError(f"Missing environment variable: {name}")
    return v


def ttl_minutes(minutes: int = 10):
    return datetime.utcnow() + timedelta(minutes=minutes)

