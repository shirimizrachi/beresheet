# Recurring Events System Documentation

## Overview

The Beresheet app now supports a sophisticated recurring events system that allows for flexible scheduling of repeating events. This system separates the concept of an "initial event date" from the actual recurring schedule pattern.

## Key Concepts

### 1. Initial Event Date (`dateTime`)
- This is the **creation/reference date** for the recurring event series
- It serves as the starting point for the recurring series
- For non-recurring events, this is the actual event date
- For recurring events, this may not be the first actual occurrence

### 2. Recurrence Pattern (`recurringPattern`)
- JSON object containing the actual scheduling rules
- Defines when the events actually occur
- Takes precedence over the initial `dateTime` for recurring events

### 3. End Date (`recurringEndDate`)
- Defines when the recurring series stops
- Required for all recurring events

## Supported Recurrence Types

### 1. None (`none`)
- Single occurrence event
- Uses the `dateTime` as the actual event date
- No `recurringPattern` needed

### 2. Weekly (`weekly`)
- Event occurs every week on a specific day
- Pattern: `{"dayOfWeek": X, "time": "HH:MM"}`
- `dayOfWeek`: 0=Sunday, 1=Monday, ..., 6=Saturday

### 3. Bi-Weekly (`bi-weekly`)
- Event occurs every two weeks on a specific day
- Pattern: `{"dayOfWeek": X, "time": "HH:MM", "interval": 2}`
- Same day numbering as weekly

### 4. Monthly (`monthly`)
- Event occurs on a specific day of each month
- Pattern: `{"dayOfMonth": X, "time": "HH:MM"}`
- `dayOfMonth`: 1-31

## Data Structure Examples

### Weekly Event Example
```json
{
  "id": "art-therapy-wed",
  "name": "טיפול באמנות",
  "dateTime": "2025-06-20T20:00:25.400Z",
  "recurring": "weekly",
  "recurringEndDate": "2025-09-17T20:00:25.400Z",
  "recurringPattern": "{\"dayOfWeek\": 3, \"time\": \"14:00\"}"
}
```

**Explanation:**
- Created on June 20, 2025 (Friday)
- Actually occurs every Wednesday at 2:00 PM
- First actual occurrence: June 25, 2025 (next Wednesday after creation)
- Continues until September 17, 2025

### Monthly Event Example
```json
{
  "id": "birthday-party",
  "name": "חגיגת יום הולדת קבוצתית",
  "dateTime": "2025-07-02T20:00:25.400Z",
  "recurring": "monthly",
  "recurringEndDate": "2025-12-17T20:00:25.400Z",
  "recurringPattern": "{\"dayOfMonth\": 15, \"time\": \"15:00\"}"
}
```

**Explanation:**
- Created on July 2, 2025
- Actually occurs on the 15th of each month at 3:00 PM
- First actual occurrence: July 15, 2025
- Continues until December 17, 2025

### Bi-Weekly Event Example
```json
{
  "id": "book-club-wed",
  "name": "מועדון קריאה",
  "dateTime": "2025-06-27T20:00:25.400Z",
  "recurring": "bi-weekly",
  "recurringEndDate": "2025-09-17T20:00:25.400Z",
  "recurringPattern": "{\"dayOfWeek\": 3, \"time\": \"17:00\", \"interval\": 2}"
}
```

**Explanation:**
- Created on June 27, 2025 (Friday)
- Actually occurs every other Wednesday at 5:00 PM
- Uses `interval: 2` to specify bi-weekly
- First actual occurrence: July 2, 2025 (next Wednesday after creation)

## Implementation Changes

### 1. Flutter Model (`lib/model/event.dart`)
- Added `RecurrencePattern` class for parsing JSON patterns
- Added helper methods `parsedRecurrencePattern` and `isRecurring`
- Enhanced JSON serialization/deserialization

### 2. API Models (`api_service/models.py`)
- Added `RecurrencePatternData` Pydantic model
- Updated field descriptions and validation
- Added bi-weekly to recurring options

### 3. Web UI (`lib/screen/web/events/event_form_web.dart`)
- Comprehensive recurring configuration UI
- Separate fields for:
  - Initial reference date/time
  - Recurring schedule configuration (day of week, day of month, time)
  - End date
- Dynamic field visibility based on recurrence type
- Pattern validation before saving

### 4. Configuration Updates
- Added `AppConfig.eventRecurringBiWeekly` constant
- Updated display name utilities
- Added localization for bi-weekly option

## Database Schema

The database should support these fields:
- `dateTime`: DATETIME - Initial reference date
- `recurring`: VARCHAR - Type of recurrence
- `recurring_end_date`: DATETIME - When series ends
- `recurring_pattern`: TEXT - JSON pattern details

## Usage Patterns

### Creating a Weekly Event
1. Set initial `dateTime` (any date for reference)
2. Select "Weekly" recurrence
3. Choose day of week (0-6)
4. Set recurring time
5. Set end date
6. System generates pattern: `{"dayOfWeek": X, "time": "HH:MM"}`

### Creating a Monthly Event
1. Set initial `dateTime` (any date for reference)
2. Select "Monthly" recurrence
3. Choose day of month (1-31)
4. Set recurring time
5. Set end date
6. System generates pattern: `{"dayOfMonth": X, "time": "HH:MM"}`

### Creating a One-Time Event
1. Set `dateTime` to actual event date/time
2. Select "None" recurrence
3. No pattern or end date needed

## Benefits of This Design

1. **Flexibility**: Can create recurring events on any day, with actual occurrences on different days
2. **Clarity**: Clear separation between creation context and actual schedule
3. **Extensibility**: Easy to add new recurrence types (yearly, custom intervals, etc.)
4. **Consistency**: All recurring events follow the same pattern structure
5. **User-Friendly**: Intuitive UI that clearly shows the difference between reference date and recurring schedule

## Future Enhancements

Potential additions:
- Yearly recurrence
- Custom intervals (every N weeks/months)
- Multiple days per week (e.g., Monday and Wednesday)
- Exception dates (skip specific occurrences)
- Dynamic end dates (e.g., after N occurrences)