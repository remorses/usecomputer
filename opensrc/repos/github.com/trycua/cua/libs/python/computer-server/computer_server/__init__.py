"""
Computer API package.
Provides a server interface for the Computer API.
"""

from __future__ import annotations

__version__: str = "0.1.0"

# Explicitly export Server for static type checkers
from .server import Server as Server  # noqa: F401

__all__ = ["Server", "run_cli"]


def run_cli() -> None:
    """Entry point for CLI"""
    from .cli import main

    main()
