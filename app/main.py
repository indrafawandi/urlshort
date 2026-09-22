"""URL Shortener service.

Endpoints:
    POST   /api/v1/links         create a shortened link
    GET    /api/v1/links/{code}  fetch stats for a link (no redirect)
    DELETE /api/v1/links/{code}  delete a link
    GET    /{code}               redirect to the original URL (increments clicks)
    GET    /healthz              liveness/readiness probe for orchestrators
"""
from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session

from app import crud, schemas
from app.config import Settings, get_settings
from app.database import Base, SessionLocal, engine, get_db

# In a larger project this would be replaced by Alembic migrations run as a
# separate release step. For this small service, creating tables at startup
# keeps the "clone and run" experience simple — see docs/ARCHITECTURE.md.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="URL Shortener",
    version="1.0.0",
    description="A minimal, production-shaped URL shortening service.",
)


def _to_out(link, base_url: str) -> schemas.LinkOut:
    return schemas.LinkOut(
        code=link.code,
        original_url=link.original_url,
        short_url=f"{base_url.rstrip('/')}/{link.code}",
        clicks=link.clicks,
        created_at=link.created_at,
    )


@app.get("/healthz", tags=["ops"])
def healthz():
    """Used by Docker/Kubernetes health checks; verifies the DB is reachable."""
    db: Session = SessionLocal()
    try:
        db.execute(__import__("sqlalchemy").text("SELECT 1"))
        return {"status": "ok"}
    finally:
        db.close()


@app.post(
    "/api/v1/links",
    response_model=schemas.LinkOut,
    status_code=status.HTTP_201_CREATED,
    tags=["links"],
)
def create_link(
    payload: schemas.LinkCreate,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
):
    try:
        link = crud.create_link(
            db,
            original_url=str(payload.url),
            code_length=settings.code_length,
            custom_code=payload.custom_code,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return _to_out(link, settings.base_url)


@app.get("/api/v1/links/{code}", response_model=schemas.LinkOut, tags=["links"])
def get_link_stats(
    code: str,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
):
    link = crud.get_link_by_code(db, code)
    if link is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="link not found")
    return _to_out(link, settings.base_url)


@app.delete("/api/v1/links/{code}", status_code=status.HTTP_204_NO_CONTENT, tags=["links"])
def delete_link(code: str, db: Session = Depends(get_db)):
    link = crud.get_link_by_code(db, code)
    if link is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="link not found")
    crud.delete_link(db, link)


@app.get("/{code}", tags=["redirect"])
def redirect_to_original(code: str, db: Session = Depends(get_db)):
    link = crud.get_link_by_code(db, code)
    if link is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="link not found")
    crud.register_click(db, link)
    return RedirectResponse(url=link.original_url, status_code=status.HTTP_307_TEMPORARY_REDIRECT)
