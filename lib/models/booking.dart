class Booking {
  final int? id;
  final String customerName;
  final String customerPhone;
  final String eventDate; // Format: "YYYY-MM-DD"
  final String slot; // "Morning", "Evening", "Full Day"
  final int totalPeople;
  final int waitersCount;
  final double totalAmount;
  final double advancePaid;
  final double balanceAmount;
  final String status;
  final String? createdAt;

  Booking({
    this.id,
    required this.customerName,
    required this.customerPhone,
    required this.eventDate,
    required this.slot,
    this.totalPeople = 0,
    this.waitersCount = 0,
    required this.totalAmount,
    required this.advancePaid,
    double? balanceAmount,
    this.status = 'Confirmed',
    this.createdAt,
  }) : balanceAmount = balanceAmount ?? (totalAmount - advancePaid);

  factory Booking.fromJson(Map<String, dynamic> json) {
    final total = (json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final advance = (json['advance_paid'] as num?)?.toDouble() ?? 0.0;
    return Booking(
      id: json['id'] as int?,
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      slot: json['slot']?.toString() ?? 'Morning',
      totalPeople: (json['total_people'] as num?)?.toInt() ?? 0,
      waitersCount: (json['waiters_count'] as num?)?.toInt() ?? 0,
      totalAmount: total,
      advancePaid: advance,
      balanceAmount: (json['balance_amount'] as num?)?.toDouble() ?? (total - advance),
      status: json['status']?.toString() ?? 'Confirmed',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'event_date': eventDate,
      'slot': slot,
      'total_people': totalPeople,
      'waiters_count': waitersCount,
      'total_amount': totalAmount,
      'advance_paid': advancePaid,
      'status': status,
    };
  }
}
