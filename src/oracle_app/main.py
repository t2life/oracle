from __future__ import annotations

from .api import create_app
from .config import AppConfig
from .logging_utils import configure_logging

app_config = AppConfig()
configure_logging(app_config.logger_level)
app = create_app(config=app_config)
