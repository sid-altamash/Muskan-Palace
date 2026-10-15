import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../widgets/booking_form_modal.dart';

class AllBookingsTab extends StatefulWidget {
  final VoidCallback? onBookingChanged;

  const AllBookingsTab({super.key, this.onBookingChanged});

  @override
  State<AllBookingsTab> createState() => AllBookingsTabState();
}

class AllBookingsTabState extends State<AllBookingsTab> {
  final ApiService _apiService = ApiService();

  List<Booking> _allBookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedStatusFilter = 'All'; // 'All', 'Confirmed', 'Tentative', 'Cancelled'
  bool _sortAscending = true; // by event date

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.getAllBookings();
      if (mounted) {
        setState(() {
          _allBookings = list;
          _isLoading = false;
        });
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

  List<Booking> get _filteredBookings {
    var list = _allBookings.where((b) {
      // Status filter
      if (_selectedStatusFilter != 'All' && b.status != _selectedStatusFilter) {
        return false;
      }
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = b.customerName.toLowerCase().contains(q);
        final phoneMatch = b.customerPhone.toLowerCase().contains(q);
        final dateMatch = b.eventDate.toLowerCase().contains(q);
        final slotMatch = b.slot.toLowerCase().contains(q);
        return nameMatch || phoneMatch || dateMatch || slotMatch;
      }
      return true;
    }).toList();

    // Sort by event date
    list.sort((a, b) {
      final comp = a.eventDate.compareTo(b.eventDate);
      return _sortAscending ? comp : -comp;
    });

    return list;
  }

  void _openCreateModal() {
    BookingFormModal.show(
      context: context,
      selectedDate: DateTime.now(),
      availableSlots: ['Morning', 'Evening', 'Full Day'],
      onBookingSuccess: () {
        fetchBookings();
        widget.onBookingChanged?.call();
      },
    );
  }

  void _openEditModal(Booking booking) {
    BookingFormModal.show(
      context: context,
      selectedDate: DateTime.tryParse(booking.eventDate) ?? DateTime.now(),
      availableSlots: ['Morning', 'Evening', 'Full Day'],
      existingBooking: booking,
      onBookingSuccess: () {
        fetchBookings();
        widget.onBookingChanged?.call();
      },
    );
  }

