import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class BookingFormModal extends StatefulWidget {
  final DateTime selectedDate;
  final List<String> availableSlots;
  final String? preselectedSlot;
  final Booking? existingBooking;
  final VoidCallback onBookingSuccess;

  const BookingFormModal({
    super.key,
    required this.selectedDate,
    required this.availableSlots,
    this.preselectedSlot,
    this.existingBooking,
    required this.onBookingSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required DateTime selectedDate,
    required List<String> availableSlots,
    String? preselectedSlot,
    Booking? existingBooking,
    required VoidCallback onBookingSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingFormModal(
        selectedDate: selectedDate,
        availableSlots: availableSlots,
        preselectedSlot: preselectedSlot,
        existingBooking: existingBooking,
        onBookingSuccess: onBookingSuccess,
      ),
    );
  }

  @override
  State<BookingFormModal> createState() => _BookingFormModalState();
}

class _BookingFormModalState extends State<BookingFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _totalPeopleController;
  late TextEditingController _waitersCountController;
  late TextEditingController _totalAmountController;
  late TextEditingController _advancePaidController;

  late DateTime _currentDate;
  String? _selectedSlot;
  String _selectedStatus = 'Confirmed';
  bool _isLoading = false;
  bool _isDeleting = false;
  String? _errorMessage;

  bool get isEditing => widget.existingBooking != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingBooking;

    if (existing != null) {
      _currentDate = DateTime.tryParse(existing.eventDate) ?? widget.selectedDate;
      _nameController = TextEditingController(text: existing.customerName);
      _phoneController = TextEditingController(text: existing.customerPhone);
      _totalPeopleController = TextEditingController(
          text: existing.totalPeople > 0 ? existing.totalPeople.toString() : '');
      _waitersCountController = TextEditingController(
          text: existing.waitersCount > 0 ? existing.waitersCount.toString() : '');
      _totalAmountController = TextEditingController(text: existing.totalAmount.toStringAsFixed(0));
      _advancePaidController = TextEditingController(text: existing.advancePaid.toStringAsFixed(0));
      _selectedSlot = existing.slot;
      _selectedStatus = existing.status;
    } else {
      _currentDate = widget.selectedDate;
      _nameController = TextEditingController();
      _phoneController = TextEditingController();
      _totalPeopleController = TextEditingController();
      _waitersCountController = TextEditingController();
      _totalAmountController = TextEditingController();
      _advancePaidController = TextEditingController();

      if (widget.preselectedSlot != null &&
          widget.availableSlots.contains(widget.preselectedSlot)) {
        _selectedSlot = widget.preselectedSlot;
      } else if (widget.availableSlots.isNotEmpty) {
        _selectedSlot = widget.availableSlots.first;
      } else {
        _selectedSlot = 'Morning';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _totalPeopleController.dispose();
    _waitersCountController.dispose();
    _totalAmountController.dispose();
    _advancePaidController.dispose();
    super.dispose();
  }

  List<String> get _slotOptions {
    final Set<String> slots = Set.from(widget.availableSlots);
    if (isEditing && widget.existingBooking?.slot != null) {
      slots.add(widget.existingBooking!.slot);
    }
    if (slots.isEmpty) {
      return ['Morning', 'Evening', 'Full Day'];
    }
    final order = ['Morning', 'Evening', 'Full Day'];
    return order.where((s) => slots.contains(s)).toList();
  }

  double get _calculatedBalance {
    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final advance = double.tryParse(_advancePaidController.text.trim()) ?? 0.0;
    return (total - advance).clamp(0.0, double.infinity);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC9933B),
              onPrimary: Color(0xFF0B0F19),
              surface: Color(0xFF141A29),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _currentDate = picked);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlot == null) {
      setState(() => _errorMessage = 'Please select a slot.');
      return;
    }

    final total = double.tryParse(_totalAmountController.text.trim()) ?? 0.0;
    final advance = double.tryParse(_advancePaidController.text.trim()) ?? 0.0;

    if (advance > total) {
      setState(() => _errorMessage = 'Advance paid cannot exceed total amount.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);

    final totalPeople = int.tryParse(_totalPeopleController.text.trim()) ?? 0;
    final waitersCount = int.tryParse(_waitersCountController.text.trim()) ?? 0;

    try {
      if (isEditing) {
        // Alter / Edit existing booking
        final updates = {
          'customer_name': _nameController.text.trim(),
          'customer_phone': _phoneController.text.trim(),
          'event_date': dateStr,
          'slot': _selectedSlot!,
          'total_people': totalPeople,
          'waiters_count': waitersCount,
          'total_amount': total,
          'advance_paid': advance,
          'status': _selectedStatus,
        };

        await _apiService.updateBooking(widget.existingBooking!.id!, updates);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking #${widget.existingBooking!.id} updated successfully!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
          widget.onBookingSuccess();
        }
      } else {
        // Create new booking
        final booking = Booking(
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          eventDate: dateStr,
          slot: _selectedSlot!,
          totalPeople: totalPeople,
          waitersCount: waitersCount,
          totalAmount: total,
          advancePaid: advance,
          status: _selectedStatus,
        );

        final res = await _apiService.createBooking(booking);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking #${res["booking_id"] ?? ""} confirmed for ${booking.customerName}!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
          widget.onBookingSuccess();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existingBooking;
    if (existing == null) return;

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
          'Are you sure you want to permanently delete Booking #${existing.id} for "${existing.customerName}" on ${existing.eventDate}?\n\nThis will free up the slot.',
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
      setState(() => _isDeleting = true);
      try {
        await _apiService.deleteBooking(existing.id!);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.delete_sweep, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking #${existing.id} has been deleted.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
          widget.onBookingSuccess();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isDeleting = false;
            _errorMessage = 'Failed to delete: ${e.toString()}';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF141A29),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Color(0xFFC9933B), width: 2),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Grab Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Alter Booking #${widget.existingBooking!.id}'
                              : 'New Banquet Booking',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEditing ? 'Modify or update reservation details' : 'Reserve a morning, evening or full day slot',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Event Date Row (with Date Picker)
                _buildFieldLabel('Event Date'),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1523),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFFC9933B), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy').format(_currentDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9933B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Change Date',
                            style: TextStyle(
                              color: Color(0xFFF3C977),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Customer Name
                _buildFieldLabel('Customer Full Name / Family'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    hint: 'e.g., Rajesh Sharma (Wedding)',
                    icon: Icons.person_rounded,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Customer name is required' : null,
                ),
                const SizedBox(height: 14),

                // Customer Phone
                _buildFieldLabel('Contact Phone Number'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    hint: 'e.g., +91 98765 43210',
                    icon: Icons.phone_rounded,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Contact phone is required' : null,
                ),
                const SizedBox(height: 14),

                // Slot Selection Row
                _buildFieldLabel('Time Slot'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedSlot,
                  dropdownColor: const Color(0xFF1E2638),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: _buildInputDecoration(
                    hint: 'Choose slot',
                    icon: Icons.access_time_rounded,
                  ),
                  items: _slotOptions.map((slot) {
                    String sub = '';
                    if (slot == 'Morning') sub = ' (09:00 AM – 03:00 PM)';
                    if (slot == 'Evening') sub = ' (05:00 PM – 11:00 PM)';
                    if (slot == 'Full Day') sub = ' (09:00 AM – 11:00 PM)';
                    return DropdownMenuItem<String>(
                      value: slot,
                      child: Text('$slot$sub'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedSlot = val);
                  },
                  validator: (v) => v == null ? 'Slot selection is required' : null,
                ),
                const SizedBox(height: 14),

                // Status Dropdown
                _buildFieldLabel('Booking Status'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  dropdownColor: const Color(0xFF1E2638),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: _buildInputDecoration(
                    hint: 'Status',
                    icon: Icons.flag_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed (Active Slot)')),
                    DropdownMenuItem(value: 'Tentative', child: Text('Tentative (Reserved)')),
                    DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled (Frees Slot)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
                const SizedBox(height: 14),

                // Total People & No. of Waiters Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Total People (Guests)'),
                          TextFormField(
                            controller: _totalPeopleController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              hint: 'e.g., 500',
                              icon: Icons.groups_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('No. of Waiters'),
                          TextFormField(
                            controller: _waitersCountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              hint: 'e.g., 20',
                              icon: Icons.room_service_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Total Amount & Advance Paid Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Total Amount (₹)'),
                          TextFormField(
                            controller: _totalAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              hint: '85000',
                              icon: Icons.currency_rupee_rounded,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final val = double.tryParse(v);
                              if (val == null || val <= 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Advance Paid (₹)'),
                          TextFormField(
                            controller: _advancePaidController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: _buildInputDecoration(
                              hint: '35000',
                              icon: Icons.payments_rounded,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final val = double.tryParse(v);
                              if (val == null || val < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Live Balance Calculation Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1523),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pending Balance Due:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        currencyFormat.format(_calculatedBalance),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _calculatedBalance > 0
                              ? const Color(0xFFF3C977)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Primary Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading || _isDeleting ? null : _submitBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9933B),
                      foregroundColor: const Color(0xFF0B0F19),
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.1),
                      disabledForegroundColor: Colors.white30,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B0F19)),
                            ),
                          )
                        : Text(
                            isEditing ? 'SAVE ALTERATIONS' : 'CONFIRM & SAVE BOOKING',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),

                // Delete Button (if editing)
                if (isEditing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading || _isDeleting ? null : _confirmDelete,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                              ),
                            )
                          : const Icon(Icons.delete_forever_rounded, size: 20),
                      label: Text(
                        _isDeleting ? 'Deleting...' : 'Delete Booking Permanently',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF0F1523),
      prefixIcon: Icon(icon, color: const Color(0xFFC9933B), size: 20),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC9933B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
