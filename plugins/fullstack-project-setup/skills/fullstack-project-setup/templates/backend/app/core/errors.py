"""
RFC 7807 Problem Details error contract — decision #6. This is the ONLY
error shape the API ever returns. packages/core/src/errors.ts on the
frontend is the exact mirror of `ProblemDetail` below; don't let them drift
— if you add a field here, add it to the TS type too.
"""

import logging
from collections.abc import Awaitable, Callable

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class FieldError(BaseModel):
    field: str
    message: str


class ProblemDetail(BaseModel):
    """
    `errors` is a project-defined extension for field-level validation — NOT
    part of RFC 7807 itself. This is the one shape used for it everywhere;
    don't invent a second field-error format on a specific endpoint.
    """

    type: str = "about:blank"
    title: str
    status: int
    detail: str | None = None
    instance: str | None = None
    errors: list[FieldError] | None = None


class NotFoundError(Exception):
    def __init__(self, title: str = "Resource not found", detail: str | None = None):
        self.title = title
        self.detail = detail


class ValidationAppError(Exception):
    """Raise this from a service/repository for a domain validation failure
    that should surface as field-level errors — distinct from FastAPI's own
    request-schema validation (RequestValidationError), which is handled
    separately below but normalized to the same ProblemDetail shape."""

    def __init__(self, errors: list[FieldError], title: str = "Validation failed"):
        self.errors = errors
        self.title = title


def _problem_response(problem: ProblemDetail) -> JSONResponse:
    return JSONResponse(
        status_code=problem.status,
        content=problem.model_dump(exclude_none=True),
        media_type="application/problem+json",
    )


def register_exception_handlers(app: FastAPI) -> None:
    settings = get_settings()

    @app.exception_handler(NotFoundError)
    async def handle_not_found(_: Request, exc: NotFoundError) -> JSONResponse:
        return _problem_response(
            ProblemDetail(
                title=exc.title,
                status=status.HTTP_404_NOT_FOUND,
                detail=exc.detail,
            )
        )

    @app.exception_handler(ValidationAppError)
    async def handle_validation_app_error(_: Request, exc: ValidationAppError) -> JSONResponse:
        return _problem_response(
            ProblemDetail(
                title=exc.title,
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
                errors=exc.errors,
            )
        )

    @app.exception_handler(RequestValidationError)
    async def handle_request_validation_error(
        _: Request, exc: RequestValidationError
    ) -> JSONResponse:
        field_errors = [
            FieldError(field=".".join(str(p) for p in err["loc"][1:]), message=err["msg"])
            for err in exc.errors()
        ]
        return _problem_response(
            ProblemDetail(
                title="Validation failed",
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
                errors=field_errors,
            )
        )

    @app.exception_handler(StarletteHTTPException)
    async def handle_http_exception(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        return _problem_response(
            ProblemDetail(
                title=str(exc.detail),
                status=exc.status_code,
            )
        )

    @app.exception_handler(Exception)
    async def handle_unhandled_exception(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled exception")
        # Prod-vs-dev detail suppression is a HARD requirement (decision #6)
        # — never leak internals in production responses.
        detail = None if settings.is_production else str(exc)
        return _problem_response(
            ProblemDetail(
                title="Internal server error",
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=detail,
            )
        )


ExceptionHandler = Callable[[Request, Exception], Awaitable[JSONResponse]]
