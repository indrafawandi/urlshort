"""Data-access helpers, kept separate from the HTTP layer so the persistence
logic can be unit tested (or swapped) without spinning up FastAPI.
"""
import secrets
import string

from sqlalchemy.orm import Session

from app import models

_ALPHABET = string.ascii_letters + string.digits


def generate_code(length: int) -> str:
    return "".join(secrets.choice(_ALPHABET) for _ in range(length))


def get_link_by_code(db: Session, code: str) -> models.Link | None:
    return db.query(models.Link).filter(models.Link.code == code).first()


def create_link(db: Session, original_url: str, code_length: int, custom_code: str | None) -> models.Link:
    if custom_code:
        if get_link_by_code(db, custom_code) is not None:
            raise ValueError(f"code '{custom_code}' is already taken")
        code = custom_code
    else:
        # Extremely unlikely to collide at this length, but guard anyway
        # rather than trusting probability in a production system.
        code = generate_code(code_length)
        while get_link_by_code(db, code) is not None:
            code = generate_code(code_length)

    link = models.Link(code=code, original_url=original_url)
    db.add(link)
    db.commit()
    db.refresh(link)
    return link


def register_click(db: Session, link: models.Link) -> models.Link:
    link.clicks += 1
    db.commit()
    db.refresh(link)
    return link


def delete_link(db: Session, link: models.Link) -> None:
    db.delete(link)
    db.commit()
