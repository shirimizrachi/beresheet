import 'dart:convert';
import 'package:beresheet_app/model/event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EventService {
  // Use different URLs for web vs mobile platforms
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000/api'; // Web can use localhost
    } else {
      return 'http://10.0.2.2:8000/api'; // Android emulator uses 10.0.2.2
    }
  }

  // Load all events from API
  static Future<List<Event>> loadEvents() async {
    try {
      print('EventService: Attempting to load events from $baseUrl/events');
      final response = await http.get(
        Uri.parse('$baseUrl/events'),
        headers: {'Content-Type': 'application/json'},
      );

      print('EventService: Response status code: ${response.statusCode}');
      print('EventService: Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('EventService: Parsed ${data.length} events from API');
        
        // Get registered events to mark them as registered
        final List<String> registeredEventIds = await getRegisteredEventIds();
        
        final List<Event> events = data.map((eventJson) {
          Event event = Event.fromJson(eventJson);
          // Mark as registered if it's in the local registered list
          if (registeredEventIds.contains(event.id)) {
            event = event.copyWith(isRegistered: true);
          }
          return event;
        }).toList();
        
        print('EventService: Successfully loaded ${events.length} events');
        return events;
      } else {
        print('EventService: Failed to load events with status: ${response.statusCode}');
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      print('EventService: Error loading events from API: $e');
      // Return empty list if API is not available - no fallback to assets
      return [];
    }
  }

  // Fallback method to load from assets if API is not available
  static Future<List<Event>> _loadEventsFromAssets() async {
    try {
      final String response = await rootBundle.loadString('assets/data/events.json');
      final List<dynamic> data = json.decode(response);
      
      final List<String> registeredEventIds = await getRegisteredEventIds();
      
      return data.map((eventJson) {
        Event event = Event.fromJson(eventJson);
        if (registeredEventIds.contains(event.id)) {
          event = event.copyWith(isRegistered: true);
        }
        return event;
      }).toList();
    } catch (e) {
      print('Error loading events from assets: $e');
      return [];
    }
  }

  // Get event by ID from API
  static Future<Event?> getEventById(String eventId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Event.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to get event: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting event by ID: $e');
      return null;
    }
  }

  // Register for an event
  static Future<bool> registerForEvent(Event event) async {
    try {
      // Register via API
      final response = await http.post(
        Uri.parse('$baseUrl/events/${event.id}/register'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Also save to local storage for offline access
        final List<Event> registeredEvents = await getRegisteredEvents();
        
        // Check if already registered locally
        if (!registeredEvents.any((e) => e.id == event.id)) {
          final Event registeredEvent = event.copyWith(isRegistered: true);
          registeredEvents.add(registeredEvent);
          await _saveRegisteredEvents(registeredEvents);
        }
        return true;
      } else {
        throw Exception('Failed to register: ${response.statusCode}');
      }
    } catch (e) {
      print('Error registering for event via API: $e');
      // Fallback to local registration only
      return _registerForEventLocally(event);
    }
  }

  // Fallback local registration
  static Future<bool> _registerForEventLocally(Event event) async {
    try {
      final List<Event> registeredEvents = await getRegisteredEvents();
      
      // Check if already registered
      if (registeredEvents.any((e) => e.id == event.id)) {
        return false; // Already registered
      }

      // Add to registered events
      final Event registeredEvent = event.copyWith(isRegistered: true);
      registeredEvents.add(registeredEvent);
      
      // Save to file
      await _saveRegisteredEvents(registeredEvents);
      return true;
    } catch (e) {
      print('Error registering for event locally: $e');
      return false;
    }
  }

  // Unregister from an event
  static Future<bool> unregisterFromEvent(String eventId) async {
    try {
      // Unregister via API
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/unregister'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Also remove from local storage
        final List<Event> registeredEvents = await getRegisteredEvents();
        registeredEvents.removeWhere((event) => event.id == eventId);
        await _saveRegisteredEvents(registeredEvents);
        return true;
      } else {
        throw Exception('Failed to unregister: ${response.statusCode}');
      }
    } catch (e) {
      print('Error unregistering from event via API: $e');
      // Fallback to local unregistration only
      return _unregisterFromEventLocally(eventId);
    }
  }

  // Fallback local unregistration
  static Future<bool> _unregisterFromEventLocally(String eventId) async {
    try {
      final List<Event> registeredEvents = await getRegisteredEvents();
      
      // Remove the event
      registeredEvents.removeWhere((event) => event.id == eventId);
      
      // Save updated list
      await _saveRegisteredEvents(registeredEvents);
      return true;
    } catch (e) {
      print('Error unregistering from event locally: $e');
      return false;
    }
  }

  // Get events by type
  static Future<List<Event>> getEventsByType(String type) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events?type=$type'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((eventJson) => Event.fromJson(eventJson)).toList();
      } else {
        throw Exception('Failed to load events by type: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading events by type from API: $e');
      // Return empty list if API is not available
      return [];
    }
  }

  // Get upcoming events (events in the future)
  static Future<List<Event>> getUpcomingEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events?upcoming=true'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((eventJson) => Event.fromJson(eventJson)).toList();
      } else {
        throw Exception('Failed to load upcoming events: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading upcoming events from API: $e');
      // Return empty list if API is not available
      return [];
    }
  }

  // Get API statistics
  static Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading stats: $e');
      return null;
    }
  }

  // Create a new event
  static Future<Event?> createEvent({
    required String name,
    required String type,
    required String description,
    required DateTime dateTime,
    required String location,
    required int maxParticipants,
    required String imageUrl,
  }) async {
    try {
      final Map<String, dynamic> eventData = {
        'name': name,
        'type': type,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'location': location,
        'maxParticipants': maxParticipants,
        'image_url': imageUrl,
        'currentParticipants': 0,
        'isRegistered': false,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(eventData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Event.fromJson(responseData);
      } else {
        throw Exception('Failed to create event: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating event: $e');
      return null;
    }
  }

  // Update an existing event
  static Future<Event?> updateEvent({
    required String eventId,
    String? name,
    String? type,
    String? description,
    DateTime? dateTime,
    String? location,
    int? maxParticipants,
    String? imageUrl,
    int? currentParticipants,
  }) async {
    try {
      final Map<String, dynamic> updateData = <String, dynamic>{};
      
      if (name != null) updateData['name'] = name;
      if (type != null) updateData['type'] = type;
      if (description != null) updateData['description'] = description;
      if (dateTime != null) updateData['dateTime'] = dateTime.toIso8601String();
      if (location != null) updateData['location'] = location;
      if (maxParticipants != null) updateData['maxParticipants'] = maxParticipants;
      if (imageUrl != null) updateData['image_url'] = imageUrl;
      if (currentParticipants != null) updateData['currentParticipants'] = currentParticipants;

      final response = await http.put(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updateData),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Event.fromJson(responseData);
      } else {
        throw Exception('Failed to update event: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating event: $e');
      return null;
    }
  }

  // Delete an event
  static Future<bool> deleteEvent(String eventId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Also remove from local registered events if it exists
        final List<Event> registeredEvents = await getRegisteredEvents();
        registeredEvents.removeWhere((event) => event.id == eventId);
        await _saveRegisteredEvents(registeredEvents);
        return true;
      } else {
        throw Exception('Failed to delete event: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  // Local storage methods (for offline support) - Using SharedPreferences for web compatibility
  static const String _registeredEventsKey = 'registered_events';

  static Future<List<Event>> getRegisteredEvents() async {
    try {
      if (kIsWeb) {
        // For web, we can skip local storage since we're always online
        return [];
      }
      
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? eventsJson = prefs.getString(_registeredEventsKey);
      
      if (eventsJson != null) {
        final List<dynamic> data = json.decode(eventsJson);
        return data.map((eventJson) => Event.fromJson(eventJson)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading registered events: $e');
      return [];
    }
  }

  static Future<List<String>> getRegisteredEventIds() async {
    try {
      final List<Event> registeredEvents = await getRegisteredEvents();
      return registeredEvents.map((event) => event.id).toList();
    } catch (e) {
      print('Error getting registered event IDs: $e');
      return [];
    }
  }

  static Future<void> _saveRegisteredEvents(List<Event> events) async {
    try {
      if (kIsWeb) {
        // For web, we can skip local storage since we're always online
        return;
      }
      
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonData =
          events.map((event) => event.toJson()).toList();
      
      await prefs.setString(_registeredEventsKey, json.encode(jsonData));
    } catch (e) {
      print('Error saving registered events: $e');
    }
  }

  static Future<bool> isRegisteredForEvent(String eventId) async {
    try {
      final List<String> registeredEventIds = await getRegisteredEventIds();
      return registeredEventIds.contains(eventId);
    } catch (e) {
      print('Error checking registration status: $e');
      return false;
    }
  }
}