import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/availability.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../widgets/booking_form_modal.dart';
import '../widgets/slot_card.dart';

class CalendarBookingTab extends StatefulWidget {
  final VoidCallback? onBookingCreated;

  const CalendarBookingTab({super.key, this.onBookingCreated});

  @override
  State<CalendarBookingTab> createState() => _CalendarBookingTabState();
}

class _CalendarBookingTabState extends State<CalendarBookingTab> {
  final ApiService _apiService = ApiService();

  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  SlotAvailability? _availability;
  bool _isLoadingSlots = false;
  String? _slotError;

  // Month summary for calendar badges
  Map<String, dynamic> _monthSummary = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = now;
    _selectedDay = now;
    _fetchMonthSummary(_focusedDay.year, _focusedDay.month);
    _fetchAvailability(_selectedDay);
  }

  Future<void> _fetchMonthSummary(int year, int month) async {
    try {
      final summary = await _apiService.getMonthSummary(year, month);
      if (mounted) {
        setState(() => _monthSummary = summary);
      }
    } catch (_) {}
  }

  Future<void> _fetchAvailability(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _slotError = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final data = await _apiService.getAvailability(dateStr);
      if (mounted) {
        setState(() {
          _availability = data;
          _isLoadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slotError = e.toString();
          _isLoadingSlots = false;
        });
      }
    }
  }

  void _openBookingModal({String? preselectedSlot}) {
    final avail = _availability?.availableSlots ?? ['Morning', 'Evening', 'Full Day'];
    BookingFormModal.show(
      context: context,
      selectedDate: _selectedDay,
      availableSlots: avail,
      preselectedSlot: preselectedSlot,
      onBookingSuccess: () {
        _fetchAvailability(_selectedDay);
        _fetchMonthSummary(_focusedDay.year, _focusedDay.month);
        widget.onBookingCreated?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateHeading = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101626),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFC9933B).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF171E30),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFC9933B), size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Calendar & Slots',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _openBookingModal(),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFC9933B),
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'New Booking',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openBookingModal(),
        backgroundColor: const Color(0xFFC9933B),
        foregroundColor: const Color(0xFF0B0F19),
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text(
          'Book Slot',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TableCalendar Card
            _buildCalendarCard(),
            const SizedBox(height: 20),

            // Date & Status Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateHeading,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Slot Availability Breakdown',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                if (_availability != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _availability!.isFullyBooked
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _availability!.isFullyBooked
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                    child: Text(
                      _availability!.isFullyBooked ? 'FULLY BOOKED' : 'SLOTS OPEN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _availability!.isFullyBooked
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Slots list or Loading state
            if (_isLoadingSlots)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFFC9933B)),
                ),
              )
            else if (_slotError != null)
              _buildSlotErrorCard()
            else
              _buildSlotList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171E30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _fetchAvailability(selectedDay);
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _fetchMonthSummary(focusedDay.year, focusedDay.month);
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: Color(0xFFC9933B)),
          rightChevronIcon: Icon(Icons.chevron_right, color: Color(0xFFC9933B)),
          formatButtonTextStyle: TextStyle(color: Color(0xFFC9933B), fontSize: 12),
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFC9933B))),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          weekendStyle: TextStyle(color: Color(0xFFF3C977), fontWeight: FontWeight.w600),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          weekendTextStyle: const TextStyle(color: Color(0xFFF3C977), fontWeight: FontWeight.w500),
          todayDecoration: BoxDecoration(
            color: const Color(0xFFC9933B).withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9933B), width: 1.5),
          ),
          selectedDecoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFC9933B), Color(0xFF845314)],
            ),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final dayInfo = _monthSummary[dateKey];
            if (dayInfo == null || (dayInfo['booking_count'] ?? 0) == 0) {
              return null;
            }
            final isFull = dayInfo['is_fully_booked'] == true;
            return Positioned(
              bottom: 2,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFull ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlotErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _slotError ?? 'Failed to load availability',
              style: const TextStyle(color: Color(0xFFF87171)),
            ),
          ),
          TextButton(
            onPressed: () => _fetchAvailability(_selectedDay),
            child: const Text('Retry', style: TextStyle(color: Color(0xFFC9933B))),
          ),
        ],
      ),
    );
  }

  void _editBooking(Booking booking) {
    final avail = _availability?.availableSlots ?? ['Morning', 'Evening', 'Full Day'];
    BookingFormModal.show(
      context: context,
      selectedDate: DateTime.tryParse(booking.eventDate) ?? _selectedDay,
      availableSlots: avail,
      existingBooking: booking,
      onBookingSuccess: () {
        _fetchAvailability(_selectedDay);
        _fetchMonthSummary(_focusedDay.year, _focusedDay.month);
        widget.onBookingCreated?.call();
      },
    );
  }

  Future<void> _deleteBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A29),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Booking', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Booking #${booking.id} for "${booking.customerName}" on ${booking.eventDate}?\n\nThis will permanently delete the reservation and free up the slot.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _apiService.deleteBooking(booking.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.delete_sweep, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Booking #${booking.id} deleted successfully.'),
                ],
              ),
            ),
          );
          _fetchAvailability(_selectedDay);
          _fetchMonthSummary(_focusedDay.year, _focusedDay.month);
          widget.onBookingCreated?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text('Failed to delete booking: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  Widget _buildSlotList() {
    final avail = _availability?.availableSlots ?? ['Morning', 'Evening', 'Full Day'];
    final bookings = _availability?.bookings ?? [];

    Booking? findBooking(String slot) {
      try {
        return bookings.firstWhere((b) => b.slot == slot);
      } catch (_) {
        return null;
      }
    }

    final morningBooking = findBooking('Morning');
    final eveningBooking = findBooking('Evening');
    final fullDayBooking = findBooking('Full Day');

    final effectiveMorning = morningBooking ?? fullDayBooking;
    final effectiveEvening = eveningBooking ?? fullDayBooking;

    return Column(
      children: [
        // 1. Morning Slot
        SlotCard(
          slotName: 'Morning',
          isAvailable: avail.contains('Morning'),
          booking: effectiveMorning,
          onBookNow: avail.contains('Morning')
              ? () => _openBookingModal(preselectedSlot: 'Morning')
              : null,
          onEdit: effectiveMorning != null ? () => _editBooking(effectiveMorning) : null,
          onDelete: effectiveMorning != null ? () => _deleteBooking(effectiveMorning) : null,
        ),

        // 2. Evening Slot
        SlotCard(
          slotName: 'Evening',
          isAvailable: avail.contains('Evening'),
          booking: effectiveEvening,
          onBookNow: avail.contains('Evening')
              ? () => _openBookingModal(preselectedSlot: 'Evening')
              : null,
          onEdit: effectiveEvening != null ? () => _editBooking(effectiveEvening) : null,
          onDelete: effectiveEvening != null ? () => _deleteBooking(effectiveEvening) : null,
        ),

        // 3. Full Day Slot
        SlotCard(
          slotName: 'Full Day',
          isAvailable: avail.contains('Full Day'),
          booking: fullDayBooking,
          onBookNow: avail.contains('Full Day')
              ? () => _openBookingModal(preselectedSlot: 'Full Day')
              : null,
          onEdit: fullDayBooking != null ? () => _editBooking(fullDayBooking) : null,
          onDelete: fullDayBooking != null ? () => _deleteBooking(fullDayBooking) : null,
        ),
      ],
    );
  }
}

