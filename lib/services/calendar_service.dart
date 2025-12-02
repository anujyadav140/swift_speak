import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:flutter/foundation.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [CalendarApi.calendarScope],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => _googleSignIn.onCurrentUserChanged;

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();
  Future<GoogleSignInAccount?> signOut() => _googleSignIn.signOut();

  Future<CalendarApi?> _getCalendarApi() async {
    try {
      // Ensure user is signed in
      if (_googleSignIn.currentUser == null) {
        // Don't auto-sign in here, rely on explicit sign-in or previous session
        // But if we want to be helpful, we can try signInSilently
        await _googleSignIn.signInSilently();
      }
      
      if (_googleSignIn.currentUser == null) return null;

      final client = await _googleSignIn.authenticatedClient();
      if (client == null) return null;
      
      return CalendarApi(client);
    } catch (e) {
      debugPrint('Error getting Calendar API: $e');
      return null;
    }
  }

  /// Checks availability for a specific time range.
  /// Returns a string describing conflicts or "Available".
  Future<String> checkAvailability(DateTime start, DateTime end) async {
    try {
      final api = await _getCalendarApi();
      if (api == null) return "Error: Could not access calendar.";

      final events = await api.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null || events.items!.isEmpty) {
        return "Available";
      }

      final conflicts = events.items!.map((e) {
        final summary = e.summary ?? "Busy";
        final start = e.start?.dateTime ?? e.start?.date;
        final end = e.end?.dateTime ?? e.end?.date;
        return "$summary ($start - $end)";
      }).join(", ");

      return "Busy: $conflicts";
    } catch (e) {
      debugPrint('Error checking availability: $e');
      return "Error checking calendar: $e";
    }
  }

  /// Returns a list of events for the given day.
  Future<List<String>> getEventsForDay(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    
    try {
      final api = await _getCalendarApi();
      if (api == null) return ["Error: Could not access calendar."];

      final events = await api.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      if (events.items == null || events.items!.isEmpty) {
        return ["No events found."];
      }

      return events.items!.map((e) {
        final summary = e.summary ?? "No Title";
        final startTime = e.start?.dateTime ?? e.start?.date;
        return "$summary at $startTime";
      }).toList();
    } catch (e) {
      return ["Error fetching events: $e"];
    }
  }
  Future<void> insertEvent(String title, DateTime start, DateTime end) async {
    try {
      final api = await _getCalendarApi();
      if (api == null) throw Exception('User not signed in or API unavailable');

      final event = Event(
        summary: title,
        start: EventDateTime(dateTime: start.toUtc()),
        end: EventDateTime(dateTime: end.toUtc()),
      );

      await api.events.insert(event, 'primary');
      debugPrint('Event added: $title');
    } catch (e) {
      debugPrint('Error adding event: $e');
      rethrow;
    }
  }
}
