# FoundIT

FoundIT is a comprehensive Lost and Found mobile application built with Flutter and Firebase. It aims to reunite people with their lost belongings by providing a seamless, intelligent, and secure platform. Users can report lost and found items, browse through listings on a map, verify claims, and securely communicate through end-to-end encrypted chats. The application also integrates on-device AI using TensorFlow Lite for automated image tagging and classification, simplifying the reporting process. 

##  Key Features (Functional Requirements)

1. **User Authentication & Profiles:** 
   - Secure login and registration using Firebase Authentication.
   - Google Sign-In integration.
   - User profile management.

2. **Reporting Items:** 
   - Report a "Lost" or "Found" item with images, description, and location.
   - **AI-Powered Image Recognition:** Automatically categorize item types from uploaded photos using an on-device TensorFlow Lite model (`mobilenet_v2`).

3. **Map & Location Services:** 
   - Interactive map interface (Google Maps) to display lost and found items based on their geographical coordinates.
   - Geolocation-based distance calculation and radius searching using `geoflutterfire_plus`.

4. **Secure In-App Messaging:**
   - Real-time chat functionality using Firestore.
   - **End-to-End Encryption:** Messages are encrypted locally on the device before transmission to ensure maximum privacy between users coordinating item returns.
   - Reply, reaction, and swipe-to-reply capabilities for a complete chat experience.
 
5. **Claims & Matching System:**
   - Users can securely file a claim for a found item.
   - Owners are notified of potential matches, ensuring a streamlined return process.

6. **Push Notifications:** 
   - Real-time alerts for new messages, nearby item matches, and claim updates via Firebase Cloud Messaging (FCM).

7. **Admin Dashboard & Moderation:** 
   - Admin capabilities to review reported items, handle inappropriate content, and manage user disputes.

## 🛠 Non-Functional Requirements (NFR)

1. **Performance & Responsiveness:** 
   - The app must load lists and maps quickly.
   - Images are optimized using cached networks (`cached_network_image`) and shimmer effects for a fluid UX, reducing bandwidth usage.

2. **Security & Privacy:** 
   - **Data Protection:** Firestore Security Rules and Firebase Storage Rules strictly govern data access paths to prevent unauthorized access.
   - **Chat Privacy:** Messages utilize symmetric encryption (`encrypt` and `crypto` algorithms), preventing anyone (including admins) from reading private communications.

3. **Scalability & Reliability:**
   - Hosted entirely on Firebase's scalable infrastructure, capable of adapting to a growing user base.
   - Offline capabilities through Firestore caching mechanisms where applicable.

4. **Usability & Aesthetics:** 
   - Modern, intuitive, and responsive UI utilizing `google_fonts`, custom animations (`flutter_spinkit`), and cohesive styling to ensure ease-of-use without a steep learning curve. The interface employs a feature-first approach to display complex logic simply.

##  Project Directory Structure

FoundIT follows a feature-centric modular architecture to ensure the codebase remains maintainable and scalable.

```text
lib/
├── core/                   # App-wide constants, global state, themes, and robust utilities.
├── features/               # Contains all UI-centric application features.
│   ├── admin/              # Admin dashboard and item moderation screens.
│   ├── auth/               # Login, registration, and password recovery workflows.
│   ├── chat/               # Inter-user messaging interfaces and controllers.
│   ├── claims/             # Logic and UI for making and resolving item claims.
│   ├── home/               # Main item feeds and navigation hub.
│   ├── map/                # Google Maps integration and localized search.
│   ├── notifications/      # In-app notification center.
│   ├── profile/            # User account settings and personal listings.
│   ├── report_item/        # Forms and logic for submitting new items (Lost/Found).
│   ├── reports/            # Global reporting functions and user feedback viewing.
│   └── splash/             # Application initialization and Splash Screen.
├── models/                 # Dart Data classes and models representing DB schemas.
├── services/               # Core business logic, backend connections, and 3rd party integrations.
│   ├── ai_service.dart               # High-level AI coordination.
│   ├── auth_service.dart             # Firebase Authentication logic.
│   ├── database_service.dart         # Firestore read/write operations.
│   ├── encryption_service.dart       # Cryptographic algorithms for E2E Encrypted Chats.
│   ├── location_service.dart         # Geolocator & Map APIs interactions.
│   ├── notification_service.dart     # Local and push notification dispatchers.
│   ├── push_notification_service.dart # FCM Token management and foreground messaging.
│   ├── storage_service.dart          # Firebase Storage uploads/downloads.
│   └── tflite_service.dart           # On-device image classification (MobileNet2).
├── widgets/                # Reusable, global UI components (Buttons, Dialogs, Cards).
├── firebase_options.dart   # Firebase configuration details (Auto-generated).
└── main.dart               # Application entry point.
```

## 🏗 System Architecture

FoundIT utilizes a robust cloud-based setup tightly coupled with a clean client architecture:

### 1. Client App Architecture
The Flutter frontend relies on a combination of decoupled **Services** (handling backend operations) and **Features** (handling UI and state). This is akin to a feature-first Domain-Driven Design approach. State management and injection allow the UI layer to seamlessly connect with Firebase without hardcoding backend queries directly in widget trees. This keeps the presentation logic entirely separate from database integration.

### 2. Backend Services (Firebase Ecosystem)
- **Cloud Firestore:** The NoSQL database stores user profiles, item metadata (location hashes via GeoFlutterFire), real-time chats, and active claims. 
- **Firebase Storage:** Accommodates high-resolution images submitted by users. Access is governed via customized Security Rules.
- **Firebase Authentication:** Single Sign-On (SSO) and native email/password handling.

### 3. Edge / On-Device Processing
- **TFLite AI Model:** In order to minimize server costs and maximize speed/privacy, image classification is executed directly on the user's hardware. Images are pre-processed and fed into `mobilenet_v2.tflite` via `tflite_service.dart` during the item submission flow.
- **Local Encryption Context:** Sensitive operations like chat encryption/decryption are processed locally. Only encrypted ciphertexts travel across the network.

##  Getting Started

### Prerequisites
- Flutter SDK (`^3.10.0`)
- Valid Firebase Project
- Google Maps API Key

### Setup
1. Clone the repository.
2. Run `flutter pub get` in the root directory to fetch all dependencies.
3. Configure your API keys inside your `.env` file (e.g., Maps API keys).
4. Run the app securely using `flutter run`.
