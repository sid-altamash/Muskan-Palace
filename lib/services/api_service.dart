import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
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

  // Set your Render URL here for 24/7 cloud connectivity
  static const String cloudApiUrl = 'https://muskan-palace-api.onrender.com';

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

  // Timeout constant (35s allows free-tier cloud containers to wake up)
  static const Duration requestTimeout = Duration(seconds: 35);

  /// GET /api/analytics/monthly?year=YYYY&month=M
  Future<MonthlyAnalytics> getMonthlyAnalytics(int year, int month) async {
    final uri = Uri.parse('$baseUrl/api/analytics/monthly?year=$year&month=$month');
    try {
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return MonthlyAnalytics.fromJson(data);
      } else {
        final err = _parseErrorMessage(response.body, statusCode: response.statusCode);
        throw ApiException(err, statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw ApiException(
        'Server took too long to respond. If hosted on Render free tier, the server spins down after inactivity and needs ~45s to wake up. Please tap Retry.',
      );
    } on SocketException {
      throw ApiException(
        'Cannot connect to server. Please check your internet connection or verify the backend URL.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Connection error: ${e.toString()}');
    }
  }

  /// GET /api/availability?date=YYYY-MM-DD
  Future<SlotAvailability> getAvailability(String date) async {
    final uri = Uri.parse('$baseUrl/api/availability?date=$date');
    try {
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return SlotAvailability.fromJson(data);
      } else {
        final err = _parseErrorMessage(response.body, statusCode: response.statusCode);
        throw ApiException(err, statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw ApiException(
        'Server took too long to respond. The server may be waking up from sleep. Please tap Retry in a moment.',
      );
    } on SocketException {
      throw ApiException(
        'Cannot connect to server. Please check your internet connection or verify the backend URL.',
      );
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
      ).timeout(requestTimeout);

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return data;
      } else {
        final msg = data['message'] ?? data['error'] ?? 'Booking creation failed';
        throw ApiException(msg.toString(), statusCode: response.statusCode);
      }
    } on TimeoutException {
      throw ApiException('Booking request timed out. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error submitting booking: ${e.toString()}');
    }
  }

  /// GET /api/calendar/month-summary?year=YYYY&month=M
  Future<Map<String, dynamic>> getMonthSummary(int year, int month) async {
    final uri = Uri.parse('$baseUrl/api/calendar/month-summary?year=$year&month=$month');
    try {
      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['summary'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  String _parseErrorMessage(String responseBody, {int? statusCode}) {
    try {
      final data = json.decode(responseBody);
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    } catch (_) {}

    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'Server is starting up (HTTP $statusCode). If using Render free hosting, please wait 30 seconds and tap Retry.';
    } else if (statusCode == 404) {
      return 'HTTP 404 Not Found: Could not reach the backend at this address. Please verify your Render service URL.';
    } else if (statusCode != null) {
      return 'Server error (HTTP $statusCode).';
    }
    return 'Server returned an error.';
  }
}
