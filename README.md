# Muskan Palace - Banquet Hall Management System
**Full-Stack Mobile & Backend Solution (Flask REST API + Cross-Platform Flutter App)**

---

## 🏛️ Project Overview

**Muskan Palace** is a production-ready Banquet Hall Management System designed to handle event bookings, prevent double-bookings through strict slot conflict rules, and provide real-time performance analytics for banquet hall administrators.

The system features:
1. **Python Flask Backend (`app.py`)**: SQLite/SQLAlchemy database models, automated conflict resolution engine, availability checker, booking engine, monthly financial/occupancy analytics, and an integrated interactive web console.
2. **Cross-Platform Flutter Mobile App (`lib/main.dart`)**: Material 3 dark/gold luxury theme, custom navigation with two core tabs:
   - **Tab 1: Performance Dashboard (`DashboardTab`)** - Live metrics (Total Bookings, Total Revenue, Average Booking Value, Occupancy Rate), payment collection progress, and slot distribution with pull-to-refresh.
   - **Tab 2: Calendar & Slot Booking (`CalendarBookingTab`)** - Interactive `TableCalendar` with booked date indicators, real-time availability cards (Morning, Evening, Full Day), and a modal bottom sheet booking form.

---

## 📁 Repository Structure

```
muskan palace/
├── app.py                      # Flask REST API backend, conflict engine, models, & web console
├── requirements.txt            # Python dependencies (Flask, Flask-SQLAlchemy, Flask-CORS, etc.)
├── seed_data.py                # Database seeder with realistic wedding & banquet bookings
├── test_app.py                 # Automated test suite (13 comprehensive test cases)
├── banquet.db                  # SQLite database generated automatically
├── pubspec.yaml                # Flutter project configuration (table_calendar, http, intl)
├── lib/
│   ├── main.dart               # App entry point, dark luxury theme, BottomNavigationBar
│   ├── models/
│   │   ├── booking.dart        # Booking data model with JSON serialization
│   │   ├── analytics.dart      # Monthly analytics data model
│   │   └── availability.dart   # Slot availability model
│   ├── services/
│   │   └── api_service.dart    # Robust HTTP client communicating with Flask backend
│   ├── tabs/
│   │   ├── dashboard_tab.dart  # Tab 1: Performance Dashboard with live metrics
│   │   └── calendar_booking_tab.dart # Tab 2: TableCalendar & Slot Availability inspector
│   └── widgets/
│       ├── metric_card.dart    # Glassmorphic KPI metric cards
│       ├── slot_card.dart      # Slot availability & booking detail cards
│       └── booking_form_modal.dart # Bottom sheet modal form for new bookings
└── web/
    └── index.html              # Flutter web support
```

---

## ⚙️ Slot Conflict Rules

The banquet hall operates on a standard of **2 discrete operational slots per day** (Morning and Evening) or **Full Day**:
- **Morning Slot:** 09:00 AM – 03:00 PM
- **Evening Slot:** 05:00 PM – 11:00 PM
- **Full Day Slot:** 09:00 AM – 11:00 PM

### Strict Conflict Matrix:
| Existing Booking on Date | Can Book Morning? | Can Book Evening? | Can Book Full Day? |
|--------------------------|-------------------|-------------------|--------------------|
| **None**                 | ✅ Yes            | ✅ Yes            | ✅ Yes             |
| **Morning Booked**       | ❌ No             | ✅ Yes            | ❌ No              |
| **Evening Booked**       | ✅ Yes            | ❌ No             | ❌ No              |
| **Both Morning & Evening**| ❌ No             | ❌ No             | ❌ No              |
| **Full Day Booked**      | ❌ No             | ❌ No             | ❌ No              |

*Note: Cancelled bookings automatically release reserved slots.*

---

## 🚀 Backend Quickstart (Flask)

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Seed Database (Optional but Recommended)
Populates the database with realistic sample wedding, engagement, and corporate bookings for the current month:
```bash
python seed_data.py
```

### 3. Run Automated Tests
Verifies all 13 unit tests covering availability, double-booking prevention, conflict logic, and monthly analytics formulas:
```bash
python -m unittest test_app.py
```

### 4. Start Backend Server
```bash
python app.py
```
- **API Base URL:** `http://127.0.0.1:5000`
- **Interactive Web Console:** Open `http://localhost:5000` in any web browser to inspect the live dashboard, availability calendar, and test bookings directly.

