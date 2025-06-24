"""
Shared/Common Pydantic models

This file now contains only shared models that are used across multiple modules.
Module-specific models have been moved to their respective modules:
- Events models: modules/events/models.py
- Users models: modules/users/models.py
"""

from pydantic import BaseModel
from typing import Optional

# Note: All models have been moved to their respective modules:
# - Event-related models (including Room models): modules/events/models.py and modules/events/events_room.py
# - User-related models: modules/users/models.py
# - Service request models: modules/service_requests/models.py

# This file is now reserved for truly shared models that are used across multiple modules
# Currently no shared models exist - all models are module-specific