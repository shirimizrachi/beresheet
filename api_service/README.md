# Beresheet Events API

A FastAPI-based REST API service for managing events in the Beresheet Flutter application. This API provides CRUD operations for events and serves both Flutter mobile and web applications.

## Features

- **CRUD Operations**: Create, Read, Update, Delete events
- **Event Registration**: Register/unregister for events
- **Filtering**: Filter events by type and get upcoming events
- **Statistics**: Get API usage statistics
- **CORS Support**: Configured for Flutter web and mobile applications
- **Auto Documentation**: Interactive API documentation with Swagger UI

## Installation

1. **Navigate to the API service directory:**
   ```bash
   cd api_service
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Running the Server

### Option 1: Using the startup script (Recommended)
```bash
python start_server.py
```

### Option 2: Using uvicorn directly
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Option 3: Running the main module
```bash
python main.py
```

## API Endpoints

The server will start on `http://localhost:8000`

### Core Endpoints

- **Root**: `GET /` - API information
- **Health Check**: `GET /health` - Server health status
- **API Documentation**: `GET /docs` - Interactive Swagger UI documentation

### Tenant-Aware Events CRUD

**Note**: All endpoints now require a tenant name. Replace `{tenant_name}` with your organization name (e.g., "beresheet").

- **Get All Events**: `GET /{tenant_name}/api/events`
  - Query Parameters:
    - `type` (optional): Filter by event type
    - `upcoming` (optional): Get only upcoming events
  - Headers: `homeID: {tenant_id}` (required)
- **Get Event by ID**: `GET /{tenant_name}/api/events/{event_id}`
- **Create Event**: `POST /{tenant_name}/api/events`
- **Update Event**: `PUT /{tenant_name}/api/events/{event_id}`
- **Delete Event**: `DELETE /{tenant_name}/api/events/{event_id}`

### Event Registration

- **Register for Event**: `POST /{tenant_name}/api/events/{event_id}/register`
- **Unregister from Event**: `POST /{tenant_name}/api/events/{event_id}/unregister`

### Filtering & Statistics

- **Get Events by Type**: `GET /{tenant_name}/api/events/types/{event_type}`
- **Get Upcoming Events**: `GET /{tenant_name}/api/events/upcoming/all`
- **Get Statistics**: `GET /stats`

### Legacy Endpoints (Deprecated)

⚠️ **These endpoints are no longer available:**
- `GET /api/events` → Use `GET /{tenant_name}/api/events`
- `GET /events` → Use `GET /{tenant_name}/api/events`

## Event Data Structure

```json
{
  "id": "string",
  "name": "string",
  "type": "string",
  "description": "string", 
  "date_time": "2025-06-09T10:00:00",
  "location": "string",
  "max_participants": 15,
  "current_participants": 8,
  "image_url": "string",
  "isRegistered": false
}
```

### Event Types
- `class` - Educational classes
- `performance` - Shows and performances
- `cultural` - Cultural activities
- `leisure` - Leisure activities

## Usage Examples

**Note**: Replace `beresheet` with your tenant name and `1` with your tenant's homeID.

### Get All Events
```bash
curl http://localhost:8000/beresheet/api/events \
  -H "homeID: 1"
```

### Get Upcoming Events Only
```bash
curl http://localhost:8000/beresheet/api/events?upcoming=true \
  -H "homeID: 1"
```

### Get Events by Type
```bash
curl http://localhost:8000/beresheet/api/events?type=class \
  -H "homeID: 1"
```

### Create a New Event
```bash
curl -X POST http://localhost:8000/beresheet/api/events \
  -H "Content-Type: application/json" \
  -H "homeID: 1" \
  -d '{
    "name": "New Yoga Class",
    "type": "class",
    "description": "Relaxing yoga session",
    "date_time": "2025-06-15T10:00:00",
    "location": "Wellness Room",
    "max_participants": 20,
    "image_url": "https://example.com/image.jpg"
  }'
```

### Register for an Event
```bash
curl -X POST http://localhost:8000/beresheet/api/events/1/register \
  -H "homeID: 1"
```

### Legacy Examples (No longer work)
```bash
# ❌ These will return 404 errors:
curl http://localhost:8000/events
curl http://localhost:8000/api/events
```

## Integration with Flutter App

### Update Flutter Dependencies

Add HTTP package to your `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.1.0
```

### Update Event Service

The Flutter app's `EventService` should be updated to make HTTP requests to this API instead of loading from JSON assets.

Example API base URL for local development:
- **Local Development**: `http://localhost:8000`
- **Production**: Update to your deployed API URL

## Data Storage

- Events are stored in `events_data.json` file
- Initial data is loaded from the original `../assets/data/events.json`
- Data is automatically saved when events are created, updated, or deleted

## Development

### Project Structure
```
api_service/
├── main.py              # FastAPI application
├── models.py            # Pydantic models
├── database.py          # Database operations
├── start_server.py      # Server startup script
├── requirements.txt     # Python dependencies
├── README.md           # This file
└── events_data.json    # Event data storage (created automatically)
```

### Adding New Features

1. **New Models**: Add to `models.py`
2. **New Endpoints**: Add to `main.py`
3. **New Database Operations**: Add to `database.py`

## Production Deployment

For production deployment, consider:

1. **Environment Variables**: Use environment variables for configuration
2. **Database**: Replace JSON file storage with a proper database (PostgreSQL, MongoDB, etc.)
3. **Authentication**: Add user authentication and authorization
4. **HTTPS**: Enable HTTPS for secure communication
5. **Rate Limiting**: Add rate limiting for API endpoints
6. **Logging**: Implement proper logging
7. **Docker**: Containerize the application

## Troubleshooting

### Common Issues

1. **Port 8000 already in use**:
   ```bash
   # Find and kill the process using port 8000
   netstat -ano | findstr :8000
   taskkill /PID <PID> /F
   ```

2. **Module not found errors**:
   ```bash
   # Make sure you're in the api_service directory
   cd api_service
   # Install dependencies
   pip install -r requirements.txt
   ```

3. **CORS issues**:
   - The API is configured to allow all origins for development
   - For production, update the CORS settings in `main.py`

## API Documentation

Once the server is running, visit `http://localhost:8000/docs` for interactive API documentation with Swagger UI.