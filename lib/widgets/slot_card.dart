import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';

class SlotCard extends StatelessWidget {
  final String slotName;
  final bool isAvailable;
  final Booking? booking;
  final VoidCallback? onBookNow;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SlotCard({
    super.key,
    required this.slotName,
    required this.isAvailable,
    this.booking,
    this.onBookNow,
    this.onEdit,
    this.onDelete,
  });

  String _getTimeWindow() {
    switch (slotName) {
      case 'Morning':
        return '09:00 AM – 03:00 PM';
      case 'Evening':
        return '05:00 PM – 11:00 PM';
      case 'Full Day':
        return '09:00 AM – 11:00 PM (Full Day Event)';
      default:
        return '';
    }
  }

  IconData _getSlotIcon() {
    switch (slotName) {
      case 'Morning':
        return Icons.wb_sunny_rounded;
      case 'Evening':
        return Icons.nights_stay_rounded;
      case 'Full Day':
        return Icons.all_inclusive_rounded;
      default:
        return Icons.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isBooked = !isAvailable;

    final borderColor = isAvailable
        ? const Color(0xFF10B981).withValues(alpha: 0.4)
        : const Color(0xFFEF4444).withValues(alpha: 0.4);

    final bgColor = isAvailable
        ? const Color(0xFF10B981).withValues(alpha: 0.08)
        : const Color(0xFFEF4444).withValues(alpha: 0.08);

    final statusColor = isAvailable ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Slot title, time, and status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getSlotIcon(),
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$slotName Slot',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _getTimeWindow(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  isAvailable ? 'AVAILABLE' : 'BOOKED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          // If Booked, display customer details and action buttons
          if (isBooked && booking != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          booking!.customerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF3C977),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: booking!.status == 'Cancelled'
                              ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                              : booking!.status == 'Tentative'
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                  : const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          booking!.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: booking!.status == 'Cancelled'
                                ? const Color(0xFFF87171)
                                : booking!.status == 'Tentative'
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFF34D399),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone, size: 13, color: Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            booking!.customerPhone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Paid: ${currencyFormat.format(booking!.advancePaid)} / ${currencyFormat.format(booking!.totalAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),

                  // Alter / Edit and Delete Action Row
                  if (onEdit != null || onDelete != null) ...[
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onEdit != null)
                          TextButton.icon(
                            onPressed: onEdit,
                            icon: const Icon(Icons.edit_outlined, size: 14),
                            label: const Text('Alter / Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFF3C977),
                              backgroundColor: const Color(0xFFC9933B).withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(color: const Color(0xFFC9933B).withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                        if (onEdit != null && onDelete != null) const SizedBox(width: 8),
                        if (onDelete != null)
                          TextButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                            label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFF87171),
                              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // If Booked due to conflict (e.g. Full Day booked when viewing Morning)
          if (isBooked && booking == null) ...[
            const SizedBox(height: 10),
            Text(
              'Unavailable due to an active conflicting reservation on this date.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: const Color(0xFFEF4444).withValues(alpha: 0.9),
              ),
            ),
          ],

          // Quick Book Action for Available Slot
          if (isAvailable && onBookNow != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onBookNow,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFF34D399),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xFF10B981), width: 0.8),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(
                  'Book $slotName',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
