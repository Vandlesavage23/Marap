"""In-process domain events dispatched after commit (Bible §6.2).

Handlers that do I/O must enqueue Celery tasks. Visibility-affecting side effects (e.g. block) are NOT
events — services call each other directly inside the same transaction.
"""

import logging
from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any, TypeVar

from django.db import transaction

logger = logging.getLogger(__name__)

E = TypeVar("E")
_handlers: dict[type, list[Callable[[Any], None]]] = defaultdict(list)


@dataclass(frozen=True)
class DomainEvent:
    """Base class for events; subclasses carry ids only (no PII)."""


def subscribe(event_type: type[E]) -> Callable[[Callable[[E], None]], Callable[[E], None]]:
    def decorator(handler: Callable[[E], None]) -> Callable[[E], None]:
        if handler not in _handlers[event_type]:
            _handlers[event_type].append(handler)
        return handler

    return decorator


def publish(event: DomainEvent) -> None:
    """Dispatch `event` to subscribers once the current transaction commits."""

    def dispatch() -> None:
        for handler in list(_handlers.get(type(event), [])):
            try:
                handler(event)
            except Exception:  # one failing handler must not block others
                logger.exception("event handler failed", extra={"event": type(event).__name__})

    transaction.on_commit(dispatch)


def clear_handlers() -> None:  # test helper
    _handlers.clear()
