import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';

class BookingFormModal extends StatefulWidget {
  final DateTime selectedDate;
  final List<String> availableSlots;
  final String? preselectedSlot;
  final VoidCallback onBookingSuccess;

  const BookingFormModal({
    super.key,
    required this.selectedDate,
    required this.availableSlots,
    this.preselectedSlot,
    required this.onBookingSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required DateTime selectedDate,
    required List<String> availableSlots,
    String? preselectedSlot,
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
  late TextEditingController _totalAmountController;
  late TextEditingController _advancePaidController;

  String? _selectedSlot;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _totalAmountController = TextEditingController();
    _advancePaidController = TextEditingController();

    // Default or preselected slot
    if (widget.preselectedSlot != null &&
        widget.availableSlots.contains(widget.preselectedSlot)) {
      _selectedSlot = widget.preselectedSlot;
    } else if (widget.availableSlots.isNotEmpty) {
      _selectedSlot = widget.availableSlots.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _totalAmountController.dispose();
    _advancePaidController.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlot == null) {
      setState(() => _errorMessage = 'Please select an available slot.');
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

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    final booking = Booking(
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      eventDate: dateStr,
      slot: _selectedSlot!,
      totalAmount: total,
      advancePaid: advance,
      status: 'Confirmed',
    );

    try {
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplay = DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate);
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
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
                        const Text(
                          'New Banquet Booking',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateDisplay,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFF3C977),
                            fontWeight: FontWeight.w600,
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

                // Customer Name
                _buildFieldLabel('Customer Full Name / Family'),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _buildInputDecoration(
                    hint: 'e.g., Rajesh Sharma & Family',
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

                // Slot Dropdown (Filtered by available slots)
                _buildFieldLabel('Select Time Slot'),
                if (widget.availableSlots.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'No slots available on this date. Please pick another date.',
                      style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSlot,
                    dropdownColor: const Color(0xFF1E2638),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: _buildInputDecoration(
                      hint: 'Choose slot',
                      icon: Icons.access_time_rounded,
                    ),
                    items: widget.availableSlots.map((slot) {
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
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final val = double.tryParse(v);
                              if (val == null || val <= 0) return 'Invalid amount';
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
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (widget.availableSlots.isEmpty || _isLoading)
                        ? null
                        : _submitBooking,
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
                        : const Text(
                            'CONFIRM & SAVE BOOKING',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                  ),
                ),
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
