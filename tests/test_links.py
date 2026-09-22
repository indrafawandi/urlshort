def test_health_check(client):
    resp = client.get("/healthz")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_create_link_generates_code(client):
    resp = client.post("/api/v1/links", json={"url": "https://example.com/some/page"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["original_url"] == "https://example.com/some/page"
    assert body["clicks"] == 0
    assert len(body["code"]) == 7
    assert body["short_url"].endswith(body["code"])


def test_create_link_with_custom_code(client):
    resp = client.post(
        "/api/v1/links", json={"url": "https://example.com", "custom_code": "my-link"}
    )
    assert resp.status_code == 201
    assert resp.json()["code"] == "my-link"


def test_create_link_with_duplicate_custom_code_conflicts(client):
    client.post("/api/v1/links", json={"url": "https://example.com", "custom_code": "dup"})
    resp = client.post("/api/v1/links", json={"url": "https://other.com", "custom_code": "dup"})
    assert resp.status_code == 409


def test_create_link_rejects_invalid_custom_code(client):
    resp = client.post(
        "/api/v1/links", json={"url": "https://example.com", "custom_code": "a b!"}
    )
    assert resp.status_code == 422


def test_create_link_rejects_invalid_url(client):
    resp = client.post("/api/v1/links", json={"url": "not-a-url"})
    assert resp.status_code == 422


def test_get_link_stats(client):
    created = client.post("/api/v1/links", json={"url": "https://example.com"}).json()
    resp = client.get(f"/api/v1/links/{created['code']}")
    assert resp.status_code == 200
    assert resp.json()["code"] == created["code"]


def test_get_link_stats_404_for_unknown_code(client):
    resp = client.get("/api/v1/links/does-not-exist")
    assert resp.status_code == 404


def test_redirect_increments_click_count(client):
    created = client.post("/api/v1/links", json={"url": "https://example.com"}).json()
    code = created["code"]

    redirect = client.get(f"/{code}", follow_redirects=False)
    assert redirect.status_code == 307
    assert redirect.headers["location"] == "https://example.com/"

    stats = client.get(f"/api/v1/links/{code}").json()
    assert stats["clicks"] == 1

    client.get(f"/{code}", follow_redirects=False)
    stats = client.get(f"/api/v1/links/{code}").json()
    assert stats["clicks"] == 2


def test_redirect_404_for_unknown_code(client):
    resp = client.get("/unknown-code", follow_redirects=False)
    assert resp.status_code == 404


def test_delete_link(client):
    created = client.post("/api/v1/links", json={"url": "https://example.com"}).json()
    code = created["code"]

    resp = client.delete(f"/api/v1/links/{code}")
    assert resp.status_code == 204

    resp = client.get(f"/api/v1/links/{code}")
    assert resp.status_code == 404


def test_delete_unknown_link_404s(client):
    resp = client.delete("/api/v1/links/does-not-exist")
    assert resp.status_code == 404
