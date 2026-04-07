# TowerTrack — Offline Cell Tower Location App

A fully offline-capable Android app that detects your connected cellular tower and estimates your current area — even without internet. Works like a "Where is my train?" app using cell tower handover detection.

---

## Features

### Core (Fully Offline)
- **Cell tower detection** via Android `TelephonyManager` API
- Reads **MCC, MNC, LAC/TAC, Cell ID** from live network
- Supports **LTE (4G), NR (5G), WCDMA (3G), GSM (2G)**
- **Local SQLite database** mapping tower IDs → area names
- **Signal strength** display (dBm + bars)
- **Tower handover detection** — tracks when you move between cells
- **Journey log** showing your movement history

### Online Mode
- **Interactive map** (OpenStreetMap via flutter_map)
- Tower location pinned on map with animated marker
- History markers showing previous tower locations

### Train Mode ("Where Am I?")
- Animated train track UI showing your journey
- Station-stop timeline based on tower handovers
- Optimized for travel — detects movement automatically

---

## Architecture

```
TowerTrack/
├── android/
│   └── app/src/main/kotlin/com/celllocator/
│       └── MainActivity.kt          ← Native TelephonyManager integration
│
├── lib/
│   ├── main.dart                    ← App entry, 3-tab navigation
│   ├── models/
│   │   └── cell_info.dart           ← CellInfo, AreaMatch, data models
│   ├── services/
│   │   ├── telephony_service.dart   ← Flutter ↔ Android method/event channels
│   │   └── location_provider.dart  ← State management (Provider)
│   ├── database/
│   │   └── cell_database.dart      ← SQLite lookup + JSON seeding
│   └── screens/
│       ├── home_screen.dart         ← Tower info screen
│       ├── train_mode_screen.dart   ← "Where Am I?" offline screen
│       └── map_screen.dart          ← Online map screen
│
└── assets/
    ├── cell_database.json           ← ~50+ pre-mapped India areas (seed data)
    └── india_cells.json             ← LAC→city hint table
```

---

## How It Works

### 1. Native Android Layer (Kotlin)
```
MainActivity.kt
  └── MethodChannel: "com.celllocator/telephony"
       ├── getCellInfo()      → CellInfoLte / CellInfoNr / CellInfoGsm
       ├── getSignalStrength() → dBm, level (0-4)
       ├── getNetworkOperator() → name, MCC/MNC, roaming
       └── getAllCells()       → all visible cells (not just serving)
  └── EventChannel: "com.celllocator/tower_stream"
       └── Streams tower changes for handover detection
```

### 2. Database Lookup Strategy
```
Query → Exact Match (MCC+MNC+LAC+CID)
      → LAC Match (any CID in that area)
      → City Hint (LAC→city from hint table)
      → Unknown (show raw tower data)
```

### 3. Online/Offline Mode
- **Online**: OpenStreetMap tiles load, tower shown on map
- **Offline**: Map tiles cached or unavailable; cell-tower location still works perfectly

---

## Setup & Build

