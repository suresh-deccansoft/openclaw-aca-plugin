from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.features.todos.router import router as todos_router

settings = get_settings()

app = FastAPI(title="{{PROJECT_NAME}}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Common error middleware — decision #6. Every route in every feature module
# raises the shared exceptions from app.core.errors; nothing registers its
# own ad hoc error handling.
register_exception_handlers(app)

# New feature module? Add its router here — see
# app/features/todos/ for the vertical-slice shape (decision #11).
app.include_router(todos_router)
