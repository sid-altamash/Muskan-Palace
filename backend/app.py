import os
import calendar
from datetime import datetime, timezone
from flask import Flask, request, jsonify, render_template_string
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS

# Initialize Flask App
app = Flask(__name__)

# Configuration
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
db_url = os.environ.get('DATABASE_URL', f'sqlite:///{os.path.join(BASE_DIR, "banquet.db")}')
if db_url and db_url.startswith('postgres://'):
    db_url = db_url.replace('postgres://', 'postgresql://', 1)
app.config['SQLALCHEMY_DATABASE_URI'] = db_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Enable CORS for cross-platform Flutter mobile & web clients
CORS(app, resources={r"/api/*": {"origins": "*"}})

# Initialize Database
db = SQLAlchemy(app)

with app.app_context():
    try:
        db.create_all()
    except Exception as e:
        app.logger.warning(f"Database initialization note: {e}")

# Allowed Slot Options
SLOT_MORNING = "Morning"
SLOT_EVENING = "Evening"
SLOT_FULL_DAY = "Full Day"
ALL_SLOTS = [SLOT_MORNING, SLOT_EVENING, SLOT_FULL_DAY]

# Allowed Booking Statuses
STATUS_TENTATIVE = "Tentative"
STATUS_CONFIRMED = "Confirmed"
STATUS_CANCELLED = "Cancelled"
ALL_STATUSES = [STATUS_TENTATIVE, STATUS_CONFIRMED, STATUS_CANCELLED]


# ==========================================
# Database Models
# ==========================================
class Booking(db.Model):
    __tablename__ = 'bookings'

    id = db.Column(db.Integer, primary_key=True)
    customer_name = db.Column(db.String(120), nullable=False)
    customer_phone = db.Column(db.String(25), nullable=False)
    event_date = db.Column(db.String(10), nullable=False, index=True)  # Format: "YYYY-MM-DD"
    slot = db.Column(db.String(20), nullable=False)  # "Morning", "Evening", "Full Day"
    total_amount = db.Column(db.Float, nullable=False, default=0.0)
    advance_paid = db.Column(db.Float, nullable=False, default=0.0)
    status = db.Column(db.String(20), nullable=False, default=STATUS_CONFIRMED)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    def to_dict(self):
        """Serialize model instance to dictionary."""
        return {
            "id": self.id,
            "customer_name": self.customer_name,
            "customer_phone": self.customer_phone,
            "event_date": self.event_date,
            "slot": self.slot,
            "total_amount": float(self.total_amount),
            "advance_paid": float(self.advance_paid),
            "balance_amount": round(float(self.total_amount - self.advance_paid), 2),
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }


# ==========================================
# Slot Conflict & Availability Logic
# ==========================================
def get_slot_availability(date_str, exclude_booking_id=None):
    """
    Computes booked and available slots for a given date string ('YYYY-MM-DD').
    Conflict Rules:
      - If 'Full Day' is booked, all slots ('Morning', 'Evening', 'Full Day') are unavailable.
      - If 'Morning' is booked, 'Morning' and 'Full Day' are unavailable.
      - If 'Evening' is booked, 'Evening' and 'Full Day' are unavailable.
      - If both 'Morning' and 'Evening' are booked, all slots are unavailable.
      - Cancelled bookings do NOT block availability.
    """
    query = Booking.query.filter(
        Booking.event_date == date_str,
        Booking.status != STATUS_CANCELLED
    )
    if exclude_booking_id:
        query = query.filter(Booking.id != exclude_booking_id)

    active_bookings = query.all()
    booked_slots = [b.slot for b in active_bookings]

    has_full_day = SLOT_FULL_DAY in booked_slots
    has_morning = SLOT_MORNING in booked_slots
    has_evening = SLOT_EVENING in booked_slots

    if has_full_day:
        available_slots = []
    else:
        available_slots = []
        if not has_morning:
            available_slots.append(SLOT_MORNING)
        if not has_evening:
            available_slots.append(SLOT_EVENING)
        # Full day is only available if NEITHER Morning NOR Evening is booked
        if not has_morning and not has_evening:
            available_slots.append(SLOT_FULL_DAY)

    return booked_slots, available_slots, active_bookings


def is_slot_conflicting(date_str, requested_slot, exclude_booking_id=None):
    """
    Checks if requesting `requested_slot` on `date_str` conflicts with existing bookings.
    Returns (conflicts: bool, reason: str).
    """
    booked_slots, available_slots, _ = get_slot_availability(date_str, exclude_booking_id)

    if requested_slot not in available_slots:
        if SLOT_FULL_DAY in booked_slots:
            return True, f"Date {date_str} is fully booked ('Full Day' reserved)."
        elif requested_slot == SLOT_FULL_DAY:
            return True, f"'Full Day' cannot be booked because {', '.join(booked_slots)} is already reserved on {date_str}."
        else:
            return True, f"Slot '{requested_slot}' is already booked on {date_str}."

    return False, ""


# ==========================================
# REST API Endpoints
# ==========================================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "Banquet Hall Management API",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 200


@app.route('/api/availability', methods=['GET'])
def check_availability():
    """
    GET /api/availability?date=YYYY-MM-DD
    Returns booked_slots and available_slots for the given date.
    """
    date_str = request.args.get('date')
    if not date_str:
        return jsonify({
            "error": "Bad Request",
            "message": "Query parameter 'date' (format: YYYY-MM-DD) is required."
        }), 400

    # Validate date format
    try:
        datetime.strptime(date_str, '%Y-%m-%d')
    except ValueError:
        return jsonify({
            "error": "Bad Request",
            "message": "Invalid date format. Expected 'YYYY-MM-DD'."
        }), 400

    booked_slots, available_slots, active_bookings = get_slot_availability(date_str)

    # All bookings on that date (including cancelled for reference)
    all_date_bookings = Booking.query.filter(Booking.event_date == date_str).order_by(Booking.id.asc()).all()

    return jsonify({
        "date": date_str,
        "booked_slots": booked_slots,
        "available_slots": available_slots,
        "is_fully_booked": len(available_slots) == 0,
        "active_bookings_count": len(active_bookings),
        "bookings": [b.to_dict() for b in all_date_bookings]
    }), 200


