import 'package:friend_private/backend/preferences.dart';
import 'package:friend_private/utils/logger.dart';
import 'package:manage_calendar_events/manage_calendar_events.dart';
import 'package:permission_handler/permission_handler.dart';

// TODO: handle these edge cases:
// - Process reminders during the transcription? (Detect phrases like "Hey Friend...")
// - If an event was supposed to happen soon (e.g., 10 minutes) but the conversation happened too late (e.g., 20 minutes after), avoid creating the event.

class CalendarUtil {
  static final CalendarUtil _instance = CalendarUtil._internal();
  static CalendarPlugin? _calendarPlugin;

  factory CalendarUtil() {
    return _instance;
  }

  CalendarUtil._internal();

  static void init() {
    _calendarPlugin = CalendarPlugin();
  }

  // Check if the app has calendar access
  Future<bool> checkCalendarPermission() async {
    try {
      var status = await Permission.calendarFullAccess.status;
      if (status.isGranted) {
        return true;
      } else if (status.isDenied || status.isPermanentlyDenied) {
        return false;
      }
      return false;
    } catch (e) {
      Logger.error('Error in checkCalendarPermission: $e');
      return false;
    }
  }

  // Fetch available calendars
  Future<List<Calendar>> fetchCalendars() async {
    final calendarsResult = await _calendarPlugin!.getCalendars();
    Logger.log('calendarsResult: $calendarsResult');
    if (calendarsResult != null) {
      return calendarsResult;
    } else {
      return [];
    }
  }

  // Create an event in the selected calendar
  Future<bool> createEvent(String title, DateTime startsAt, int durationMinutes, {String? description}) async {
    bool hasAccess = await checkCalendarPermission();
    if (!hasAccess) return false;

    DateTime startDate = startsAt.toLocal();
    DateTime endDate = startDate.add(Duration(minutes: durationMinutes));

    String calendarId = SharedPreferencesUtil().calendarId;

    CalendarEvent newEvent = CalendarEvent(
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
    );

    var res = await _calendarPlugin!.createEvent(calendarId: calendarId, event: newEvent);

    if (res != null && res.isNotEmpty) {
      print('Event created successfully');
      return true;
    } else {
      print('Failed to create event: $res');
    }
    return false;
  }

  // Method to find an event from the calendar that might overlap with the current conversation time
  Future<List<CalendarEvent>> findOverlappingEvents(DateTime conversationTime) async {
    bool hasAccess = await checkCalendarPermission();
    if (!hasAccess) return [];

    String calendarId = SharedPreferencesUtil().calendarId;
    List<CalendarEvent> events = await _calendarPlugin!.getEventsForCalendar(calendarId);

    // Filter events that overlap with the conversation timestamp
    return events.where((event) {
      return event.startDate.isBefore(conversationTime) && event.endDate.isAfter(conversationTime);
    }).toList();
  }

  // Check if an event should be created based on the conversation's timestamp
  Future<bool> shouldCreateEvent(DateTime conversationTime, DateTime eventTime) async {
    Duration difference = conversationTime.difference(eventTime);
    
    // Avoid creating an event if the conversation happened too late (e.g., 20 minutes after the event time)
    if (difference.isNegative || difference.inMinutes > 15) {
      Logger.log('Event creation skipped: Conversation happened too late or is too far from the event time.');
      return false;
    }
    return true;
  }

  // Process reminders or event creation during transcription
  Future<void> processTranscriptionForEvents(String transcription, DateTime conversationTime) async {
    // Simple check for reminder or event-related keywords (e.g., "Hey Friend...")
    if (transcription.contains('Hey Friend') || transcription.contains('remind me') || transcription.contains('schedule')) {
      // Extract potential event details (e.g., title, time, etc.)
      String title = 'New event based on conversation';
      DateTime eventTime = conversationTime.add(const Duration(minutes: 10));  // Example of adding 10 minutes for the event
      
      // Check if the event is worth creating
      bool canCreateEvent = await shouldCreateEvent(conversationTime, eventTime);
      if (canCreateEvent) {
        // Create the event if it makes sense
        await createEvent(title, eventTime, 30);  // 30-minute event as a placeholder
      }
    }
  }
}
