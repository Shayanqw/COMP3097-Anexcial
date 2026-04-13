# Anexcial iOS

Native iOS app for Anexcial loyalty (SwiftUI, iOS 16+). Same features and dark UI as the web app.

## Requirements

- Xcode 15+ (or 14 with iOS 16 SDK)
- Backend API running (Django project with `/api/` endpoints)

## Open in Xcode

1. Open `Anexcial.xcodeproj` in Xcode.
2. Select the Anexcial scheme and a simulator or device.
3. Build and run (Cmd+R).

## Backend URL

- **Default:** `http://127.0.0.1:8000/api/` (local Django with `python manage.py runserver`).
- **Override:** Add to the app target’s Info tab (or `Info.plist`): key `ANEXCIAL_API_URL`, value e.g. `https://your-server.com/api/`.
- For simulator to reach your Mac’s Django: use your Mac’s LAN IP (e.g. `http://192.168.1.x:8000/api/`) and ensure the Django server is bound to `0.0.0.0` (`runserver 0.0.0.0:8000`).

## Run backend first

```bash
cd /path/to/Anexcial-2
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Then run the iOS app and sign in or sign up (Member with invite code, or Store).

## Features

- **Member:** Store cards with points and rewards, store detail and history, redeem reward, My QR (show at store to earn points), profile and logout.
- **Store:** Dashboard (KPIs, items, onboarding status), Scan (camera QR + member lookup, award points, redeem points), Invites (create codes), Items (add/edit), Onboarding form, More (onboarding, logout).
- **Admin:** Onboarding review list, Approve/Reject.

UI uses the same dark theme as the web app (background `#17120f`, accent `#e0a458`).