@app.route('/api/bookings', methods=['POST'])
def create_booking():
    """
    POST /api/bookings
    Payload: {
        "customer_name": "...",
        "customer_phone": "...",
        "event_date": "YYYY-MM-DD",
        "slot": "Morning" | "Evening" | "Full Day",
        "total_amount": 100000.0,
        "advance_paid": 40000.0,
        "status": "Confirmed" (optional, default: Confirmed)
    }
    """
    data = request.get_json(silent=True)
    if not data:
        return jsonify({
            "error": "Bad Request",
            "message": "Request body must be a valid JSON object."
        }), 400

    # Required field validation
    required_fields = ['customer_name', 'customer_phone', 'event_date', 'slot']
    missing_fields = [f for f in required_fields if f not in data or str(data[f]).strip() == '']
    if missing_fields:
        return jsonify({
            "error": "Bad Request",
            "message": f"Missing required fields: {', '.join(missing_fields)}"
        }), 400

    customer_name = str(data['customer_name']).strip()
    customer_phone = str(data['customer_phone']).strip()
    event_date = str(data['event_date']).strip()
    slot = str(data['slot']).strip()

    # Slot option validation
    if slot not in ALL_SLOTS:
        return jsonify({
            "error": "Bad Request",
            "message": f"Invalid slot '{slot}'. Must be one of: {ALL_SLOTS}"
        }), 400

    # Date format validation
    try:
        datetime.strptime(event_date, '%Y-%m-%d')
    except ValueError:
        return jsonify({
            "error": "Bad Request",
            "message": "Invalid 'event_date' format. Expected 'YYYY-MM-DD'."
        }), 400

    # Amounts validation
    try:
        total_amount = float(data.get('total_amount', 0.0))
        advance_paid = float(data.get('advance_paid', 0.0))
    except (ValueError, TypeError):
        return jsonify({
            "error": "Bad Request",
            "message": "'total_amount' and 'advance_paid' must be numeric values."
        }), 400

    if total_amount < 0 or advance_paid < 0:
        return jsonify({
            "error": "Bad Request",
            "message": "Amounts cannot be negative."
        }), 400

    if advance_paid > total_amount:
        return jsonify({
            "error": "Bad Request",
            "message": "'advance_paid' cannot exceed 'total_amount'."
        }), 400

    status = str(data.get('status', STATUS_CONFIRMED)).strip()
    if status not in ALL_STATUSES:
        status = STATUS_CONFIRMED

    # Conflict check
    if status != STATUS_CANCELLED:
        conflicting, reason = is_slot_conflicting(event_date, slot)
        if conflicting:
            return jsonify({
                "error": "Conflict",
                "message": reason
            }), 409

    # Create new booking
    new_booking = Booking(
        customer_name=customer_name,
        customer_phone=customer_phone,
        event_date=event_date,
        slot=slot,
        total_amount=total_amount,
        advance_paid=advance_paid,
        status=status
    )

    db.session.add(new_booking)
    db.session.commit()

    return jsonify({
        "success": True,
        "message": "Booking created successfully.",
        "booking_id": new_booking.id,
        "booking": new_booking.to_dict()
    }), 201


@app.route('/api/bookings', methods=['GET'])
def list_bookings():
    """
    GET /api/bookings?date=YYYY-MM-DD&month=M&year=YYYY&status=Confirmed
    Returns list of bookings matching filters.
    """
    query = Booking.query

    date_str = request.args.get('date')
    if date_str:
        query = query.filter(Booking.event_date == date_str)

    year = request.args.get('year')
    month = request.args.get('month')
    if year and month:
        try:
            y = int(year)
            m = int(month)
            prefix = f"{y:04d}-{m:02d}"
            query = query.filter(Booking.event_date.startswith(prefix))
        except ValueError:
            pass

    status = request.args.get('status')
    if status:
        query = query.filter(Booking.status == status)

    bookings = query.order_by(Booking.event_date.asc(), Booking.id.asc()).all()
    return jsonify({
        "count": len(bookings),
        "bookings": [b.to_dict() for b in bookings]
    }), 200


@app.route('/api/bookings/<int:booking_id>', methods=['GET'])
def get_booking(booking_id):
    """GET /api/bookings/<id>"""
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Not Found", "message": f"Booking ID {booking_id} not found."}), 404
    return jsonify(booking.to_dict()), 200


@app.route('/api/bookings/<int:booking_id>', methods=['PATCH', 'PUT'])
def update_booking(booking_id):
    """
    PATCH / PUT /api/bookings/<id>
    Update booking fields: customer_name, customer_phone, slot, event_date, total_amount, advance_paid, status
    """
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Not Found", "message": f"Booking ID {booking_id} not found."}), 404

    data = request.get_json(silent=True) or {}

    if 'customer_name' in data and str(data['customer_name']).strip():
        booking.customer_name = str(data['customer_name']).strip()

    if 'customer_phone' in data and str(data['customer_phone']).strip():
        booking.customer_phone = str(data['customer_phone']).strip()

    new_date = str(data.get('event_date', booking.event_date)).strip()
    new_slot = str(data.get('slot', booking.slot)).strip()
    new_status = str(data.get('status', booking.status)).strip()

    if new_status in ALL_STATUSES:
        booking.status = new_status

    # Validate slot conflict if changing date/slot or reopening a cancelled booking
    if new_status != STATUS_CANCELLED:
        if new_slot not in ALL_SLOTS:
            return jsonify({"error": "Bad Request", "message": f"Invalid slot: {new_slot}"}), 400
        try:
            datetime.strptime(new_date, '%Y-%m-%d')
        except ValueError:
            return jsonify({"error": "Bad Request", "message": "Invalid date format."}), 400

        conflicting, reason = is_slot_conflicting(new_date, new_slot, exclude_booking_id=booking.id)
        if conflicting:
            return jsonify({
                "error": "Conflict",
                "message": f"Cannot move booking: {reason}"
            }), 409

        booking.event_date = new_date
        booking.slot = new_slot

    if 'total_amount' in data:
        try:
            booking.total_amount = float(data['total_amount'])
        except (ValueError, TypeError):
            return jsonify({"error": "Bad Request", "message": "total_amount must be numeric"}), 400

    if 'advance_paid' in data:
        try:
            new_advance = float(data['advance_paid'])
            if 0 <= new_advance <= booking.total_amount:
                booking.advance_paid = new_advance
            else:
                return jsonify({"error": "Bad Request", "message": "advance_paid cannot exceed total_amount."}), 400
        except (ValueError, TypeError):
            return jsonify({"error": "Bad Request", "message": "advance_paid must be numeric."}), 400

    db.session.commit()
    return jsonify({
        "success": True,
        "message": "Booking updated successfully.",
        "booking": booking.to_dict()
    }), 200