  Future<void> _deleteBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A29),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete Booking', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete Booking #${booking.id} for "${booking.customerName}" on ${booking.eventDate}?\n\nThis will free up the slot.',
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
          fetchBookings();
          widget.onBookingChanged?.call();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFEF4444),
              content: Text('Failed to delete: ${e.toString()}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleStatus(Booking booking) async {
    final newStatus = booking.status == 'Cancelled' ? 'Confirmed' : 'Cancelled';
    try {
      await _apiService.updateBooking(booking.id!, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: newStatus == 'Confirmed' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            content: Text('Booking #${booking.id} status changed to $newStatus.'),
          ),
        );
        fetchBookings();
        widget.onBookingChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final filtered = _filteredBookings;

    // Totals
    final confirmedCount = _allBookings.where((b) => b.status == 'Confirmed').length;
    final totalRevenue = _allBookings
        .where((b) => b.status == 'Confirmed')
        .fold<double>(0.0, (acc, b) => acc + b.totalAmount);
    final totalBalance = _allBookings
        .where((b) => b.status == 'Confirmed')
        .fold<double>(0.0, (acc, b) => acc + b.balanceAmount);

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
                    child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFC9933B), size: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Manage All Bookings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFFC9933B)),
            tooltip: 'Refresh list',
            onPressed: fetchBookings,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _openCreateModal,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFC9933B),
                foregroundColor: const Color(0xFF0B0F19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'New',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateModal,
        backgroundColor: const Color(0xFFC9933B),
        foregroundColor: const Color(0xFF0B0F19),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Booking', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        color: const Color(0xFFC9933B),
        backgroundColor: const Color(0xFF141A29),
        onRefresh: fetchBookings,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // KPI Summary Row
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF141A29), Color(0xFF1A2236)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC9933B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Total Bookings', '${_allBookings.length} ($confirmedCount active)', Icons.calendar_month_rounded),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _buildSummaryItem('Total Revenue', currencyFormat.format(totalRevenue), Icons.currency_rupee_rounded),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _buildSummaryItem('Pending Due', currencyFormat.format(totalBalance), Icons.pending_actions_rounded),
                  ],
                ),
              ),
            ),

            // Search Bar & Sort Toggle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search customer, phone, or date...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFC9933B), size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFF141A29),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFC9933B)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A29),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _sortAscending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          color: const Color(0xFFC9933B),
                          size: 20,
                        ),
                        tooltip: _sortAscending ? 'Date: Earliest first' : 'Date: Latest first',
                        onPressed: () => setState(() => _sortAscending = !_sortAscending),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status Filter Chips
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: ['All', 'Confirmed', 'Tentative', 'Cancelled'].map((status) {
                    final isSelected = _selectedStatusFilter == status;
                    final count = status == 'All'
                        ? _allBookings.length
                        : _allBookings.where((b) => b.status == status).length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('$status ($count)'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedStatusFilter = status),
                        backgroundColor: const Color(0xFF141A29),
                        selectedColor: const Color(0xFFC9933B).withValues(alpha: 0.25),
                        checkmarkColor: const Color(0xFFC9933B),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFFF3C977) : Colors.white70,
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFC9933B) : Colors.white.withValues(alpha: 0.1),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // Loading / Error / Empty / List content
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFC9933B)),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load bookings',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: fetchBookings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC9933B),
                            foregroundColor: const Color(0xFF0B0F19),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.event_available_rounded,
                          color: Colors.white24,
                          size: 54,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No bookings found matching "$_searchQuery"'
                              : 'No bookings recorded in this category',
                          style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedStatusFilter = 'All';
                              });
                            },
                            child: const Text('Reset filters', style: TextStyle(color: Color(0xFFC9933B))),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: _openCreateModal,
                            icon: const Icon(Icons.add),
                            label: const Text('Create New Booking'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC9933B),
                              foregroundColor: const Color(0xFF0B0F19),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final booking = filtered[index];
                      return _buildBookingCard(booking, currencyFormat);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String val, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFFC9933B)),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Booking b, NumberFormat currencyFormat) {
    final isCancelled = b.status == 'Cancelled';
    final isTentative = b.status == 'Tentative';

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(b.eventDate);
    } catch (_) {}

    final formattedDate = parsedDate != null
        ? DateFormat('EEE, d MMM yyyy').format(parsedDate)
        : b.eventDate;

    Color statusBg = const Color(0xFF10B981).withValues(alpha: 0.15);
    Color statusColor = const Color(0xFF34D399);

    if (isCancelled) {
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      statusColor = const Color(0xFFF87171);
    } else if (isTentative) {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      statusColor = const Color(0xFFFBBF24);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141A29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCancelled
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
              : const Color(0xFFC9933B).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: ID, Date, Slot, Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC9933B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${b.id ?? ""}',
                      style: const TextStyle(
                        color: Color(0xFFF3C977),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      b.slot,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      b.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer info
          Text(
            b.customerName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF3C977),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 13, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                b.customerPhone,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),

          if (b.totalPeople > 0 || b.waitersCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (b.totalPeople > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded, size: 12, color: Color(0xFF60A5FA)),
                        const SizedBox(width: 4),
                        Text(
                          '${b.totalPeople} Guests',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF93C5FD), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                if (b.totalPeople > 0 && b.waitersCount > 0)
                  const SizedBox(width: 8),
                if (b.waitersCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.room_service_rounded, size: 12, color: Color(0xFF34D399)),
                        const SizedBox(width: 4),
                        Text(
                          '${b.waitersCount} Waiters',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF6EE7B7), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Financials Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1523),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Amount', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(
                      currencyFormat.format(b.totalAmount),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Advance Paid', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(
                      currencyFormat.format(b.advancePaid),
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Balance Due', style: TextStyle(color: Colors.white38, fontSize: 10)),
                    Text(
                      currencyFormat.format(b.balanceAmount),
                      style: TextStyle(
                        color: b.balanceAmount > 0 ? const Color(0xFFFBBF24) : Colors.white54,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Actions Row: Alter / Edit, Toggle Status, Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Reopen / Cancel Quick Button
              TextButton.icon(
                onPressed: () => _toggleStatus(b),
                icon: Icon(
                  isCancelled ? Icons.restore_rounded : Icons.cancel_outlined,
                  size: 14,
                ),
                label: Text(
                  isCancelled ? 'Reopen' : 'Cancel',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: isCancelled ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  backgroundColor: isCancelled
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Edit / Alter Button
              TextButton.icon(
                onPressed: () => _openEditModal(b),
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
              const SizedBox(width: 8),

              // Delete Button
              TextButton.icon(
                onPressed: () => _deleteBooking(b),
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
      ),
    );
  }
}
