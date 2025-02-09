import 'package:googleapis/calendar/v3.dart' as google_calendar;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class CalendarProvider extends ChangeNotifier {
  // Existing code...

  // Add Google Calendar API client
  google_calendar.CalendarApi? _googleCalendarApi;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar.events',
      'https://www.googleapis.com/auth/calendar.readonly',
    ],
  );

  // Add a method to initialize Google Calendar API
  Future<void> initializeGoogleCalendar() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final authHeaders = await googleUser.authHeaders;
        final authenticatedClient = GoogleAuthClient(authHeaders);
        _googleCalendarApi = google_calendar.CalendarApi(authenticatedClient);
      }
    } catch (e) {
      print('Error initializing Google Calendar: $e');
      AppSnackbar.showSnackbar('Failed to connect to Google Calendar. Please try again.');
    }
  }

  // Add a method to fetch Google Calendar events
  Future<List<google_calendar.Event>> fetchGoogleCalendarEvents(DateTime startTime, DateTime endTime) async {
    if (_googleCalendarApi == null) {
      await initializeGoogleCalendar();
    }
    try {
      final events = await _googleCalendarApi!.events.list(
        'primary',
        timeMin: startTime.toUtc(),
        timeMax: endTime.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );
      return events.items ?? [];
    } catch (e) {
      print('Error fetching Google Calendar events: $e');
      AppSnackbar.showSnackbar('Failed to fetch Google Calendar events.');
      return [];
    }
  }

  // Add a method to create a Google Calendar event
  Future<void> createGoogleCalendarEvent(String title, DateTime startTime, DateTime endTime, String? description) async {
    if (_googleCalendarApi == null) {
      await initializeGoogleCalendar();
    }
    try {
      final event = google_calendar.Event(
        summary: title,
        description: description,
        start: google_calendar.EventDateTime(dateTime: startTime.toUtc()),
        end: google_calendar.EventDateTime(dateTime: endTime.toUtc()),
      );
      await _googleCalendarApi!.events.insert(event, 'primary');
      AppSnackbar.showSnackbar('Event created successfully.');
    } catch (e) {
      print('Error creating Google Calendar event: $e');
      AppSnackbar.showSnackbar('Failed to create Google Calendar event.');
    }
  }

  // Add a method to update a Google Calendar event
  Future<void> updateGoogleCalendarEvent(String eventId, DateTime newStartTime, DateTime newEndTime) async {
    if (_googleCalendarApi == null) {
      await initializeGoogleCalendar();
    }
    try {
      final event = await _googleCalendarApi!.events.get('primary', eventId);
      event.start = google_calendar.EventDateTime(dateTime: newStartTime.toUtc());
      event.end = google_calendar.EventDateTime(dateTime: newEndTime.toUtc());
      await _googleCalendarApi!.events.update(event, 'primary', eventId);
      AppSnackbar.showSnackbar('Event updated successfully.');
    } catch (e) {
      print('Error updating Google Calendar event: $e');
      AppSnackbar.showSnackbar('Failed to update Google Calendar event.');
    }
  }

  // Add a method to delete a Google Calendar event
  Future<void> deleteGoogleCalendarEvent(String eventId) async {
    if (_googleCalendarApi == null) {
      await initializeGoogleCalendar();
    }
    try {
      await _googleCalendarApi!.events.delete('primary', eventId);
      AppSnackbar.showSnackbar('Event deleted successfully.');
    } catch (e) {
      print('Error deleting Google Calendar event: $e');
      AppSnackbar.showSnackbar('Failed to delete Google Calendar event.');
    }
  }

  // Add a method to open Google Calendar event in the app
  void openGoogleCalendarEvent(String eventId) {
    final url = 'https://calendar.google.com/event?eid=$eventId';
    // Use a package like `url_launcher` to open the URL
    // Example: launchUrl(Uri.parse(url));
  }
}

// Helper class for authenticated HTTP requests
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
