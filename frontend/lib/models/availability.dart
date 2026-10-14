import 'booking.dart';

class SlotAvailability {
  final String date;
  final List<String> bookedSlots;
  final List<String> availableSlots;
  final bool isFullyBooked;
  final List<Booking> bookings;

  SlotAvailability({
    required this.date,
    required this.bookedSlots,
    required this.availableSlots,
    required this.isFullyBooked,
    required this.bookings,
  });

  factory SlotAvailability.fromJson(Map<String, dynamic> json) {
    final booked = (json['booked_slots'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final avail = (json['available_slots'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final rawBookings = (json['bookings'] as List<dynamic>?) ?? [];
    final parsedBookings = rawBookings
        .map((b) => Booking.fromJson(b as Map<String, dynamic>))
        .toList();

    return SlotAvailability(
      date: json['date']?.toString() ?? '',
      bookedSlots: booked,
      availableSlots: avail,
      isFullyBooked: json['is_fully_booked'] as bool? ?? (avail.isEmpty),
      bookings: parsedBookings,
    );
  }

  factory SlotAvailability.empty(String date) {
    return SlotAvailability(
      date: date,
      bookedSlots: [],
      availableSlots: ['Morning', 'Evening', 'Full Day'],
      isFullyBooked: false,
      bookings: [],
    );
  }
}
