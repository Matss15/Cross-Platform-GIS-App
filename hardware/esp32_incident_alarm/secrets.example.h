// Copy this file to secrets.h (same folder) and fill in your values.
// secrets.h is git-ignored so the passwords never get committed.
#pragma once

// Wi-Fi is chosen from a phone through the setup hotspot (see the sketch
// header), so no network name goes here. 2.4 GHz networks only.
// Password for the setup hotspot itself, at least 8 characters:
#define SETUP_AP_PASSWORD "change-this-setup-password"

// From lib/firebase_options.dart (web apiKey / projectId).
#define FIREBASE_API_KEY "AIzaSyCtrsnxhrVO5uEjNSWTH8StaMI9s0x_lIQ"
#define FIREBASE_PROJECT_ID "gis-cross-platform"

// A dedicated BFP Personnel account created from the admin panel.
// Firestore only lets barangay/BFP/admin roles read every incident.
#define DEVICE_EMAIL "alarm-device@example.com"
#define DEVICE_PASSWORD "device-account-password"