@app.route('/api/bookings/<int:booking_id>', methods=['DELETE'])
def delete_booking(booking_id):
    """
    DELETE /api/bookings/<id>
    Permanently deletes a booking.
    """
    booking = db.session.get(Booking, booking_id)
    if not booking:
        return jsonify({"error": "Not Found", "message": f"Booking ID {booking_id} not found."}), 404

    db.session.delete(booking)
    db.session.commit()

    return jsonify({
        "success": True,
        "message": f"Booking #{booking_id} deleted successfully."
    }), 200


@app.route('/api/bookings/reset', methods=['POST'])
def reset_all_bookings():
    """
    POST /api/bookings/reset
    Deletes all bookings in the database so the user starts with 0 bookings.
    """
    count = Booking.query.count()
    Booking.query.delete()
    db.session.commit()

    return jsonify({
        "success": True,
        "message": f"Cleared {count} bookings. Database is now completely empty."
    }), 200


@app.route('/api/bookings/seed', methods=['POST'])
def reseed_bookings():
    """
    POST /api/bookings/seed
    Re-populates demo bookings.
    """
    from seed_data import seed
    Booking.query.delete()
    db.session.commit()
    seed()

    return jsonify({
        "success": True,
        "message": "Sample bookings loaded successfully."
    }), 200


@app.route('/api/analytics/monthly', methods=['GET'])
def get_monthly_analytics():
    """
    GET /api/analytics/monthly?year=YYYY&month=M
    Computes monthly metrics for confirmed bookings:
      - Total confirmed bookings count
      - Total revenue sum
      - Average booking value (ABV)
      - Occupancy rate percentage (based on 2 slots per day standard)
    """
    now = datetime.now(timezone.utc)
    year_param = request.args.get('year')
    month_param = request.args.get('month')

    try:
        year = int(year_param) if year_param else now.year
        month = int(month_param) if month_param else now.month
    except ValueError:
        return jsonify({
            "error": "Bad Request",
            "message": "Invalid 'year' or 'month' parameter. Must be integers."
        }), 400

    if month < 1 or month > 12:
        return jsonify({
            "error": "Bad Request",
            "message": "'month' must be between 1 and 12."
        }), 400

    if year < 1900 or year > 2100:
        return jsonify({
            "error": "Bad Request",
            "message": "'year' must be between 1900 and 2100."
        }), 400

    # Prefix for date matching: 'YYYY-MM'
    date_prefix = f"{year:04d}-{month:02d}"

    # Query confirmed bookings for this month
    confirmed_bookings = Booking.query.filter(
        Booking.event_date.startswith(date_prefix),
        Booking.status == STATUS_CONFIRMED
    ).all()

    total_bookings = len(confirmed_bookings)
    total_revenue = sum(b.total_amount for b in confirmed_bookings)
    total_advance_paid = sum(b.advance_paid for b in confirmed_bookings)
    pending_balance = total_revenue - total_advance_paid

    # Average Booking Value (ABV)
    average_booking_value = round(total_revenue / total_bookings, 2) if total_bookings > 0 else 0.0

    # Days in month and total slots capacity (2 slots per day standard: Morning + Evening)
    days_in_month = calendar.monthrange(year, month)[1]
    total_slots_capacity = days_in_month * 2

    # Slots occupied: 'Full Day' counts as 2 slots; 'Morning' and 'Evening' count as 1 slot each
    slots_occupied = 0
    slot_breakdown = {SLOT_MORNING: 0, SLOT_EVENING: 0, SLOT_FULL_DAY: 0}

    for b in confirmed_bookings:
        if b.slot == SLOT_FULL_DAY:
            slots_occupied += 2
            slot_breakdown[SLOT_FULL_DAY] += 1
        elif b.slot == SLOT_MORNING:
            slots_occupied += 1
            slot_breakdown[SLOT_MORNING] += 1
        elif b.slot == SLOT_EVENING:
            slots_occupied += 1
            slot_breakdown[SLOT_EVENING] += 1

    # Occupancy rate percentage
    occupancy_rate = round((slots_occupied / total_slots_capacity) * 100, 2) if total_slots_capacity > 0 else 0.0

    month_name = calendar.month_name[month]

    return jsonify({
        "year": year,
        "month": month,
        "month_name": month_name,
        "total_bookings": total_bookings,
        "total_revenue": round(total_revenue, 2),
        "average_booking_value": average_booking_value,
        "occupancy_rate": occupancy_rate,
        "total_advance_paid": round(total_advance_paid, 2),
        "pending_balance": round(pending_balance, 2),
        "slots_occupied": slots_occupied,
        "total_slots_capacity": total_slots_capacity,
        "days_in_month": days_in_month,
        "slot_breakdown": slot_breakdown
    }), 200


@app.route('/api/calendar/month-summary', methods=['GET'])
def get_month_summary():
    """
    GET /api/calendar/month-summary?year=YYYY&month=M
    Helper endpoint returning day-by-day availability summary for the whole month.
    Allows Flutter calendar to display markers and highlights with a single HTTP call.
    """
    now = datetime.now(timezone.utc)
    try:
        year = int(request.args.get('year', now.year))
        month = int(request.args.get('month', now.month))
    except ValueError:
        return jsonify({"error": "Bad Request", "message": "Invalid year or month"}), 400

    date_prefix = f"{year:04d}-{month:02d}"
    bookings = Booking.query.filter(
        Booking.event_date.startswith(date_prefix),
        Booking.status != STATUS_CANCELLED
    ).all()

    # Group by date
    days_data = {}
    for b in bookings:
        d = b.event_date
        if d not in days_data:
            days_data[d] = []
        days_data[d].append(b.to_dict())

    days_in_month = calendar.monthrange(year, month)[1]
    result = {}
    for day in range(1, days_in_month + 1):
        d_str = f"{year:04d}-{month:02d}-{day:02d}"
        day_bookings = days_data.get(d_str, [])
        booked_slots = [b['slot'] for b in day_bookings]
        is_full = (SLOT_FULL_DAY in booked_slots) or (SLOT_MORNING in booked_slots and SLOT_EVENING in booked_slots)
        result[d_str] = {
            "date": d_str,
            "booked_slots": booked_slots,
            "is_fully_booked": is_full,
            "booking_count": len(day_bookings),
            "bookings": day_bookings
        }

    return jsonify({
        "year": year,
        "month": month,
        "summary": result
    }), 200


