import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/calendar_booking_tab.dart';
import 'tabs/all_bookings_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0F19),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MuskanPalaceApp());
}

class MuskanPalaceApp extends StatelessWidget {
  const MuskanPalaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muskan Palace - Banquet Management',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        primaryColor: const Color(0xFFC9933B),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC9933B),
          secondary: Color(0xFFF3C977),
          surface: Color(0xFF141A29),
          error: Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF101626),
          elevation: 0,
          centerTitle: false,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardTabState> _dashboardKey = GlobalKey();
  final GlobalKey<AllBookingsTabState> _allBookingsKey = GlobalKey();

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  void _handleBookingChanged() {
    // Force refresh across all tabs when any booking is created, altered, or deleted
    _dashboardKey.currentState?.refresh();
    _allBookingsKey.currentState?.fetchBookings();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(
        key: _dashboardKey,
        onNavigateToCalendar: () => _onTabTapped(1),
        onNavigateToAllBookings: () => _onTabTapped(2),
      ),
      CalendarBookingTab(
        onBookingCreated: _handleBookingChanged,
      ),
      AllBookingsTab(
        key: _allBookingsKey,
        onBookingChanged: _handleBookingChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101626),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFC9933B),
          unselectedItemColor: Colors.white.withValues(alpha: 0.4),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar & Slots',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'All Bookings',
            ),
          ],
        ),
      ),
    );
  }
}
