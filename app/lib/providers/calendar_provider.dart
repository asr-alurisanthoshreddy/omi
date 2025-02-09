import 'package:flutter/material.dart';
import 'package:friend_private/backend/preferences.dart';
import 'package:friend_private/utils/alerts/app_snackbar.dart';
import 'package:friend_private/utils/analytics/mixpanel.dart';
import 'package:friend_private/utils/features/calendar.dart';
import 'package:manage_calendar_events/manage_calendar_events.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar; // You will need the Google Calendar API

class CalendarProvider extends ChangeNotifier {
  List<Calendar> calendars = [];
  bool calendarEnabled = false;
  final CalendarUtil _calendarUtil = CalendarUtil();
  final MixpanelManager _mixpanelManager = MixpanelManager();
  final SharedPreferencesUtil _sharedPreferencesUtil = SharedPreferencesUtil();
  bool isLoading = false;

  // Google Calendar API Client
  google_calendar.CalendarApi? _calendarApi;

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    calendarEnabled = await hasCalendarAccess();
    if (await hasCalendarAccess()) {
      await _getCalendars();
    }
    await initializeGoogleCalendar();
  }

  Future<void> initializeGoogleCalendar() async {
    // Initialize Google Calendar API client here (authentication and setup)
    // For example: _calendarApi = await GoogleAuthUtil.getGoogleCalendarApi();
    // The auth token could be stored and reused for the app session.
  }

  Future<void> _getCalendars() async {
    calendars = await _calendarUtil.fetchCalendars();
    notifyListeners();
  }

  Future<bool> hasCalendarAccess() async {
    return await _calendarUtil.checkCalendarPermission();
  }

  Future<void> onCalendarSwitchChanged(bool s) async {
    if (s) {
      var res = await Permission.calendarFullAccess.request();
      print('res: $res');
      _sharedPreferencesUtil.calendarPermissionAlreadyRequested = true;
      bool hasAccess = await hasCalendarAccess();
      print('hasAccess: $hasAccess');
      if (res.isGranted || hasAccess) {
        setLoading(true);
        await _getCalendars();
        await Future.delayed(const Duration(seconds: 3), () async {
          await _getCalendars();
        });
        setLoading(false);
        if (calendars.isEmpty) {
          AppSnackbar.showSnackbar(
            'No calendars found. Please check your device settings.',
            duration: const Duration(seconds: 5),
          );
          calendarEnabled = false;
        } else {
          calendarEnabled = true;
          _mixpanelManager.calendarEnabled();
        }
      } else {
        AppSnackbar.showSnackbar(
          'Calendar access was denied. Please enable it in your app settings.',
          duration: const Duration(seconds: 5),
        );
        calendarEnabled = false;
      }
    } else {
      _sharedPreferencesUtil.calendarId = '';
      _sharedPreferencesUtil.calendarType = 'auto';
      _mixpanelManager.calendarDisabled();
      calendarEnabled = false;
    }
    _sharedPreferencesUtil.calendarEnabled = calendarEnabled;
    notifyListeners();
  }

  void onCalendarTypeChanged(String? v) {
    _sharedPreferencesUtil.calendarType = v!;
    _mixpanelManager.calendarTypeChanged(v);
    notifyListeners();
  }

  void selectCalendar(String? value, Calendar calendar) {
    _sharedPreferencesUtil.calendarId = value!;
    notifyListeners();
    _mixpanelManager.calendarSelected();
    AppSnackbar.showSnackbar(
      'Calendar ${calendar.name} selected.',
      duration: const Duration(seconds: 1),
    );
  }

  // New method for integrating with Google Calendar and pulling context for memories
  Future<void> linkEventToMemory(DateTime memoryTimestamp) async {
    if (_calendarApi == null) return;

    // Check for events around the memory timestamp
    final google_calendar.Events events = await _calendarApi!.events.list(
      'primary',
      timeMin: memoryTimestamp.subtract(Duration(hours: 1)).toUtc(),
      timeMax: memoryTimestamp.add(Duration(hours: 1)).toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
    );

    if (events.items != null && events.items!.isNotEmpty) {
      final event = events.items!.first; // Assume the first event is the most relevant
      // Here, you would enrich the memory with event details
      String eventTitle = event.summary ?? "No Title";
      String eventDescription = event.description ?? "No Description";
      List<String> attendees = event.attendees?.map((attendee) => attendee.email ?? "").toList() ?? [];

      // Call the method to link the event to the memory (you'll need to implement memory logic)
      // Example: MemoryUtil.linkMemoryToEvent(memoryId, eventTitle, eventDescription, attendees);
      
      // Display linked event in the UI (if required)
      AppSnackbar.showSnackbar('Linked event: $eventTitle', duration: const Duration(seconds: 3));
    }
  }

  // Method to create Google Calendar events via chat (simple example)
  Future<void> createEventFromChat(String title, DateTime dateTime) async {
    if (_calendarApi == null) return;

    google_calendar.Event event = google_calendar.Event(
      summary: title,
      start: google_calendar.EventDateTime(dateTime: dateTime.toUtc()),
      end: google_calendar.EventDateTime(dateTime: dateTime.add(Duration(hours: 1)).toUtc()),
    );

    await _calendarApi!.events.insert(event, 'primary');
    AppSnackbar.showSnackbar('Event "$title" scheduled for $dateTime', duration: const Duration(seconds: 3));
  }

  // View the linked calendar event directly (assuming a UI interaction)
  Future<void> viewInCalendar(String eventId) async {
    // Open the Google Calendar app with the event ID (you will need proper URL scheme handling)
    // Example: _calendarUtil.openGoogleCalendarEvent(eventId);
  }
}
