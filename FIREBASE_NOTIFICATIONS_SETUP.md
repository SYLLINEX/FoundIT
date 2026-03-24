# Firebase Notifications Setup (FoundIT)

This app now uses Firestore-backed in-app notifications and true push notifications via FCM.

## 1) Firestore collections used

### `notifications`
Each document:
- `user_id` (string)
- `title` (string)
- `body` (string)
- `type` (string): `report_approved`, `nearby_report`, `report_found`, `report_reserved`, `general`
- `is_read` (bool)
- `created_at` (timestamp)
- `related_item_id` (string, optional)
- `data` (map, optional)

### `items` (already used)
The flow now expects these statuses:
- `Pending for Approval`
- `Open`
- `Reserved`
- `Resolved`

## 2) Required Firestore indexes

Create these indexes in Firebase Console -> Firestore Database -> Indexes:

1. Collection: `notifications`
- Fields:
  - `user_id` Asc
  - `created_at` Desc

2. Collection: `notifications`
- Fields:
  - `user_id` Asc
  - `is_read` Asc

If Firebase gives an index link during runtime, you can also create directly from that link.

## 3) Suggested Firestore rules

Use/merge these rules so users can only read their own notifications:

```txt
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /notifications/{notificationId} {
      allow read: if request.auth != null && request.auth.uid == resource.data.user_id;
      allow update: if request.auth != null
        && request.auth.uid == resource.data.user_id
        && request.resource.data.diff(resource.data).changedKeys().hasOnly(['is_read']);
      allow create, delete: if false;
    }
  }
}
```

Note:
- The app currently creates notifications from trusted app flows (admin/user actions). For production, move notification creation to Cloud Functions for stronger security.

## 4) True push notifications (already wired in code)

Already implemented:
- Flutter token registration and refresh handling in `lib/services/push_notification_service.dart`
- Startup initialization in `lib/main.dart`
- Cloud Function trigger in `functions/index.js`

Do this once on your machine:

1. Install function dependencies:
```bash
cd functions
npm install
cd ..
```

2. Deploy Cloud Functions:
```bash
firebase deploy --only functions
```

3. Android: notifications runtime permission is already added in manifest.

4. iOS (required for real push on Apple devices):
- In Apple Developer account, create an APNs Auth Key (.p8)
- In Firebase Console -> Project Settings -> Cloud Messaging, upload APNs key
- In Xcode Runner target, ensure Push Notifications capability is enabled
- Ensure Background Modes includes Remote notifications

## 5) Admin flow summary

- New report from user: status `Pending for Approval`
- Admin approves: status `Open`
- On approval:
  - Owner gets `report_approved`
  - Nearby users (500m) with opposite-type open reports get `nearby_report`
- Claim submitted: owner gets `report_found`
- Claim approved by admin: item becomes `Reserved`
  - Owner gets `report_found` and `report_reserved`
  - Claimant gets `report_reserved`

## 6) Important production note

For strict security and consistency, move notification writes from client-side to Cloud Functions using Firestore triggers and callable functions.
