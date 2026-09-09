import pytest


@pytest.mark.anyio
async def test_create_and_list_todo(client):
    create_response = await client.post("/todos", json={"title": "Write the skill"})
    assert create_response.status_code == 201
    body = create_response.json()
    assert body["title"] == "Write the skill"
    assert body["isCompleted"] is False

    list_response = await client.get("/todos")
    assert list_response.status_code == 200
    titles = [t["title"] for t in list_response.json()]
    assert "Write the skill" in titles


@pytest.mark.anyio
async def test_create_todo_validation_error_is_rfc7807(client):
    # Empty title violates TodoCreate's min_length — should come back as the
    # shared RFC 7807 shape (decision #6), not a bespoke error format.
    response = await client.post("/todos", json={"title": ""})
    assert response.status_code == 422
    assert response.headers["content-type"] == "application/problem+json"
    body = response.json()
    assert body["errors"][0]["field"] == "title"
