import re
from datetime import datetime

from pydantic import BaseModel, ConfigDict, HttpUrl, field_validator

CUSTOM_CODE_RE = re.compile(r"^[A-Za-z0-9_-]{3,32}$")


class LinkCreate(BaseModel):
    url: HttpUrl
    custom_code: str | None = None

    @field_validator("custom_code")
    @classmethod
    def validate_custom_code(cls, v: str | None) -> str | None:
        if v is not None and not CUSTOM_CODE_RE.match(v):
            raise ValueError(
                "custom_code must be 3-32 characters, using only letters, "
                "digits, hyphens and underscores"
            )
        return v


class LinkOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    original_url: str
    short_url: str
    clicks: int
    created_at: datetime
