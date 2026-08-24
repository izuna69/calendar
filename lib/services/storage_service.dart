import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_event.dart';

class StorageService {
  static const String _eventsKey = 'schedule_events';
  static const String _autoStartKey = 'setting_auto_start';
  static const String _minimizeToTrayKey = 'setting_minimize_to_tray';
  static const String _darkModeKey = 'setting_dark_mode';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('StorageService must be initialized before use.');
    }
    return _prefs!;
  }

  // Event CRUD
  static List<ScheduleEvent> loadEvents() {
    final jsonString = prefs.getString(_eventsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded
          .map((item) => ScheduleEvent.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[StorageService] Error loading events: $e');
      return [];
    }
  }

  static Future<void> saveEvents(List<ScheduleEvent> events) async {
    final List<Map<String, dynamic>> jsonList =
        events.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_eventsKey, jsonString);
  }

  static Future<void> addEvent(ScheduleEvent event) async {
    final events = loadEvents();
    events.add(event);
    await saveEvents(events);
  }

  static Future<void> updateEvent(ScheduleEvent event) async {
    final events = loadEvents();
    final index = events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      events[index] = event;
      await saveEvents(events);
    }
  }

  static Future<void> deleteEvent(String id) async {
    final events = loadEvents();
    events.removeWhere((e) => e.id == id);
    await saveEvents(events);
  }

  static Future<ScheduleEvent?> toggleComplete(String id) async {
    final events = loadEvents();
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      final updated = events[index].copyWith(
        isCompleted: !events[index].isCompleted,
      );
      events[index] = updated;
      await saveEvents(events);
      return updated;
    }
    return null;
  }

  static Future<void> markNotified(String id) async {
    final events = loadEvents();
    final index = events.indexWhere((e) => e.id == id);
    if (index != -1) {
      events[index] = events[index].copyWith(isNotified: true);
      await saveEvents(events);
    }
  }

  // Settings
  static bool getAutoStart() {
    return prefs.getBool(_autoStartKey) ?? true;
  }

  static Future<void> setAutoStart(bool value) async {
    await prefs.setBool(_autoStartKey, value);
  }

  static bool getMinimizeToTray() {
    return prefs.getBool(_minimizeToTrayKey) ?? true;
  }

  static Future<void> setMinimizeToTray(bool value) async {
    await prefs.setBool(_minimizeToTrayKey, value);
  }

  static bool getDarkMode() {
    return prefs.getBool(_darkModeKey) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    await prefs.setBool(_darkModeKey, value);
  }
}