---

## 📡 Core REST API Endpoints

### 1. Check Slot Availability
- **Method & Route:** `GET /api/availability?date=YYYY-MM-DD`
- **Response `(200 OK)`:**
```json
{
  "date": "2026-10-12",
  "booked_slots": ["Morning"],
  "available_slots": ["Evening"],
  "is_fully_booked": false,
  "active_bookings_count": 1,
  "bookings": [
    {
      "id": 4,
      "customer_name": "TechCorp India (Annual Summit)",
      "customer_phone": "+91 98220 11990",
      "slot": "Morning",
      "status": "Confirmed",
      "total_amount": 95000.0,
      "advance_paid": 95000.0,
      "balance_amount": 0.0
    }
  ]
}
```

### 2. Create Booking
- **Method & Route:** `POST /api/bookings`
- **Request Body:**
```json
{
  "customer_name": "Ananya & Rohan Sharma",
  "customer_phone": "+91 98765 43210",
  "event_date": "2026-10-20",
  "slot": "Evening",
  "total_amount": 85000.0,
  "advance_paid": 35000.0,
  "status": "Confirmed"
}
```
- **Success Response `(201 Created)`:**
```json
{
  "success": true,
  "message": "Booking created successfully.",
  "booking_id": 10,
  "booking": { ... }
}
```
- **Conflict Response `(409 Conflict)`:**
```json
{
  "error": "Conflict",
  "message": "Slot 'Evening' is already booked on 2026-10-20."
}
```

### 3. Monthly Performance Analytics
- **Method & Route:** `GET /api/analytics/monthly?year=YYYY&month=M`
- **Formulas:**
  - `total_bookings` = Count of confirmed bookings in that month
  - `total_revenue` = Sum of `total_amount` for confirmed bookings
  - `average_booking_value` (ABV) = `total_revenue / total_bookings`
  - `occupancy_rate` (%) = `(slots_occupied / (days_in_month * 2)) * 100` *(Morning/Evening = 1 slot, Full Day = 2 slots)*
- **Response `(200 OK)`:**
```json
{
  "year": 2026,
  "month": 10,
  "month_name": "October",
  "total_bookings": 9,
  "total_revenue": 1270000.0,
  "average_booking_value": 141111.11,
  "occupancy_rate": 19.35,
  "total_advance_paid": 855000.0,
  "pending_balance": 415000.0,
  "slots_occupied": 12,
  "total_slots_capacity": 62,
  "days_in_month": 31,
  "slot_breakdown": {
    "Morning": 3,
    "Evening": 3,
    "Full Day": 3
  }
}
```

---

## 📱 Frontend Mobile App Quickstart (Flutter)

### 1. Requirements
- Flutter SDK `^3.0.0`
- Dart SDK `^3.0.0`

### 2. Dependencies
Included in `pubspec.yaml`:
- `table_calendar: ^3.1.2` - Custom calendar view and date selection
- `http: ^1.2.1` - REST API client
- `intl: ^0.19.0` - Currency and date formatting

### 3. Run the App
```bash
# Fetch dependencies
flutter pub get

# Run on connected device / emulator
flutter run

# Or run on Chrome Web
flutter run -d chrome
```

### Connecting to Backend from Mobile/Emulator:
The `ApiService` automatically detects platforms:
- **Android Emulator:** Points to `http://10.0.2.2:5000`
- **iOS Simulator / Web / Desktop:** Points to `http://127.0.0.1:5000`
- **Physical Devices:** Tap the gear icon ⚙️ in the Dashboard app bar to set your local Wi-Fi IP address (e.g., `http://192.168.1.100:5000`).

---

## 🧪 Automated Test Verification

All unit tests in `test_app.py` pass cleanly:
```
Ran 13 tests in 0.490s
OK
```
Tests include:
- `test_availability_empty_day`
- `test_availability_after_morning_booked`
- `test_availability_after_evening_booked`
- `test_availability_after_full_day_booked`
- `test_availability_both_morning_and_evening_booked`
- `test_cancelled_booking_does_not_block_slot`
- `test_create_booking_success`
- `test_create_booking_conflict_same_slot`
- `test_create_booking_conflict_full_day_when_morning_booked`
- `test_create_booking_conflict_morning_when_full_day_booked`
- `test_create_booking_validation_errors`
- `test_monthly_analytics_calculation`
- `test_monthly_analytics_zero_bookings`