# ==========================================
# Interactive Web Dashboard / API Preview
# ==========================================
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Muskan Palace - Banquet Hall Management Console</title>
  <link rel="icon" type="image/png" href="/static/images/logo_web.png">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=Playfair+Display:wght@700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0b0f19;
      --card-bg: rgba(23, 30, 48, 0.75);
      --card-border: rgba(255, 255, 255, 0.08);
      --primary: #c9933b;
      --primary-light: #f3c977;
      --accent: #6366f1;
      --success: #10b981;
      --danger: #ef4444;
      --warning: #f59e0b;
      --text-main: #f8fafc;
      --text-muted: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background: radial-gradient(circle at 10% 20%, #171b2f 0%, #080c14 90%);
      color: var(--text-main);
      min-height: 100vh;
      padding: 24px;
    }
    .container { max-width: 1280px; margin: 0 auto; }
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16px 24px;
      background: var(--card-bg);
      backdrop-filter: blur(12px);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      margin-bottom: 24px;
      flex-wrap: wrap;
      gap: 16px;
    }
    .logo-area { display: flex; align-items: center; gap: 14px; }
    .logo-badge {
      width: 52px; height: 52px; border-radius: 12px;
      display: flex; align-items: center; justify-content: center;
      box-shadow: 0 4px 16px rgba(201, 147, 59, 0.35);
      border: 1.5px solid rgba(201, 147, 59, 0.6);
      overflow: hidden;
      background: #141a29;
    }
    .logo-badge img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
    .title-box h1 { font-family: 'Playfair Display', serif; font-size: 24px; color: var(--primary-light); }
    .title-box p { font-size: 13px; color: var(--text-muted); }
    
    .header-actions { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
    .action-btn {
      padding: 8px 14px; border-radius: 8px; font-size: 13px; font-weight: 600;
      cursor: pointer; transition: all 0.2s; border: 1px solid transparent; font-family: inherit;
    }
    .btn-outline-danger {
      background: rgba(239, 68, 68, 0.12); color: #f87171; border-color: rgba(239, 68, 68, 0.3);
    }
    .btn-outline-danger:hover { background: rgba(239, 68, 68, 0.25); }
    .btn-outline-primary {
      background: rgba(201, 147, 59, 0.12); color: var(--primary-light); border-color: rgba(201, 147, 59, 0.3);
    }
    .btn-outline-primary:hover { background: rgba(201, 147, 59, 0.25); }
    .btn-outline-info {
      background: rgba(99, 102, 241, 0.12); color: #a5b4fc; border-color: rgba(99, 102, 241, 0.3);
    }
    .btn-outline-info:hover { background: rgba(99, 102, 241, 0.25); }

    .badge {
      padding: 6px 12px; border-radius: 999px; font-size: 12px; font-weight: 600;
      background: rgba(16, 185, 129, 0.15); color: var(--success); border: 1px solid rgba(16, 185, 129, 0.3);
    }
    
    /* Metrics Grid */
    .metrics-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 16px;
      margin-bottom: 28px;
    }
    .metric-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 20px;
      position: relative;
      overflow: hidden;
      transition: transform 0.2s ease, border-color 0.2s ease;
    }
    .metric-card:hover { transform: translateY(-2px); border-color: rgba(201, 147, 59, 0.4); }
    .metric-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
    .metric-title { font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-muted); font-weight: 600; }
    .metric-icon { font-size: 20px; }
    .metric-val { font-size: 30px; font-weight: 800; color: #fff; margin-bottom: 6px; }
    .metric-sub { font-size: 12px; color: var(--text-muted); }
    
    /* Layout Columns */
    .main-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
    }
    @media(max-width: 900px) { .main-grid { grid-template-columns: 1fr; } }
    
    .panel {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 24px;
    }
    .panel-header {
      display: flex; justify-content: space-between; align-items: center;
      margin-bottom: 20px; padding-bottom: 12px; border-bottom: 1px solid var(--card-border);
    }
    .panel-header h2 { font-size: 18px; font-weight: 700; color: #f1f5f9; display: flex; align-items: center; gap: 8px; }
    
    /* Form controls */
    .form-group { margin-bottom: 16px; }
    label { display: block; font-size: 13px; font-weight: 600; color: #cbd5e1; margin-bottom: 6px; }
    input, select {
      width: 100%; padding: 12px 14px; border-radius: 10px;
      background: #0f172a; border: 1px solid rgba(255, 255, 255, 0.12);
      color: #fff; font-size: 14px; font-family: inherit;
      outline: none; transition: border-color 0.2s;
    }
    input:focus, select:focus { border-color: var(--primary); }
    .form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
    
    .btn {
      width: 100%; padding: 14px; border-radius: 10px; border: none; cursor: pointer;
      font-weight: 700; font-size: 15px; font-family: inherit;
      transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 8px;
    }
    .btn-primary {
      background: linear-gradient(135deg, var(--primary), #b37e2b);
      color: #0b0f19;
      box-shadow: 0 4px 14px rgba(201, 147, 59, 0.35);
    }
    .btn-primary:hover { filter: brightness(1.1); transform: translateY(-1px); }
    
    /* Availability view */
    .slot-list { display: flex; flex-direction: column; gap: 10px; margin-top: 14px; }
    .slot-item {
      display: flex; justify-content: space-between; align-items: center;
      padding: 14px 18px; border-radius: 10px; font-weight: 600;
    }
    .slot-available {
      background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); color: #34d399;
    }
    .slot-booked {
      background: rgba(239, 68, 68, 0.12); border: 1px solid rgba(239, 68, 68, 0.3); color: #f87171;
    }
    .booking-list { margin-top: 20px; display: flex; flex-direction: column; gap: 12px; max-height: 380px; overflow-y: auto; }
    
    /* Card with action controls */
    .booking-card {
      background: #0f172a; border: 1px solid var(--card-border);
      border-radius: 12px; padding: 14px 16px; font-size: 13px;
    }
    .booking-card-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
    .booking-card-sub { color: var(--text-muted); font-size: 12px; margin-bottom: 10px; line-height: 1.5; }
    .card-actions {
      display: flex; gap: 8px; justify-content: flex-end; padding-top: 8px; border-top: 1px solid rgba(255, 255, 255, 0.06);
    }
    .btn-xs {
      padding: 4px 10px; font-size: 11px; font-weight: 700; border-radius: 6px; cursor: pointer; border: none;
      display: inline-flex; align-items: center; gap: 4px; font-family: inherit;
    }
    .btn-edit { background: rgba(99, 102, 241, 0.2); color: #a5b4fc; }
    .btn-edit:hover { background: rgba(99, 102, 241, 0.35); }
    .btn-cancel { background: rgba(245, 158, 11, 0.2); color: #fbbf24; }
    .btn-cancel:hover { background: rgba(245, 158, 11, 0.35); }
    .btn-reopen { background: rgba(16, 185, 129, 0.2); color: #34d399; }
    .btn-reopen:hover { background: rgba(16, 185, 129, 0.35); }
    .btn-del { background: rgba(239, 68, 68, 0.2); color: #f87171; }
    .btn-del:hover { background: rgba(239, 68, 68, 0.35); }

    .toast {
      padding: 12px 16px; border-radius: 8px; margin-top: 14px; font-size: 13px; font-weight: 600; display: none;
    }
    .toast-success { background: rgba(16, 185, 129, 0.2); color: #34d399; border: 1px solid #10b981; }
    .toast-error { background: rgba(239, 68, 68, 0.2); color: #f87171; border: 1px solid #ef4444; }

    /* Modal styling */
    .modal-overlay {
      position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0, 0, 0, 0.75); backdrop-filter: blur(4px);
      display: none; align-items: center; justify-content: center; z-index: 1000; padding: 20px;
    }
    .modal-box {
      background: #141a29; border: 1px solid rgba(201, 147, 59, 0.4);
      border-radius: 16px; width: 100%; max-width: 520px; padding: 24px; max-height: 90vh; overflow-y: auto;
    }
    .modal-wide { max-width: 800px; }
    .modal-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; border-bottom: 1px solid var(--card-border); padding-bottom: 10px; }
    .modal-top h3 { font-size: 18px; color: var(--primary-light); }
    .modal-close { background: none; border: none; font-size: 20px; color: #94a3b8; cursor: pointer; }
    .table-container { max-height: 400px; overflow-y: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 13px; }
    th { text-align: left; padding: 10px 12px; background: #0f172a; color: var(--text-muted); font-weight: 600; border-bottom: 1px solid var(--card-border); }
    td { padding: 10px 12px; border-bottom: 1px solid var(--card-border); }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="logo-area">
        <div class="logo-badge">
          <img src="/static/images/logo_web.png" alt="Muskan Palace" onerror="this.parentElement.innerHTML='🏛️';">
        </div>
        <div class="title-box">
          <h1>Muskan Palace</h1>
          <p>Banquet Hall Management System &bull; Live API Console</p>
        </div>
      </div>
      <div class="header-actions">
        <button class="action-btn btn-outline-info" onclick="openAllBookingsModal()">
          📋 Manage All Bookings
        </button>
        <button class="action-btn btn-outline-danger" onclick="confirmResetAll()">
          🧹 Clear All Bookings (Fresh Slate)
        </button>
        <button class="action-btn btn-outline-primary" onclick="loadSampleData()">
          🌱 Load Demo Bookings
        </button>
        <span class="badge">● REST API Active</span>
      </div>
    </header>

    <!-- Metrics Row -->
    <div class="metrics-grid" id="metricsRow">
      <div class="metric-card">
        <div class="metric-header">
          <span class="metric-title">Total Bookings</span>
          <span class="metric-icon">📅</span>
        </div>
        <div class="metric-val" id="totalBookingsVal">--</div>
        <div class="metric-sub" id="bookingsSub">Confirmed for month</div>
      </div>

      <div class="metric-card">
        <div class="metric-header">
          <span class="metric-title">Total Revenue</span>
          <span class="metric-icon">💰</span>
        </div>
        <div class="metric-val" id="totalRevenueVal">--</div>
        <div class="metric-sub" id="revenueSub">Gross booking revenue</div>
      </div>

      <div class="metric-card">
        <div class="metric-header">
          <span class="metric-title">Avg Booking Value</span>
          <span class="metric-icon">💎</span>
        </div>
        <div class="metric-val" id="abvVal">--</div>
        <div class="metric-sub">Average per event</div>
      </div>

      <div class="metric-card">
        <div class="metric-header">
          <span class="metric-title">Occupancy Rate</span>
          <span class="metric-icon">📊</span>
        </div>
        <div class="metric-val" id="occupancyVal">--</div>
        <div class="metric-sub" id="occupancySub">Based on 2 slots/day</div>
      </div>
    </div>

    <!-- Main Grid -->
    <div class="main-grid">
      <!-- Left Panel: Slot Availability & Calendar Inspector -->
      <div class="panel">
        <div class="panel-header">
          <h2><span>🔍</span> Check Date Availability</h2>
          <input type="date" id="checkDateInput" style="width: auto; padding: 6px 12px;">
        </div>

        <div id="availabilityStatus" style="font-size: 14px; margin-bottom: 12px; color: var(--text-muted);">
          Select a date to inspect slots, modify bookings, or clear slots.
        </div>

        <div class="slot-list" id="slotListDisplay">
          <!-- Dynamically populated -->
        </div>

        <div style="margin-top: 24px;">
          <h3 style="font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--text-muted); margin-bottom: 10px;">
            Bookings on this Date (Modify, Cancel, or Delete)
          </h3>
          <div class="booking-list" id="dateBookingsList">
            <div style="color: var(--text-muted); font-size: 13px; text-align: center; padding: 20px;">
              No bookings recorded for this date.
            </div>
          </div>
        </div>
      </div>

      <!-- Right Panel: New Booking Form -->
      <div class="panel">
        <div class="panel-header">
          <h2><span>✍️</span> Create New Booking</h2>
          <span style="font-size: 12px; color: var(--primary-light);">POST /api/bookings</span>
        </div>

        <form id="bookingForm">
          <div class="form-row">
            <div class="form-group">
              <label for="custName">Customer Name</label>
              <input type="text" id="custName" placeholder="e.g. Ananya Sharma" required>
            </div>
            <div class="form-group">
              <label for="custPhone">Customer Phone</label>
              <input type="tel" id="custPhone" placeholder="e.g. +91 98765 43210" required>
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label for="eventDate">Event Date</label>
              <input type="date" id="eventDate" required>
            </div>
            <div class="form-group">
              <label for="slotSelect">Slot Option</label>
              <select id="slotSelect" required>
                <option value="">Select available slot...</option>
                <option value="Morning">Morning (9 AM - 3 PM)</option>
                <option value="Evening">Evening (5 PM - 11 PM)</option>
                <option value="Full Day">Full Day (9 AM - 11 PM)</option>
              </select>
            </div>
          </div>

          <div class="form-row">
            <div class="form-group">
              <label for="totalAmt">Total Amount (₹)</label>
              <input type="number" id="totalAmt" placeholder="85000" min="0" step="1000" required>
            </div>
            <div class="form-group">
              <label for="advanceAmt">Advance Paid (₹)</label>
              <input type="number" id="advanceAmt" placeholder="35000" min="0" step="1000" required>
            </div>
          </div>

          <button type="submit" class="btn btn-primary" id="submitBtn">
            Confirm & Save Booking
          </button>

          <div id="toastBox" class="toast"></div>
        </form>
      </div>
    </div>
  </div>

  <!-- Edit Booking Modal -->
  <div class="modal-overlay" id="editModal">
    <div class="modal-box">
      <div class="modal-top">
        <h3 id="editModalTitle">✏️ Modify Booking</h3>
        <button class="modal-close" onclick="closeEditModal()">&times;</button>
      </div>
      <form id="editForm">
        <input type="hidden" id="editBookingId">
        <div class="form-group">
          <label>Customer Name</label>
          <input type="text" id="editCustName" required>
        </div>
        <div class="form-group">
          <label>Customer Phone</label>
          <input type="tel" id="editCustPhone" required>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Event Date</label>
            <input type="date" id="editEventDate" required>
          </div>
          <div class="form-group">
            <label>Slot</label>
            <select id="editSlotSelect" required>
              <option value="Morning">Morning</option>
              <option value="Evening">Evening</option>
              <option value="Full Day">Full Day</option>
            </select>
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Total Amount (₹)</label>
            <input type="number" id="editTotalAmt" required min="0">
          </div>
          <div class="form-group">
            <label>Advance Paid (₹)</label>
            <input type="number" id="editAdvanceAmt" required min="0">
          </div>
        </div>
        <div class="form-group">
          <label>Booking Status</label>
          <select id="editStatusSelect" required>
            <option value="Confirmed">Confirmed</option>
            <option value="Tentative">Tentative</option>
            <option value="Cancelled">Cancelled (Frees Up Slot!)</option>
          </select>
        </div>
        <div style="display:flex; gap:10px; margin-top:20px;">
          <button type="button" class="btn" style="background:#334155; color:#fff;" onclick="closeEditModal()">Cancel</button>
          <button type="submit" class="btn btn-primary">Save Changes</button>
        </div>
      </form>
    </div>
  </div>

  <!-- Manage All Bookings Modal -->
  <div class="modal-overlay" id="allBookingsModal">
    <div class="modal-box modal-wide">
      <div class="modal-top">
        <h3>📋 All Bookings in System</h3>
        <button class="modal-close" onclick="closeAllBookingsModal()">&times;</button>
      </div>
      <div style="margin-bottom:12px; display:flex; justify-content:space-between; align-items:center;">
        <span style="font-size:13px; color:var(--text-muted);">Manage, modify, or delete any booking across all dates:</span>
        <button class="action-btn btn-outline-danger btn-xs" onclick="confirmResetAll()">Clear All Bookings</button>
      </div>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Customer</th>
              <th>Date</th>
              <th>Slot</th>
              <th>Amount</th>
              <th>Status</th>
              <th style="text-align:right">Actions</th>
            </tr>
          </thead>
          <tbody id="allBookingsTableBody">
            <!-- Populated via JS -->
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <script>
    const today = new Date().toISOString().split('T')[0];
    const checkDateInput = document.getElementById('checkDateInput');
    const eventDateInput = document.getElementById('eventDate');
    const slotSelect = document.getElementById('slotSelect');
    checkDateInput.value = today;
    eventDateInput.value = today;

    // Load monthly analytics
    async function loadMonthlyAnalytics(dateStr) {
      try {
        const d = new Date(dateStr);
        const y = d.getFullYear();
        const m = d.getMonth() + 1;
        const res = await fetch(`/api/analytics/monthly?year=${y}&month=${m}`);
        const data = await res.json();
        if (res.ok) {
          document.getElementById('totalBookingsVal').textContent = data.total_bookings;
          document.getElementById('totalRevenueVal').textContent = '₹' + data.total_revenue.toLocaleString('en-IN');
          document.getElementById('abvVal').textContent = '₹' + Math.round(data.average_booking_value).toLocaleString('en-IN');
          document.getElementById('occupancyVal').textContent = data.occupancy_rate + '%';
          document.getElementById('bookingsSub').textContent = `Confirmed for ${data.month_name} ${data.year}`;
          document.getElementById('occupancySub').textContent = `${data.slots_occupied} of ${data.total_slots_capacity} slots booked`;
        }
      } catch (err) {
        console.error('Failed to load analytics', err);
      }
    }

    // Load availability for selected date
    async function checkAvailability(dateStr) {
      try {
        const res = await fetch(`/api/availability?date=${dateStr}`);
        const data = await res.json();
        const slotList = document.getElementById('slotListDisplay');
        const bookingsList = document.getElementById('dateBookingsList');
        slotList.innerHTML = '';
        bookingsList.innerHTML = '';

        if (!res.ok) {
          slotList.innerHTML = `<div style="color:var(--danger)">Error: ${data.message}</div>`;
          return;
        }

        const slots = ["Morning", "Evening", "Full Day"];
        slots.forEach(slot => {
          const isAvail = data.available_slots.includes(slot);
          const div = document.createElement('div');
          div.className = `slot-item ${isAvail ? 'slot-available' : 'slot-booked'}`;
          div.innerHTML = `
            <span>${isAvail ? '✓' : '✗'} ${slot} Slot</span>
            <span>${isAvail ? 'AVAILABLE' : 'BOOKED / UNAVAILABLE'}</span>
          `;
          slotList.appendChild(div);
        });

        // Update slot dropdown options in booking form if dates match
        if (eventDateInput.value === dateStr) {
          updateSlotDropdown(data.available_slots);
        }

        // List bookings with direct action buttons
        if (data.bookings && data.bookings.length > 0) {
          data.bookings.forEach(b => {
            const card = document.createElement('div');
            card.className = 'booking-card';
            const isCancelled = b.status === 'Cancelled';
            const statusColor = isCancelled ? '#ef4444' : '#10b981';
            const statusBg = isCancelled ? 'rgba(239,68,68,0.15)' : 'rgba(16,185,129,0.15)';

            card.innerHTML = `
              <div class="booking-card-top">
                <span style="font-weight:700; color:var(--primary-light)">
                  #${b.id} &bull; ${escapeHtml(b.customer_name)}
                </span>
                <div>
                  <span class="badge" style="background:rgba(201, 147, 59, 0.2); color:var(--primary-light); margin-right:4px;">${b.slot}</span>
                  <span class="badge" style="background:${statusBg}; color:${statusColor};">${b.status}</span>
                </div>
              </div>
              <div class="booking-card-sub">
                📞 ${escapeHtml(b.customer_phone)} &bull; Total: ₹${b.total_amount.toLocaleString('en-IN')} &bull; Advance: ₹${b.advance_paid.toLocaleString('en-IN')} &bull; Balance: ₹${b.balance_amount.toLocaleString('en-IN')}
              </div>
              <div class="card-actions">
                <button class="btn-xs btn-edit" onclick='openEditModal(${JSON.stringify(b)})'>
                  ✏️ Edit
                </button>
                ${isCancelled
                  ? `<button class="btn-xs btn-reopen" onclick="updateBookingStatus(${b.id}, 'Confirmed')">✓ Reconfirm</button>`
                  : `<button class="btn-xs btn-cancel" onclick="updateBookingStatus(${b.id}, 'Cancelled')">🚫 Cancel</button>`
                }
                <button class="btn-xs btn-del" onclick="deleteBooking(${b.id}, '${escapeHtml(b.customer_name)}')">
                  🗑️ Delete
                </button>
              </div>
            `;
            bookingsList.appendChild(card);
          });
        } else {
          bookingsList.innerHTML = `<div style="color: var(--text-muted); font-size: 13px; text-align: center; padding: 20px;">No bookings recorded for ${dateStr}. All slots available.</div>`;
        }
      } catch (err) {
        console.error('Failed to check availability', err);
      }
    }

    function updateSlotDropdown(availableSlots) {
      slotSelect.innerHTML = '<option value="">Select available slot...</option>';
      if (availableSlots.length === 0) {
        slotSelect.innerHTML = '<option value="">(No slots available for this date)</option>';
        return;
      }
      availableSlots.forEach(slot => {
        const opt = document.createElement('option');
        opt.value = slot;
        opt.textContent = `${slot} Slot`;
        slotSelect.appendChild(opt);
      });
    }

    // Direct Action: Delete Booking
    async function deleteBooking(id, name) {
      if (!confirm(`Are you sure you want to permanently delete booking #${id} (${name})?`)) return;
      try {
        const res = await fetch(`/api/bookings/${id}`, { method: 'DELETE' });
        const data = await res.json();
        if (res.ok) {
          showToast(`✓ Booking #${id} deleted.`);
          refreshAll();
        } else {
          showToast(`✗ ${data.message}`, true);
        }
      } catch (_) {
        showToast('✗ Network error', true);
      }
    }

    // Direct Action: Update Status (e.g. Cancel)
    async function updateBookingStatus(id, newStatus) {
      try {
        const res = await fetch(`/api/bookings/${id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: newStatus })
        });
        const data = await res.json();
        if (res.ok) {
          showToast(`✓ Booking #${id} status changed to ${newStatus}. Slots updated!`);
          refreshAll();
        } else {
          showToast(`✗ ${data.message}`, true);
        }
      } catch (_) {
        showToast('✗ Network error', true);
      }
    }

    // Direct Action: Clear All Bookings
    async function confirmResetAll() {
      if (!confirm('⚠️ Are you sure you want to CLEAR ALL bookings? This will reset the system to 0 bookings and an empty calendar!')) return;
      try {
        const res = await fetch('/api/bookings/reset', { method: 'POST' });
        const data = await res.json();
        if (res.ok) {
          showToast('✓ All bookings cleared! Database is now empty.');
          closeAllBookingsModal();
          refreshAll();
        } else {
          showToast(`✗ ${data.message}`, true);
        }
      } catch (_) {
        showToast('✗ Network error', true);
      }
    }

    // Direct Action: Load Sample Demo Data
    async function loadSampleData() {
      if (!confirm('Load sample bookings for testing? This will replace current bookings with demo wedding/event records.')) return;
      try {
        const res = await fetch('/api/bookings/seed', { method: 'POST' });
        const data = await res.json();
        if (res.ok) {
          showToast('✓ Sample bookings loaded.');
          refreshAll();
        } else {
          showToast(`✗ ${data.message}`, true);
        }
      } catch (_) {
        showToast('✗ Network error', true);
      }
    }

    // Edit Modal Logic
    function openEditModal(booking) {
      document.getElementById('editBookingId').value = booking.id;
      document.getElementById('editCustName').value = booking.customer_name;
      document.getElementById('editCustPhone').value = booking.customer_phone;
      document.getElementById('editEventDate').value = booking.event_date;
      document.getElementById('editSlotSelect').value = booking.slot;
      document.getElementById('editTotalAmt').value = booking.total_amount;
      document.getElementById('editAdvanceAmt').value = booking.advance_paid;
      document.getElementById('editStatusSelect').value = booking.status;
      document.getElementById('editModalTitle').textContent = `✏️ Modify Booking #${booking.id}`;
      document.getElementById('editModal').style.display = 'flex';
    }

    function closeEditModal() {
      document.getElementById('editModal').style.display = 'none';
    }

    document.getElementById('editForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const id = document.getElementById('editBookingId').value;
      const payload = {
        customer_name: document.getElementById('editCustName').value,
        customer_phone: document.getElementById('editCustPhone').value,
        event_date: document.getElementById('editEventDate').value,
        slot: document.getElementById('editSlotSelect').value,
        total_amount: parseFloat(document.getElementById('editTotalAmt').value),
        advance_paid: parseFloat(document.getElementById('editAdvanceAmt').value),
        status: document.getElementById('editStatusSelect').value
      };

      try {
        const res = await fetch(`/api/bookings/${id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (res.ok) {
          closeEditModal();
          showToast(`✓ Booking #${id} updated successfully!`);
          refreshAll();
        } else {
          alert(`Error: ${data.message}`);
        }
      } catch (_) {
        alert('Network error updating booking.');
      }
    });

    // All Bookings Modal Logic
    async function openAllBookingsModal() {
      const modal = document.getElementById('allBookingsModal');
      const tbody = document.getElementById('allBookingsTableBody');
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:20px;">Loading bookings...</td></tr>';
      modal.style.display = 'flex';

      try {
        const res = await fetch('/api/bookings');
        const data = await res.json();
        tbody.innerHTML = '';

        if (!data.bookings || data.bookings.length === 0) {
          tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:20px; color:var(--text-muted);">No bookings recorded in system.</td></tr>';
          return;
        }

        data.bookings.forEach(b => {
          const tr = document.createElement('tr');
          const isCancelled = b.status === 'Cancelled';
          tr.innerHTML = `
            <td>#${b.id}</td>
            <td><strong>${escapeHtml(b.customer_name)}</strong><br><small style="color:var(--text-muted)">${escapeHtml(b.customer_phone)}</small></td>
            <td>${b.event_date}</td>
            <td><span class="badge" style="background:rgba(201,147,59,0.15); color:var(--primary-light)">${b.slot}</span></td>
            <td>₹${b.total_amount.toLocaleString('en-IN')}<br><small style="color:var(--text-muted)">Adv: ₹${b.advance_paid.toLocaleString('en-IN')}</small></td>
            <td><span class="badge" style="background:${isCancelled ? 'rgba(239,68,68,0.15)' : 'rgba(16,185,129,0.15)'}; color:${isCancelled ? '#f87171' : '#34d399'}">${b.status}</span></td>
            <td style="text-align:right">
              <button class="btn-xs btn-edit" onclick='closeAllBookingsModal(); openEditModal(${JSON.stringify(b)})'>Edit</button>
              ${isCancelled
                ? `<button class="btn-xs btn-reopen" onclick="updateBookingStatus(${b.id}, 'Confirmed'); openAllBookingsModal();">Reopen</button>`
                : `<button class="btn-xs btn-cancel" onclick="updateBookingStatus(${b.id}, 'Cancelled'); openAllBookingsModal();">Cancel</button>`
              }
              <button class="btn-xs btn-del" onclick="deleteBooking(${b.id}, '${escapeHtml(b.customer_name)}'); openAllBookingsModal();">Delete</button>
            </td>
          `;
          tbody.appendChild(tr);
        });
      } catch (_) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding:20px; color:var(--danger);">Failed to load bookings.</td></tr>';
      }
    }

    function closeAllBookingsModal() {
      document.getElementById('allBookingsModal').style.display = 'none';
    }

    function refreshAll() {
      checkAvailability(checkDateInput.value);
      loadMonthlyAnalytics(checkDateInput.value);
    }

    function showToast(msg, isErr = false) {
      const toast = document.getElementById('toastBox');
      toast.className = isErr ? 'toast toast-error' : 'toast toast-success';
      toast.textContent = msg;
      toast.style.display = 'block';
      setTimeout(() => { toast.style.display = 'none'; }, 4500);
    }

    function escapeHtml(str) {
      if (!str) return '';
      return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    // Event listeners
    checkDateInput.addEventListener('change', () => {
      checkAvailability(checkDateInput.value);
      loadMonthlyAnalytics(checkDateInput.value);
    });

    eventDateInput.addEventListener('change', async () => {
      const res = await fetch(`/api/availability?date=${eventDateInput.value}`);
      const data = await res.json();
      if (res.ok) updateSlotDropdown(data.available_slots);
    });

    // Form submit
    document.getElementById('bookingForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const toast = document.getElementById('toastBox');
      toast.style.display = 'none';

      const payload = {
        customer_name: document.getElementById('custName').value,
        customer_phone: document.getElementById('custPhone').value,
        event_date: eventDateInput.value,
        slot: slotSelect.value,
        total_amount: parseFloat(document.getElementById('totalAmt').value),
        advance_paid: parseFloat(document.getElementById('advanceAmt').value),
        status: "Confirmed"
      };

      try {
        const res = await fetch('/api/bookings', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();

        if (res.ok) {
          showToast(`✓ Booking Confirmed! ID: #${data.booking_id} for ${data.booking.customer_name}`);
          // Clear inputs
          document.getElementById('custName').value = '';
          document.getElementById('custPhone').value = '';
          document.getElementById('totalAmt').value = '';
          document.getElementById('advanceAmt').value = '';
          
          // Refresh views
          checkAvailability(checkDateInput.value);
          loadMonthlyAnalytics(eventDateInput.value);
        } else {
          showToast(`✗ ${data.message || 'Failed to create booking'}`, true);
        }
      } catch (err) {
        showToast('✗ Network error connecting to backend.', true);
      }
    });

    // Initial load
    checkAvailability(today);
    loadMonthlyAnalytics(today);
  </script>
</body>
</html>
"""

@app.route('/', methods=['GET'])
def index():
    """Serves the interactive web console."""
    return render_template_string(HTML_TEMPLATE)


# ==========================================
# CLI / Entry point
# ==========================================
def init_db():
    with app.app_context():
        try:
            db.create_all()
        except Exception:
            pass


if __name__ == '__main__':
    init_db()
    port = int(os.environ.get('PORT', 5000))
    print(f"Starting Banquet Hall Management Server on http://0.0.0.0:{port}")
    app.run(host='0.0.0.0', port=port, debug=True)
