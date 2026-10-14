from datetime import datetime, timezone
from app import app, db, Booking, STATUS_CONFIRMED, SLOT_MORNING, SLOT_EVENING, SLOT_FULL_DAY

def seed():
    with app.app_context():
        # Create tables
        db.create_all()

        # Check if already seeded
        if Booking.query.count() > 0:
            print("Database already contains bookings. Skipping seeding.")
            return

        print("Seeding sample bookings for Muskan Palace Banquet Hall...")

        # Current year and month
        now = datetime.now(timezone.utc)
        y = now.year
        m = now.month

        sample_bookings = [
            # Day 3: Morning booking
            Booking(
                customer_name="Rajesh & Sunita Sharma (Engagement)",
                customer_phone="+91 98765 43210",
                event_date=f"{y:04d}-{m:02d}-03",
                slot=SLOT_MORNING,
                total_amount=75000.0,
                advance_paid=40000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 3: Evening booking
            Booking(
                customer_name="Dr. Vikram Malhotra (Birthday Celebration)",
                customer_phone="+91 98111 22334",
                event_date=f"{y:04d}-{m:02d}-03",
                slot=SLOT_EVENING,
                total_amount=85000.0,
                advance_paid=50000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 7: Full Day wedding
            Booking(
                customer_name="Kavita & Aman Verma (Grand Wedding)",
                customer_phone="+91 99223 88445",
                event_date=f"{y:04d}-{m:02d}-07",
                slot=SLOT_FULL_DAY,
                total_amount=220000.0,
                advance_paid=150000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 12: Morning Corporate Conference
            Booking(
                customer_name="TechCorp India (Annual Summit)",
                customer_phone="+91 98220 11990",
                event_date=f"{y:04d}-{m:02d}-12",
                slot=SLOT_MORNING,
                total_amount=95000.0,
                advance_paid=95000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 15: Full Day Reception & Sangeet
            Booking(
                customer_name="Rohit & Neha Singhania (Sangeet & Reception)",
                customer_phone="+91 97654 32109",
                event_date=f"{y:04d}-{m:02d}-15",
                slot=SLOT_FULL_DAY,
                total_amount=250000.0,
                advance_paid=180000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 18: Evening Anniversary
            Booking(
                customer_name="Sanjay & Ritu Kapoor (25th Anniversary)",
                customer_phone="+91 98333 44556",
                event_date=f"{y:04d}-{m:02d}-18",
                slot=SLOT_EVENING,
                total_amount=110000.0,
                advance_paid=60000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 22: Morning Haldi Ceremony
            Booking(
                customer_name="Gupta Family (Haldi & Mehendi)",
                customer_phone="+91 99444 55667",
                event_date=f"{y:04d}-{m:02d}-22",
                slot=SLOT_MORNING,
                total_amount=65000.0,
                advance_paid=30000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 25: Full Day Wedding Gala
            Booking(
                customer_name="Mehta & Agarwal Wedding Reception",
                customer_phone="+91 98888 77665",
                event_date=f"{y:04d}-{m:02d}-25",
                slot=SLOT_FULL_DAY,
                total_amount=280000.0,
                advance_paid=200000.0,
                status=STATUS_CONFIRMED
            ),
            # Day 28: Evening Gala Dinner
            Booking(
                customer_name="Rotary Club Excellence Awards",
                customer_phone="+91 98777 66554",
                event_date=f"{y:04d}-{m:02d}-28",
                slot=SLOT_EVENING,
                total_amount=90000.0,
                advance_paid=50000.0,
                status=STATUS_CONFIRMED
            )
        ]

        for b in sample_bookings:
            db.session.add(b)

        db.session.commit()
        print(f"Successfully seeded {len(sample_bookings)} bookings for {y}-{m:02d}.")

if __name__ == '__main__':
    seed()
