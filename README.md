<div align = "center">
   <img src="assets/images/foundit_logo.png" width="200">
</div>

# FoundIT

Reuniting people with what matters most.

FoundIT is an intelligent mobile ecosystem designed to bridge the gap between lost items and their owners. By combining Real-time Geospatial Mapping, On-device AI, and End-to-End Encrypted Messaging, we provide a secure and seamless recovery experience.

## Screenshots

*(Add screenshots here)*

## Core Innovation

### On-Device AI Intelligence

Unlike traditional platforms, FoundIT uses a localized TensorFlow Lite (MobileNet V2) model.

- **Privacy First:** Images are analyzed on-device; category metadata is extracted before the image even hits the cloud.
- **Smart Tagging:** Automatically suggests item categories (e.g., "Electronics", "Wallet", "Keys") to speed up the reporting process.

### Privacy & Security (E2EE)

Communication is the most sensitive part of item recovery.

- **End-to-End Encryption:** We use AES-256 symmetric encryption.
- **Zero-Knowledge:** Chat payloads are encrypted locally. Even as database admins, we cannot read the coordination details between users.

## Key Features

- **Seamless Auth:** Google SSO and Email/Password via Firebase.
- **Smart Mapping:** Interactive Google Maps integration with radius-based searching using `geoflutterfire_plus`.
- **Rich Messaging:** Real-time Firestore chats with replies, reactions, and swipe-to-reply.
- **Instant Alerts:** Push notifications for nearby matches and claim updates via FCM.
- **Moderation Suite:** Dedicated Admin Dashboard for dispute resolution and content filtering.

## Tech Stack

| Category | Technology |
| --- | --- |
| **Frontend** | Flutter, Google Fonts, Flutter Spinkit |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **Intelligence** | TensorFlow Lite (MobileNet V2) |
| **Security** | PointyCastle (AES), Firestore Security Rules |
| **Maps** | Google Maps API, GeoFlutterFire+ |

## Project Architecture

We follow a Feature-Driven Modular Architecture for maximum scalability.

```text
lib/
├── core/               # Global constants, themes, and shared utilities
├── features/           # UI-centric slices of the app
│   ├── auth/           # Onboarding & Authentication
│   ├── map/            # Geospatial discovery & Map logic
│   ├── chat/           # E2E Encrypted messaging system
│   └── report_item/    # AI-integrated submission forms
├── models/             # Type-safe data structures
├── services/           # The "Engine Room" (API & Logic)
│   ├── ai_service.dart      # AI Orchestration
│   ├── encryption_service.dart # Cryptographic logic
│   └── tflite_service.dart  # Low-level ML processing
└── widgets/            # Reusable UI components
```

## Installation & Setup

### Prerequisites

- Flutter SDK (^3.10.0)
- A Firebase Project with Firestore and Storage enabled.
- A Google Maps API Key.

### Steps

**Clone the Repo**

```bash
git clone https://github.com/yourusername/foundit.git
cd foundit
```

**Install Dependencies**

```bash
flutter pub get
```

**Configure Firebase**

- Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
- Run `flutterfire configure`.

**Environment Variables**

Create a `.env` file in the root directory:

```env
MAPS_API_KEY=your_key_here
```

**Launch**

```bash
flutter run
```

## Contribution

FoundIT is an open-source initiative. If you'd like to improve the AI model or security protocols:

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.
