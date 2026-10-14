# Muskan Palace - Backend Setup & 24/7 Uptime Guide

## 1. Why does the app stop working when you shut down your laptop?

The **Muskan Palace** system consists of two parts:
1. **Frontend (Client)**: The mobile Flutter app running on your phone or emulator.
2. **Backend (Server & Database)**: The Python Flask API (`app.py`) and SQLite database (`banquet.db`).

Currently, the backend is running **locally on your laptop**.
- When you shut down your laptop, your computer powers off, which immediately terminates the Python Flask server (`app.py`).
- When the mobile app on your phone attempts to load analytics or slots, it cannot reach your laptop's IP address (`http://192.168.x.x:5000` or `http://10.0.2.2:5000`), resulting in the error:
  > **"Unable to Connect to Backend API"**

---

## 2. Permanent Fix: Free 24/7 Cloud Hosting (Recommended)

To make your mobile app work **24/7 anywhere, anytime** — even when your laptop is turned off, in sleep mode, or in your bag — you can host the Flask backend on a free cloud hosting service such as **Render.com** or **Railway.app**.

We have already configured:
- `Procfile` (`web: gunicorn app:app`)
- `render.yaml` (Render Blueprint)
- `requirements.txt` (includes `gunicorn`)

### Step-by-Step Instructions to Host on Render.com (100% Free):
1. Create a free account at [Render.com](https://render.com).
2. Push your `muskan palace` project folder to GitHub (private or public repo).
3. In your Render Dashboard, click **New +** -> **Web Service**.
4. Select your GitHub repository.
5. Render will automatically detect the settings:
   - **Environment**: Python
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `gunicorn app:app`
   - **Instance Type**: Free
6. Click **Create Web Service**.
7. In 1–2 minutes, Render will assign your backend a live public HTTPS address, for example:
   ```
   https://muskan-palace-api.onrender.com
   ```
8. **Connect your Mobile App**:
   - Open the **Muskan Palace** app on your phone.
   - Tap the **Settings (Gear)** icon in the top right corner of the Dashboard.
   - Enter your Render URL: `https://muskan-palace-api.onrender.com`
   - Tap **Save & Reconnect**.
   - Your app is now connected to the cloud and will work 24/7 without needing your laptop!

---

## 3. Alternative: Running Locally on Your Laptop

If you prefer to continue running the backend on your laptop:

### Method A: 1-Click Startup Script
- Double-click [`start_backend.bat`](file:///c:/Users/altu/Desktop/muskan%20palace/start_backend.bat) in this folder.
- Keep the terminal window open while using the mobile app.

### Method B: Start Automatically When Laptop Turns On
1. Press `Win + R` on your keyboard, type:
   ```
   shell:startup
   ```
   and press Enter. This opens your Windows Startup folder.
2. Right-click [`start_backend.bat`](file:///c:/Users/altu/Desktop/muskan%20palace/start_backend.bat), choose **Create shortcut**.
3. Move that shortcut into the `shell:startup` folder.
4. Now, whenever you boot your laptop, the backend server will start automatically in the background.

*(Note: While running locally, your laptop must remain powered on and connected to the same Wi-Fi network as your phone).*
