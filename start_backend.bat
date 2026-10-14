@echo off
title Muskan Palace Backend Server
color 0E
echo ===================================================
echo     MUSKAN PALACE - BANQUET HALL BACKEND API       
echo ===================================================
echo Starting Flask server on http://0.0.0.0:5000 ...
echo [TIP] Keep this window open while using the mobile app!
echo To run 24/7 even with laptop shut down, see CLOUD_HOSTING_GUIDE.md
echo ===================================================
cd /d "%~dp0"
python app.py
pause
