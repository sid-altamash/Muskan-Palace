import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/analytics.dart';
import '../models/availability.dart';
import '../models/booking.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Set your Render URL here for 24/7 cloud connectivity (e.g. 'https://muskan-palace-api.onrender.com')
  static const String cloudApiUrl = '';

  // Dynamic base URL configurable at runtime if needed
  String? _customBaseUrl;

  String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (cloudApiUrl.isNotEmpty) {
      return cloudApiUrl;
    }
    // Web or desktop defaults to localhost
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    }
    // Android emulator loops back to host via 10.0.2.2
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000';
      }
    } catch (_) {}
    return 'http://127.0.0.1:5000';
  }

  set baseUrl(String url) {
    _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// GET /api/analytics/monthly?year=YYYY&month=M
  Future<MonthlyAnalytics> getMonthlyAnalytics(int year, int month) async {
    final uri = Uri.parse('$baseUrl/api/analytics/monthly?year=$year&month=$month');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return MonthlyAnalytics.fromJson(data);
      } else {
        final err = _parseErrorMessage(response.body);
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to connect to server: ${e.toString()}');
    }
  }

  /// GET /api/availability?date=YYYY-MM-DD
  Future<SlotAvailability> getAvailability(String date) async {
    final uri = Uri.parse('$baseUrl/api/availability?date=$date');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return SlotAvailability.fromJson(data);
      } else {
        final err = _parseErrorMessage(response.body);
        throw ApiException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to check availability: ${e.toString()}');
    }
  }

  /// POST /api/bookings
  Future<Map<String, dynamic>> createBooking(Booking booking) async {
    final uri = Uri.parse('$baseUrl/api/bookings');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(booking.toJson()),
      ).timeout(const Duration(seconds: 12));

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return data;
      } else {
        final msg = data['message'] ?? data['error'] ?? 'Booking creation failed';
        throw ApiException(msg.toString(), statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error submitting booking: ${e.toString()}');
    }
  }

  /// GET /api/calendar/month-summary?year=YYYY&month=M
  Future<Map<String, dynamic>> getMonthSummary(int year, int month) async {
    final uri = Uri.parse('$baseUrl/api/calendar/month-summary?year=$year&month=$month');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['summary'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  String _parseErrorMessage(String responseBody) {
    try {
      final data = json.decode(responseBody);
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    } catch (_) {}
    return 'Server returned an error.';
  }
}