### Prerequisites
- Flutter 3.10+
- Android Studio with Android SDK 34
- Physical Android device (emulators don't have real cell radios)

### Steps

```bash
# 1. Clone / copy project
cd cell_locator

# 2. Install dependencies
flutter pub get

# 3. Connect Android device (USB debugging on)
adb devices

# 4. Run
flutter run

# 5. Build release APK
flutter build apk --release
# APK at: build/app/outputs/flutter-apk/app-release.apk
```

### Required Permissions
The app requests these at runtime:
- `READ_PHONE_STATE` — access cell tower IDs
- `ACCESS_FINE_LOCATION` — required on Android 9+ to read cell IDs
- `READ_PRECISE_PHONE_STATE` — Android 12+ for detailed cell info

---

## Adding More Tower Mappings

### Option A: Edit `assets/cell_database.json`
```json
{
  "areas": [
    {
      "mcc": 404, "mnc": 20, "lac": 11, "cid": 99999,
      "area": "My Area", "city": "My City", "state": "My State",
      "lat": 13.0827, "lon": 80.2707, "type": "urban"
    }
  ]
}
```
Reinstall the app after editing.

### Option B: In-App (Runtime)
When a tower is not found, tap **"Add to Database"** and enter the area name. It saves to SQLite immediately — no reinstall needed.

### Option C: Crowd-sourced databases
You can import from OpenCelliD (https://opencellid.org) CSV:
```python
# Convert OpenCelliD CSV to our JSON format
import csv, json

rows = []
with open('cell_towers.csv') as f:
    for row in csv.DictReader(f):
        if row['mcc'] == '404':  # India
            rows.append({
                "mcc": int(row['mcc']),
                "mnc": int(row['net']),
                "lac": int(row['area']),
                "cid": int(row['cell']),
                "area": f"Area {row['area']}-{row['cell']}",
                "city": "Unknown",
                "state": "India",
                "lat": float(row['lat']),
                "lon": float(row['lon'])
            })

print(json.dumps({"areas": rows[:5000]}, indent=2))
```

---

## Supported Networks

| Network | Type Field | Location Code | Cell ID |
|---------|-----------|---------------|---------|
| 4G LTE  | LTE        | TAC           | CI (28-bit) |
| 5G NR   | NR (5G)    | TAC           | NCI (36-bit) |
| 3G WCDMA| WCDMA (3G) | LAC           | CID |
| 2G GSM  | GSM (2G)   | LAC           | CID (16-bit) |

---

## Pre-loaded Database Coverage

### Tamil Nadu, India (priority coverage)
- Chennai: Central, Anna Nagar, T.Nagar, Adyar, Guindy, Tambaram, Chromepet, Velachery, Egmore, Mylapore, Perambur, OMR, Porur, Ambattur, Sholinganallur, Mogappair, Villivakkam, Korattur, Kodambakkam, Vadapalani, Nungambakkam
- Coimbatore, Madurai, Tiruchirappalli, Salem, Tirunelveli, Vellore

### Other Major Indian Cities
- Mumbai, Pune, Delhi, Gurugram, Bengaluru, Hyderabad, Kolkata, Ahmedabad, Jaipur, Lucknow, Kochi, Chandigarh

### Supported Operators
- Jio (405-840 to 405-846)
- Airtel (404-10, 404-30, 404-45, 404-49)
- Vi/Vodafone Idea (404-20, 404-22, 404-43)
- BSNL (404-07, 404-38, 404-44, 404-51, 404-58)

---

## Key Android APIs Used

```kotlin
// Get serving cell (Android 9+)
telephonyManager.allCellInfo  // List<CellInfo>

// Cell identity per type
(cellInfo as CellInfoLte).cellIdentity.ci   // Cell ID
(cellInfo as CellInfoLte).cellIdentity.tac  // Tracking Area Code
(cellInfo as CellInfoLte).cellIdentity.mccString
(cellInfo as CellInfoLte).cellIdentity.mncString

// Signal
(cellInfo as CellInfoLte).cellSignalStrength.rsrp  // dBm
(cellInfo as CellInfoLte).cellSignalStrength.level // 0-4

// Listen for changes (API 31+)
telephonyManager.registerTelephonyCallback(executor, callback)

// Legacy (API < 31)
telephonyManager.listen(listener, PhoneStateListener.LISTEN_CELL_INFO)
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No cell info available" | Ensure SIM is inserted; grant both permissions |
| Always shows "Unknown Area" | Tower not in DB; use "Add to Database" |
| Map tiles don't load | Normal when offline; switch to "Where Am I?" tab |
| Permissions denied loop | Go to Settings → Apps → TowerTrack → Permissions |
| App crashes on old Android | Minimum is Android 8 (API 26) |

---

## License
MIT — free to use, extend, and integrate into larger projects.
