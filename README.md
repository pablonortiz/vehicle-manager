# Gestor de Vehiculos

Cross-platform app for comprehensive vehicle fleet management. Built with Flutter, it runs on Android, iOS, Web, macOS, Linux, and Windows.

\![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
\![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
\![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)

## Features

### Vehicle Management
- **Full CRUD** with detailed vehicle information
- **Supported types:** Car, Pickup, Truck, Motorcycle
- **Vehicle data:** License plate, make, model, year, color, mileage
- **Inspection & Insurance:** Expiration dates with visual alerts
- **Location:** Province and city
- **Status:** Available, In use, Under maintenance, Out of service

### Photo Gallery
- Multiple photos per vehicle
- Main photo selection
- Upload from camera or gallery
- Multiple photo selection
- Cloudinary storage

### Maintenance
- Unlimited maintenance records per vehicle
- Required date with calendar picker
- Extensive detail field
- **Attachments:** PDFs and/or invoice photos
- Full-screen attachment viewer

### Notes
- Multiple notes per vehicle
- Extensive detail field
- Optional attached photos
- Full-screen photo viewer

### Documentation
- Sections for vehicle registration documents
- Multiple photos per document
- Full-screen viewer

### Responsible Person
- Name and phone of the vehicle's responsible person
- **Import from contacts** (mobile only)
- One-tap direct call
- One-tap WhatsApp message

### Change History
- Automatic logging of all changes
- Chronological view
- Details of modified field, old value, and new value

### Sync
- **Offline mode:** Work without connection
- **Local cache:** SQLite database on mobile
- **Pull-to-refresh:** Manual sync
- **Auto sync:** When connection is restored

### PDF Export
- Export complete vehicle data to a professional PDF
- Includes vehicle details, photos, documentation, and maintenance records
- Separate title page for each section
- Full-page images for better viewing
- Dark design matching the app theme
- Share or save the generated PDF

## Tech Stack

| Technology | Purpose |
|---|---|
| **Flutter** | Cross-platform UI framework |
| **Riverpod** | State management |
| **GoRouter** | Declarative navigation |
| **Supabase** | Backend (PostgreSQL + Auth + Storage) |
| **SQLite** | Local cache (mobile) |
| **Cloudinary** | Image storage |
| **PDF/Printing** | PDF generation |

## Installation

### Prerequisites

- Flutter SDK 3.x
- [Supabase](https://supabase.com) account
- [Cloudinary](https://cloudinary.com) account

### 1. Clone the repository

```bash
git clone https://github.com/pablonortiz/gestor-de-vehiculos.git
cd gestor-de-vehiculos
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure environment variables

Create a `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_UPLOAD_PRESET=your-upload-preset
```

> **Important:** The `.env` file is in `.gitignore` and is NOT committed to the repository.

### 4. Configure Supabase

Run the SQL script in your Supabase project:

```bash
# The file is in the project root
supabase_schema.sql
```

Or copy the contents and run them in the Supabase SQL Editor.

### 5. Configure Cloudinary

1. Create an account at [Cloudinary](https://cloudinary.com)
2. Go to Settings > Upload
3. Create an **Upload Preset** with "Unsigned" mode
4. Copy the preset name to `.env`

## Run

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Desktop
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

## Build

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web
```

## Project Structure

```
lib/
├── core/
│   ├── config/          # Configuration (Supabase, Cloudinary)
│   ├── constants/       # Constants (vehicle types, provinces)
│   ├── theme/           # App theme
│   └── utils/           # Utilities
├── data/
│   ├── database/        # SQLite helper
│   ├── repositories/    # Data repositories
│   └── services/        # Services (sync, cloudinary)
├── domain/
│   └── models/          # Domain models
├── presentation/
│   ├── providers/       # Riverpod providers
│   ├── screens/         # Screens
│   └── widgets/         # Reusable widgets
└── main.dart
```

## Database Schema

| Table | Description |
|---|---|
| `vehicles` | Vehicle data |
| `vehicle_history` | Change history |
| `vehicle_photos` | Photo gallery |
| `maintenances` | Maintenance records |
| `maintenance_invoices` | Attached invoices |
| `vehicle_notes` | Vehicle notes |
| `note_photos` | Note photos |
| `document_photos` | Documentation photos |

## Security

- Credentials stored in `.env` (not committed)
- Row Level Security (RLS) enabled in Supabase
- Data validation on client and server

## Web vs Mobile Differences

| Feature | Mobile | Web |
|---|---|---|
| Local cache | SQLite | Supabase only |
| Import contacts | Yes | No |
| Camera | Yes | Browser-dependent |
| Gallery | Yes | File picker |
| Offline mode | Yes | No |

## License

MIT
