# Beresheet Community App

A Flutter application for managing community events with both mobile app and web versions.

## Features

### Mobile App
- Browse upcoming events
- Register/unregister for events
- View registered events
- **Event Management** (NEW):
  - Add new events
  - Edit existing events
  - Delete events
  - Full CRUD operations via API

### Web Version
- **Event Carousel**: Beautiful homepage with rotating event display
- **Event Management**: Same management capabilities as mobile app
- Responsive design optimized for web browsers

## Project Structure

```
beresheet_app/
├── lib/
│   ├── main.dart              # Mobile app entry point
│   ├── main_web.dart          # Web app entry point
│   ├── screen/
│   │   ├── homepage.dart           # Mobile homepage
│   │   ├── web_homepage.dart       # Web homepage with carousel
│   │   ├── events_management_screen.dart  # Events CRUD interface
│   │   └── event_form_screen.dart         # Add/Edit event form
│   └── services/
│       └── event_service.dart # Enhanced with CRUD operations
├── api_service/
│   ├── main.py                # FastAPI backend
│   ├── database.py            # Event database with GUID IDs
│   └── data/
│       └── events.json        # Events with GUID IDs
└── web/                       # Flutter web configuration
```

## Getting Started

### Quick Start (Recommended)

#### Windows:
```bash
build_and_serve.bat
```

#### Linux/Mac:
```bash
chmod +x build_and_serve.sh
./build_and_serve.sh
```

This will automatically:
- Build the Flutter web app
- Create and activate Python virtual environment
- Install Python dependencies
- Start the combined server on `http://localhost:8000`

**URLs:**
- **Web App**: http://localhost:8000/web
- **API**: http://localhost:8000/api
- **API Documentation**: http://localhost:8000/docs

### Manual Setup

#### 1. Build Flutter Web App

```bash
flutter build web --target lib/main_web.dart --base-href /web/
```

#### 2. Start the Combined Server

```bash
cd api_service
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python main.py
```

The server will be available at:
- **Web App**: `http://localhost:8000/web`
- **API**: `http://localhost:8000/api`
- **API Docs**: `http://localhost:8000/docs`

#### 3. Run the Mobile App (separate process)

```bash
flutter run
```

## API Endpoints

All API endpoints are prefixed with `/api`:

- `GET /api/events` - List all events
- `POST /api/events` - Create new event
- `PUT /api/events/{id}` - Update event
- `DELETE /api/events/{id}` - Delete event
- `GET /api/events/{id}` - Get specific event
- `POST /api/events/{id}/register` - Register for event
- `POST /api/events/{id}/unregister` - Unregister from event

## Web Routes

- `GET /` - Redirects to web app
- `GET /web` - Flutter web application
- `GET /docs` - API documentation (Swagger UI)

## Event Management Features

### In the Mobile App:
1. Open the side menu
2. Tap "Manage Events"
3. View all events in a list
4. Use the + button to add new events
5. Tap on any event to edit
6. Use the menu (⋮) to delete events

### In the Web Version:
1. Visit the homepage to see the event carousel
2. Click "Manage Events" button
3. Same management interface as mobile app
4. Optimized for larger screens

## Event Data Structure

Events now use GUID IDs and include:
- `id`: Unique GUID identifier
- `name`: Event name
- `type`: Event category (class, performance, cultural, leisure)
- `description`: Event description
- `dateTime`: Event date and time
- `location`: Event location
- `maxParticipants`: Maximum attendees
- `currentParticipants`: Current attendees
- `image_url`: Event image URL
- `isRegistered`: User registration status

## Development Notes

- The app uses the same EventService for both mobile and web
- All CRUD operations go through the FastAPI backend
- GUID IDs ensure unique identification across platforms
- **Web Compatibility**: Uses SharedPreferences instead of file system for web support
- Web version includes auto-scrolling carousel
- Responsive design adapts to different screen sizes
- Local storage is disabled on web (assumes always online)

## Troubleshooting

### Web Version Issues
If you see errors like `MissingPluginException` for `getApplicationDocumentsDirectory`, this is expected behavior. The web version uses SharedPreferences instead of file system access, which is not available in browsers.

### API Connection Issues
- Make sure the API service is running on `http://localhost:8000`
- Check that no firewall is blocking the connection
- Verify Python dependencies are installed correctly

### Flutter Web Not Loading
- Make sure Chrome is installed and set as default browser
- Try running `flutter clean` and `flutter pub get` before starting
- Check that you're using the correct target: `--target lib/main_web.dart`

## Requirements

- Flutter SDK
- Python 3.8+
- FastAPI
- Chrome browser (for web development)

Server=localhost\SQLEXPRESS;Database=master;Trusted_Connection=True;

flutter gen-l10n