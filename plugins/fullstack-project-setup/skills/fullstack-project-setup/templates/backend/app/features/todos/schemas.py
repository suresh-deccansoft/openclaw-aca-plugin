import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

# Mirrors packages/core/src/domains/todo.ts's zod schema field-for-field.
# openapi-typescript regenerates the TS types from this automatically
# (decision #6) — if you change a field here, run
# `pnpm --filter @{{PROJECT_SLUG}}/core generate` after, don't hand-edit
# api-types.ts.


class TodoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    title: str
    is_completed: bool = Field(serialization_alias="isCompleted")
    created_at: datetime = Field(serialization_alias="createdAt")


class TodoCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
