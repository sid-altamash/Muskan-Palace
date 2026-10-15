import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/analytics.dart';
import '../services/api_service.dart';
import '../widgets/metric_card.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback? onNavigateToCalendar;
  final VoidCallback? onNavigateToAllBookings;

  const DashboardTab({
    super.key,
    this.onNavigateToCalendar,
    this.onNavigateToAllBookings,
  });

  @override
  State<DashboardTab> createState() => DashboardTabState();
}

class DashboardTabState extends State<DashboardTab> {
  final ApiService _apiService = ApiService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  late DateTime _selectedMonth;
  MonthlyAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;

  void refresh() {
    _loadAnalytics();
  }


  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getMonthlyAnalytics(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    _loadAnalytics();
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    _loadAnalytics();
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101626),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFC9933B).withValues(alpha: 0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC9933B).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF171E30),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFFC9933B), size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Muskan Palace',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Performance Dashboard',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFC9933B).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Server Settings',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFC9933B),
        backgroundColor: const Color(0xFF1E2638),
        onRefresh: _loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Selector Bar
              _buildMonthNavigator(monthTitle),
              const SizedBox(height: 18),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CircularProgressIndicator(color: Color(0xFFC9933B)),
                  ),
                )
              else if (_error != null)
                _buildErrorCard()
              else if (_analytics != null)
                _buildAnalyticsContent(_analytics!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(String monthTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF171E30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFFC9933B)),
            onPressed: _previousMonth,
            tooltip: 'Previous Month',
          ),
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFFF3C977), size: 18),
              const SizedBox(width: 8),
              Text(
                monthTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFFC9933B)),
            onPressed: _nextMonth,
            tooltip: 'Next Month',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Unable to Connect to Backend API',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? 'Network error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFF87171), fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC9933B),
              foregroundColor: const Color(0xFF0B0F19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(MonthlyAnalytics data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid of 4 Core Metric Cards
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            // 1. Total Bookings
            MetricCard(
              title: 'Total Bookings',
              value: '${data.totalBookings}',
              subtitle: 'Confirmed for ${data.monthName}',
              icon: Icons.event_available_rounded,
              accentColor: const Color(0xFF38BDF8),
            ),

            // 2. Total Revenue
            MetricCard(
              title: 'Total Revenue',
              value: _currencyFormat.format(data.totalRevenue),
              subtitle: 'Gross confirmed sales',
              icon: Icons.monetization_on_rounded,
              accentColor: const Color(0xFF10B981),
            ),

            // 3. Average Booking Value (ABV)
            MetricCard(
              title: 'Avg Booking Val',
              value: _currencyFormat.format(data.averageBookingValue),
              subtitle: 'ABV per confirmed event',
              icon: Icons.diamond_rounded,
              accentColor: const Color(0xFFC9933B),
            ),

            // 4. Occupancy Rate (%)
            MetricCard(
              title: 'Occupancy Rate',
              value: '${data.occupancyRate}%',
              subtitle: '${data.slotsOccupied} of ${data.totalSlotsCapacity} slots',
              icon: Icons.pie_chart_rounded,
              accentColor: const Color(0xFFA855F7),
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (data.occupancyRate / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  color: const Color(0xFFA855F7),
                  minHeight: 5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Financial Breakdown Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF171E30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Payment Collection Progress',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${data.totalRevenue > 0 ? ((data.totalAdvancePaid / data.totalRevenue) * 100).toStringAsFixed(1) : "0"}% Collected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: data.totalRevenue > 0
                      ? (data.totalAdvancePaid / data.totalRevenue).clamp(0.0, 1.0)
                      : 0.0,
                  backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
                  color: const Color(0xFF10B981),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPaymentStat(
                    'Advance Collected',
                    _currencyFormat.format(data.totalAdvancePaid),
                    const Color(0xFF10B981),
                  ),
                  _buildPaymentStat(
                    'Balance Pending',
                    _currencyFormat.format(data.pendingBalance),
                    const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Slot Type Distribution
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF171E30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Slot Distribution (Standard: 2 slots/day)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildSlotBadge(
                      'Morning',
                      data.slotBreakdown['Morning'] ?? 0,
                      const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSlotBadge(
                      'Evening',
                      data.slotBreakdown['Evening'] ?? 0,
                      const Color(0xFFC9933B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSlotBadge(
                      'Full Day',
                      data.slotBreakdown['Full Day'] ?? 0,
                      const Color(0xFFA855F7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick Action: Manage All Bookings
        InkWell(
          onTap: widget.onNavigateToAllBookings,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E2638), Color(0xFF141A29)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFC9933B).withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9933B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFF3C977), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage All Bookings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View, search, edit/alter, or delete reservations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFC9933B), size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: _apiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141A29),
        title: const Text('API Server Endpoint', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set host URL for Flask API backend:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F1523),
                hintText: 'http://10.0.2.2:5000',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC9933B)),
            child: const Text('Save & Reconnect', style: TextStyle(color: Color(0xFF0B0F19))),
            onPressed: () {
              _apiService.baseUrl = controller.text;
              Navigator.of(ctx).pop();
              _loadAnalytics();
            },
          ),
        ],
      ),
    );
  }
}
