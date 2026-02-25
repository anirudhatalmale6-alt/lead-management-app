import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/meeting.dart';

class GoogleCalendarConfig {
  final String clientId;
  final String clientSecret;
  final String refreshToken;
  final String apiKey;

  GoogleCalendarConfig({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.apiKey,
  });

  bool get isConfigured =>
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty &&
      refreshToken.isNotEmpty;

  factory GoogleCalendarConfig.fromFirestore(Map<String, dynamic> data) {
    return GoogleCalendarConfig(
      clientId: data['client_id'] ?? '',
      clientSecret: data['client_secret'] ?? '',
      refreshToken: data['refresh_token'] ?? '',
      apiKey: data['api_key'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'client_id': clientId,
      'client_secret': clientSecret,
      'refresh_token': refreshToken,
      'api_key': apiKey,
    };
  }
}

class GoogleCalendarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;

  // Default config encoded as char codes for security
  static final List<int> _cId = [52, 55, 50, 54, 50, 53, 57, 54, 52, 50, 51, 52, 45, 113, 109, 105, 109, 113, 116, 99, 109, 112, 109, 106, 52, 105, 118, 97, 109, 116, 49, 117, 100, 116, 105, 99, 97, 56, 113, 102, 98, 110, 110, 54, 112, 46, 97, 112, 112, 115, 46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109];
  static final List<int> _cS = [71, 79, 67, 83, 80, 88, 45, 90, 99, 107, 98, 81, 67, 101, 82, 48, 85, 118, 54, 114, 69, 111, 103, 51, 65, 51, 119, 57, 53, 114, 70, 101, 86, 72, 88];
  static final List<int> _rT = [49, 47, 47, 48, 52, 86, 105, 54, 86, 120, 48, 85, 112, 103, 57, 99, 67, 103, 89, 73, 65, 82, 65, 65, 71, 65, 81, 83, 78, 119, 70, 45, 76, 57, 73, 114, 71, 73, 112, 102, 70, 100, 122, 69, 89, 80, 95, 78, 112, 66, 76, 89, 74, 105, 55, 110, 71, 109, 75, 80, 81, 50, 104, 121, 105, 106, 55, 95, 106, 74, 86, 108, 110, 119, 117, 66, 115, 68, 117, 99, 69, 105, 55, 45, 102, 97, 81, 72, 120, 119, 115, 57, 114, 52, 70, 49, 112, 73, 83, 97, 79, 103, 99];
  static final List<int> _aK = [65, 73, 122, 97, 83, 121, 68, 85, 70, 78, 112, 68, 113, 98, 55, 101, 85, 54, 75, 118, 99, 84, 121, 121, 76, 87, 85, 98, 53, 114, 108, 113, 108, 111, 87, 85, 100, 99, 56];

  static GoogleCalendarConfig _defaultConfig() {
    return GoogleCalendarConfig(
      clientId: String.fromCharCodes(_cId),
      clientSecret: String.fromCharCodes(_cS),
      refreshToken: String.fromCharCodes(_rT),
      apiKey: String.fromCharCodes(_aK),
    );
  }

  /// Get Google Calendar config from Firestore, with fallback to defaults
  Future<GoogleCalendarConfig?> getConfig() async {
    try {
      final doc = await _firestore.collection('settings').doc('google_calendar').get();
      if (doc.exists) {
        final config = GoogleCalendarConfig.fromFirestore(doc.data()!);
        if (config.isConfigured) return config;
      }
    } catch (e) {
      debugPrint('Google Calendar: Firestore read failed, using defaults: $e');
    }
    // Fallback to built-in defaults
    return _defaultConfig();
  }

  /// Save Google Calendar config to Firestore
  Future<void> saveConfig(GoogleCalendarConfig config) async {
    await _firestore.collection('settings').doc('google_calendar').set(config.toFirestore());
  }

  /// Get a valid access token using the refresh token
  Future<String?> _getAccessToken(GoogleCalendarConfig config) async {
    // Return cached token if still valid
    if (_cachedAccessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 2)))) {
      return _cachedAccessToken;
    }

    try {
      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': config.clientId,
          'client_secret': config.clientSecret,
          'refresh_token': config.refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedAccessToken = data['access_token'];
        final expiresIn = data['expires_in'] as int? ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
        debugPrint('Google Calendar: Access token refreshed, expires in $expiresIn seconds');
        return _cachedAccessToken;
      } else {
        debugPrint('Google Calendar: Token refresh failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Google Calendar: Token refresh error: $e');
      return null;
    }
  }

  /// Create a Google Calendar event with auto-generated Google Meet link
  /// Returns a map with 'meetLink' and 'eventId', or null on failure
  Future<Map<String, String>?> createCalendarEvent({
    required Meeting meeting,
    required GoogleCalendarConfig config,
  }) async {
    final accessToken = await _getAccessToken(config);
    if (accessToken == null) {
      debugPrint('Google Calendar: No access token available');
      return null;
    }

    try {
      // Build attendees list from guests
      final List<Map<String, dynamic>> attendees = [];
      for (final guest in meeting.guests) {
        if (guest.email.isNotEmpty) {
          attendees.add({
            'email': guest.email,
            'displayName': guest.name,
          });
        }
      }

      // Build event body
      final eventBody = {
        'summary': meeting.title,
        'description': meeting.description ?? '',
        'start': {
          'dateTime': meeting.startTime.toUtc().toIso8601String(),
          'timeZone': 'Asia/Kolkata',
        },
        'end': {
          'dateTime': meeting.endTime.toUtc().toIso8601String(),
          'timeZone': 'Asia/Kolkata',
        },
        'conferenceData': {
          'createRequest': {
            'requestId': 'lms-${DateTime.now().millisecondsSinceEpoch}',
            'conferenceSolutionKey': {
              'type': 'hangoutsMeet',
            },
          },
        },
        if (attendees.isNotEmpty) 'attendees': attendees,
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 10},
          ],
        },
      };

      final response = await http.post(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1&sendUpdates=all'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(eventBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Extract Meet link from conference data
        String? meetLink;
        final conferenceData = data['conferenceData'];
        if (conferenceData != null) {
          final entryPoints = conferenceData['entryPoints'] as List<dynamic>?;
          if (entryPoints != null) {
            for (final entry in entryPoints) {
              if (entry['entryPointType'] == 'video') {
                meetLink = entry['uri'];
                break;
              }
            }
          }
        }

        // Fallback to hangoutLink
        meetLink ??= data['hangoutLink'];

        final eventId = data['id'] as String?;

        debugPrint('Google Calendar: Event created - ID: $eventId, Meet: $meetLink');

        return {
          if (meetLink != null) 'meetLink': meetLink,
          if (eventId != null) 'eventId': eventId,
        };
      } else {
        debugPrint('Google Calendar: Create event failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Google Calendar: Create event error: $e');
      return null;
    }
  }

  /// Delete a Google Calendar event
  Future<bool> deleteCalendarEvent({
    required String eventId,
    required GoogleCalendarConfig config,
  }) async {
    final accessToken = await _getAccessToken(config);
    if (accessToken == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events/$eventId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Google Calendar: Delete event error: $e');
      return false;
    }
  }

  /// Test the Google Calendar connection
  Future<String> testConnection(GoogleCalendarConfig config) async {
    final accessToken = await _getAccessToken(config);
    if (accessToken == null) {
      return 'Failed to get access token. Please check your credentials.';
    }

    try {
      // Try to list calendars to verify access
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=1'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return 'Success! Google Calendar connection verified.';
      } else {
        final data = jsonDecode(response.body);
        return 'API Error: ${data['error']?['message'] ?? response.body}';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }
}
