import unittest
import json
import calendar
from datetime import datetime
from app import app, db, Booking, SLOT_MORNING, SLOT_EVENING, SLOT_FULL_DAY, STATUS_CONFIRMED, STATUS_CANCELLED

class BanquetHallApiTestCase(unittest.TestCase):
    def setUp(self):
        # Configure app for testing with an in-memory SQLite database
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.client = app.test_client()

        with app.app_context():
            db.create_all()

    def tearDown(self):
        with app.app_context():
            db.session.remove()
            db.drop_all()

    # -------------------------------------------------------------
    # 1. Availability & Conflict Tests
    # -------------------------------------------------------------
    def test_availability_empty_day(self):
        """When no bookings exist, all slots should be available."""
        res = self.client.get('/api/availability?date=2026-11-10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['booked_slots'], [])
        self.assertCountEqual(data['available_slots'], [SLOT_MORNING, SLOT_EVENING, SLOT_FULL_DAY])
        self.assertFalse(data['is_fully_booked'])

    def test_availability_after_morning_booked(self):
        """Booking Morning should make 'Morning' and 'Full Day' unavailable, leaving 'Evening'."""
        with app.app_context():
            b = Booking(
                customer_name="Test Customer 1",
                customer_phone="9876543210",
                event_date="2026-11-10",
                slot=SLOT_MORNING,
                total_amount=50000.0,
                advance_paid=20000.0,
                status=STATUS_CONFIRMED
            )
            db.session.add(b)
            db.session.commit()

        res = self.client.get('/api/availability?date=2026-11-10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['booked_slots'], [SLOT_MORNING])
        self.assertEqual(data['available_slots'], [SLOT_EVENING])
        self.assertFalse(data['is_fully_booked'])

    def test_availability_after_evening_booked(self):
        """Booking Evening should make 'Evening' and 'Full Day' unavailable, leaving 'Morning'."""
        with app.app_context():
            b = Booking(
                customer_name="Test Customer 2",
                customer_phone="9876543210",
                event_date="2026-11-10",
                slot=SLOT_EVENING,
                total_amount=60000.0,
                advance_paid=30000.0,
                status=STATUS_CONFIRMED
            )
            db.session.add(b)
            db.session.commit()

        res = self.client.get('/api/availability?date=2026-11-10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['booked_slots'], [SLOT_EVENING])
        self.assertEqual(data['available_slots'], [SLOT_MORNING])
        self.assertFalse(data['is_fully_booked'])

    def test_availability_after_full_day_booked(self):
        """Booking Full Day should make all slots unavailable."""
        with app.app_context():
            b = Booking(
                customer_name="Test Customer 3",
                customer_phone="9876543210",
                event_date="2026-11-10",
                slot=SLOT_FULL_DAY,
                total_amount=150000.0,
                advance_paid=75000.0,
                status=STATUS_CONFIRMED
            )
            db.session.add(b)
            db.session.commit()

        res = self.client.get('/api/availability?date=2026-11-10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['booked_slots'], [SLOT_FULL_DAY])
        self.assertEqual(data['available_slots'], [])
        self.assertTrue(data['is_fully_booked'])

    def test_availability_both_morning_and_evening_booked(self):
        """Booking both Morning and Evening should leave no slots available."""
        with app.app_context():
            b1 = Booking(
                customer_name="Morning Customer",
                customer_phone="9876543210",
                event_date="2026-11-10",
                slot=SLOT_MORNING,
                total_amount=50000.0,
                advance_paid=20000.0,
                status=STATUS_CONFIRMED
            )
            b2 = Booking(
                customer_name="Evening Customer",
                customer_phone="9876543211",
                event_date="2026-11-10",
                slot=SLOT_EVENING,
                total_amount=60000.0,
                advance_paid=30000.0,
                status=STATUS_CONFIRMED
            )
            db.session.add_all([b1, b2])
            db.session.commit()

        res = self.client.get('/api/availability?date=2026-11-10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertCountEqual(data['booked_slots'], [SLOT_MORNING, SLOT_EVENING])
        self.assertEqual(data['available_slots'], [])
        self.assertTrue(data['is_fully_booked'])

    def test_cancelled_booking_does_not_block_slot(self):
        """Cancelled bookings should release the slot."""
        with app.app_context():
            b = Booking(
                customer_name="Cancelled Customer",
                customer_phone="9876543210",
                event_date="2026-11-10",
                slot=SLOT_FULL_DAY,
                total_amount=150000.0,
                advance_paid=75000.0,
                status=STATUS_CANCELLED
            )
            db.session.add(b)
            db.session.commit()

        res = self.client.get('/api/availability?date=2026-11-10')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['booked_slots'], [])
        self.assertCountEqual(data['available_slots'], [SLOT_MORNING, SLOT_EVENING, SLOT_FULL_DAY])

    # -------------------------------------------------------------
    # 2. POST /api/bookings Validation & Conflict Enforcement
    # -------------------------------------------------------------
    def test_create_booking_success(self):
        """Successful booking creation returns 201 and booking_id."""
        payload = {
            "customer_name": "Aman Verma",
            "customer_phone": "+91 99999 88888",
            "event_date": "2026-11-15",
            "slot": "Morning",
            "total_amount": 70000.0,
            "advance_paid": 30000.0
        }
        res = self.client.post('/api/bookings', json=payload)
        self.assertEqual(res.status_code, 201)
        data = res.get_json()

        self.assertTrue(data['success'])
        self.assertIn('booking_id', data)
        self.assertEqual(data['booking']['customer_name'], "Aman Verma")
        self.assertEqual(data['booking']['slot'], "Morning")

    def test_create_booking_conflict_same_slot(self):
        """Attempting to book an already booked slot returns 409 Conflict."""
        payload = {
            "customer_name": "First User",
            "customer_phone": "9876543210",
            "event_date": "2026-11-15",
            "slot": "Evening",
            "total_amount": 80000.0,
            "advance_paid": 40000.0
        }
        res1 = self.client.post('/api/bookings', json=payload)
        self.assertEqual(res1.status_code, 201)

        # Second attempt for same slot on same date
        payload2 = dict(payload)
        payload2["customer_name"] = "Second User"
        res2 = self.client.post('/api/bookings', json=payload2)
        self.assertEqual(res2.status_code, 409)
        self.assertIn("already booked", res2.get_json()['message'])

    def test_create_booking_conflict_full_day_when_morning_booked(self):
        """Cannot book Full Day if Morning is already booked."""
        self.client.post('/api/bookings', json={
            "customer_name": "Morning Guy",
            "customer_phone": "9876543210",
            "event_date": "2026-11-15",
            "slot": "Morning",
            "total_amount": 50000.0,
            "advance_paid": 20000.0
        })

        res = self.client.post('/api/bookings', json={
            "customer_name": "Full Day Guy",
            "customer_phone": "9876543211",
            "event_date": "2026-11-15",
            "slot": "Full Day",
            "total_amount": 120000.0,
            "advance_paid": 50000.0
        })
        self.assertEqual(res.status_code, 409)

    def test_create_booking_conflict_morning_when_full_day_booked(self):
        """Cannot book Morning if Full Day is already booked."""
        self.client.post('/api/bookings', json={
            "customer_name": "Full Day Booking",
            "customer_phone": "9876543210",
            "event_date": "2026-11-20",
            "slot": "Full Day",
            "total_amount": 200000.0,
            "advance_paid": 100000.0
        })

        res = self.client.post('/api/bookings', json={
            "customer_name": "Morning Guy",
            "customer_phone": "9876543211",
            "event_date": "2026-11-20",
            "slot": "Morning",
            "total_amount": 60000.0,
            "advance_paid": 30000.0
        })
        self.assertEqual(res.status_code, 409)

    def test_create_booking_validation_errors(self):
        """Missing fields, invalid slot, or bad amounts should return 400 Bad Request."""
        # Missing slot
        res = self.client.post('/api/bookings', json={
            "customer_name": "John Doe",
            "customer_phone": "1234567890",
            "event_date": "2026-11-20"
        })
        self.assertEqual(res.status_code, 400)

        # Invalid slot
        res = self.client.post('/api/bookings', json={
            "customer_name": "John Doe",
            "customer_phone": "1234567890",
            "event_date": "2026-11-20",
            "slot": "Midnight Party"
        })
        self.assertEqual(res.status_code, 400)

        # Advance > Total
        res = self.client.post('/api/bookings', json={
            "customer_name": "John Doe",
            "customer_phone": "1234567890",
            "event_date": "2026-11-20",
            "slot": "Morning",
            "total_amount": 50000.0,
            "advance_paid": 60000.0
        })
        self.assertEqual(res.status_code, 400)

    # -------------------------------------------------------------
    # 3. GET /api/analytics/monthly Tests
    # -------------------------------------------------------------
    def test_monthly_analytics_calculation(self):
        """
        Verify total confirmed bookings, total revenue, ABV, and occupancy rate:
        For November 2026 (30 days -> 60 slots capacity):
          - Booking 1: Morning (1 slot, total 60000, advance 30000)
          - Booking 2: Evening (1 slot, total 80000, advance 40000)
          - Booking 3: Full Day (2 slots, total 160000, advance 80000)
          - Booking 4: Cancelled (should be ignored)
        Expected:
          - Total bookings: 3
          - Total revenue: 60000 + 80000 + 160000 = 300000.0
          - ABV: 300000 / 3 = 100000.0
          - Slots occupied: 1 + 1 + 2 = 4 slots
          - Total capacity: 30 * 2 = 60 slots
          - Occupancy rate: (4 / 60) * 100 = 6.67%
        """
        with app.app_context():
            b1 = Booking(
                customer_name="Cust 1", customer_phone="1",
                event_date="2026-11-05", slot=SLOT_MORNING,
                total_amount=60000.0, advance_paid=30000.0, status=STATUS_CONFIRMED
            )
            b2 = Booking(
                customer_name="Cust 2", customer_phone="2",
                event_date="2026-11-06", slot=SLOT_EVENING,
                total_amount=80000.0, advance_paid=40000.0, status=STATUS_CONFIRMED
            )
            b3 = Booking(
                customer_name="Cust 3", customer_phone="3",
                event_date="2026-11-07", slot=SLOT_FULL_DAY,
                total_amount=160000.0, advance_paid=80000.0, status=STATUS_CONFIRMED
            )
            b4_cancelled = Booking(
                customer_name="Cust 4 Cancelled", customer_phone="4",
                event_date="2026-11-08", slot=SLOT_FULL_DAY,
                total_amount=200000.0, advance_paid=0.0, status=STATUS_CANCELLED
            )
            db.session.add_all([b1, b2, b3, b4_cancelled])
            db.session.commit()

        res = self.client.get('/api/analytics/monthly?year=2026&month=11')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['total_bookings'], 3)
        self.assertEqual(data['total_revenue'], 300000.0)
        self.assertEqual(data['average_booking_value'], 100000.0)
        self.assertEqual(data['slots_occupied'], 4)
        self.assertEqual(data['total_slots_capacity'], 60)
        self.assertEqual(data['occupancy_rate'], 6.67)
        self.assertEqual(data['total_advance_paid'], 150000.0)
        self.assertEqual(data['pending_balance'], 150000.0)

    def test_monthly_analytics_zero_bookings(self):
        """Check empty month metrics."""
        res = self.client.get('/api/analytics/monthly?year=2026&month=1')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()

        self.assertEqual(data['total_bookings'], 0)
        self.assertEqual(data['total_revenue'], 0.0)
        self.assertEqual(data['average_booking_value'], 0.0)
        self.assertEqual(data['occupancy_rate'], 0.0)


if __name__ == '__main__':
    unittest.main()
