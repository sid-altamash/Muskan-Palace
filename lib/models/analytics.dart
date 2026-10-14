class MonthlyAnalytics {
  final int year;
  final int month;
  final String monthName;
  final int totalBookings;
  final double totalRevenue;
  final double averageBookingValue;
  final double occupancyRate;
  final double totalAdvancePaid;
  final double pendingBalance;
  final int slotsOccupied;
  final int totalSlotsCapacity;
  final int daysInMonth;
  final Map<String, int> slotBreakdown;

  MonthlyAnalytics({
    required this.year,
    required this.month,
    required this.monthName,
    required this.totalBookings,
    required this.totalRevenue,
    required this.averageBookingValue,
    required this.occupancyRate,
    required this.totalAdvancePaid,
    required this.pendingBalance,
    required this.slotsOccupied,
    required this.totalSlotsCapacity,
    required this.daysInMonth,
    required this.slotBreakdown,
  });

  factory MonthlyAnalytics.fromJson(Map<String, dynamic> json) {
    final breakdownRaw = json['slot_breakdown'] as Map<String, dynamic>? ?? {};
    final breakdown = <String, int>{};
    breakdownRaw.forEach((k, v) {
      breakdown[k] = (v as num?)?.toInt() ?? 0;
    });

    return MonthlyAnalytics(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      monthName: json['month_name']?.toString() ?? '',
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      averageBookingValue: (json['average_booking_value'] as num?)?.toDouble() ?? 0.0,
      occupancyRate: (json['occupancy_rate'] as num?)?.toDouble() ?? 0.0,
      totalAdvancePaid: (json['total_advance_paid'] as num?)?.toDouble() ?? 0.0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0.0,
      slotsOccupied: (json['slots_occupied'] as num?)?.toInt() ?? 0,
      totalSlotsCapacity: (json['total_slots_capacity'] as num?)?.toInt() ?? 60,
      daysInMonth: (json['days_in_month'] as num?)?.toInt() ?? 30,
      slotBreakdown: breakdown,
    );
  }

  factory MonthlyAnalytics.empty(int year, int month) {
    return MonthlyAnalytics(
      year: year,
      month: month,
      monthName: '',
      totalBookings: 0,
      totalRevenue: 0.0,
      averageBookingValue: 0.0,
      occupancyRate: 0.0,
      totalAdvancePaid: 0.0,
      pendingBalance: 0.0,
      slotsOccupied: 0,
      totalSlotsCapacity: 60,
      daysInMonth: 30,
      slotBreakdown: {'Morning': 0, 'Evening': 0, 'Full Day': 0},
    );
  }
}
