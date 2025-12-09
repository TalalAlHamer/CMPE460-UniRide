# UniRide

A production-ready Flutter ride-sharing application designed for university students to offer and find rides efficiently. Built with Firebase backend, real-time messaging, and comprehensive safety features.

[![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-Academic-green.svg)](LICENSE)

---

## Features

### Driver Features
- **Ride Management**: Post rides with destination, time, available seats, and price
- **Request Handling**: View, accept, or decline passenger requests in real-time
- **Vehicle Management**: Add, edit, and manage multiple vehicles
- **Smart Notifications**: Receive instant notifications for new requests and cancellations
- **Rating System**: Rate passengers after completed rides
- **Transaction Safety**: Race-condition-free seat management with Firestore transactions

### Passenger Features
- **Advanced Search**: Find rides with filters for date, time range, seats, and distance
- **Map Integration**: Interactive map picker for precise pickup locations
- **Request Management**: Request rides with rate limiting to prevent spam
- **Smart Cancellation**: Cancel requests with automatic seat restoration
- **Real-time Chat**: Communicate with drivers before and during the ride
- **Rating System**: Rate drivers after completed rides
- **Notifications**: Stay updated on request status (accepted/declined)

### System Features
- **Authentication**: Secure Firebase Authentication with email/password
- **Real-time Updates**: Live data synchronization using Cloud Firestore
- **Push Notifications**: Firebase Cloud Messaging for all user interactions
- **Google Maps**: Location picking, distance calculation, and route visualization
- **Input Validation**: Comprehensive sanitization and validation for all user inputs
- **Error Handling**: User-friendly error messages with proper error recovery
- **Rate Limiting**: Prevent spam with intelligent debouncing (3s for requests, 1s for messages)
- **Memory Management**: Proper disposal of controllers and listeners to prevent leaks
- **Null Safety**: Complete null-safe implementation throughout the codebase

---

## Tech Stack

### Frontend
- **Flutter** (3.10+) - Cross-platform UI framework
- **Dart** (3.10+) - Programming language
- **Google Maps Flutter** (^2.5.1) - Interactive maps and location services
- **Geolocator** (^14.0.2) - GPS and location permissions

### Backend
- **Firebase Core** (^4.2.1) - Firebase SDK initialization
- **Firebase Authentication** (^6.1.2) - User authentication and authorization
- **Cloud Firestore** (^6.1.0) - NoSQL real-time database
- **Cloud Functions** (^6.0.4) - Serverless backend logic
- **Firebase Cloud Messaging** (^16.0.4) - Push notifications

### Additional Libraries
- **Flutter Local Notifications** (^18.0.1) - Local notification handling
- **HTTP** (^1.2.0) - REST API requests for Google Places
- **Intl** (^0.20.2) - Date/time formatting and internationalization

### Development Tools
- **Flutter Test** - Unit and widget testing framework
- **Flutter Lints** (^6.0.0) - Code quality and style enforcement
- **Widgetbook** (^3.8.0) - Component library and UI development

---

## Getting Started

### Prerequisites
- Flutter SDK 3.10 or higher
- Dart 3.0 or higher
- Android Studio / Xcode (for mobile development)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/TalalAlHamer/CMPE460-UniRide.git
   cd CMPE460-UniRide
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify Installation**

Check that Flutter is properly installed and there are no issues:

```bash
flutter doctor
```

Fix any issues reported by Flutter Doctor before proceeding.

The app is now ready to run. All Firebase configuration is already included in the repository.

## Firebase Configuration

Firebase is already configured and ready to use. The project includes all necessary Firebase configuration files:

- ✅ `android/app/google-services.json` - Android Firebase configuration
- ✅ `ios/Runner/GoogleService-Info.plist` - iOS Firebase configuration  
- ✅ `lib/firebase_options.dart` - Flutter Firebase options
- ✅ `functions/` - Cloud Functions for secure API access

The app is connected to a live Firebase project with:
- **Authentication** - Email/password sign-in enabled
- **Firestore Database** - Real-time database configured with security rules
- **Cloud Messaging** - Push notifications enabled
- **Cloud Functions** - Serverless functions for Google Places API

## Running the App

### Run on Android Emulator/Device

1. Start an Android emulator or connect a physical device
2. Run the app:
   ```bash
   flutter run
   ```

### Run on iOS Simulator/Device

1. Open iOS Simulator or connect a physical iOS device
2. Run the app:
   ```bash
   flutter run
   ```

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/
│   ├── chat_room.dart        # Chat room data model
│   ├── message.dart          # Message data model
│   ├── ride.dart             # Ride data model
│   └── user_model.dart       # User data model
├── screens/
│   ├── chat_list_screen.dart              # Chat list view
│   ├── chat_screen.dart                   # Individual chat view
│   ├── driver_create_vehicle_screen.dart  # Vehicle creation
│   ├── driver_offer_ride_screen.dart      # Ride creation
│   ├── driver_profile_screen.dart         # Driver profile
│   ├── driver_ride_details_screen.dart    # Driver ride details
│   ├── driver_ride_published_confirmation_screen.dart
│   ├── driver_vehicles_screen.dart        # Vehicle management
│   ├── home_screen.dart                   # Main home screen
│   ├── incoming_ride_requests_screen.dart # Request management
│   ├── login_screen.dart                  # Authentication
│   ├── my_rides_screen.dart               # Ride history
│   ├── notifications_screen.dart          # Notifications center
│   ├── passenger_find_ride_screen.dart    # Ride search
│   ├── passenger_request_confirmation_screen.dart
│   ├── passenger_ride_details_screen.dart # Passenger ride details
│   ├── profile_screen.dart                # User profile
│   ├── rating_screen.dart                 # Rating system
│   ├── register_screen.dart               # User registration
│   ├── RideRequestsScreen.dart            # Ride requests
│   ├── rides_screen.dart                  # Rides overview
│   └── widgets/
│       └── bottom_nav.dart                # Bottom navigation
└── services/
    ├── auth_service.dart          # Authentication logic
    ├── chat_service.dart          # Chat functionality
    ├── notification_service.dart  # Push notifications
    ├── rating_service.dart        # Rating system
    ├── ride_cleanup_service.dart  # Expired ride cleanup
    ├── ride_service.dart          # Ride management
    └── secure_places_service.dart # Google Places API

test/
├── all_scenarios_manual_test.dart # Manual test scenarios
├── complete_flow_test.dart        # End-to-end flow tests
├── integration_tests.dart         # Integration test suite
├── simulation_test.dart           # Simulation tests
└── widget_test.dart               # Widget tests

functions/
└── index.js                   # Cloud Functions (Google Places proxy)
```

---

## Testing

The project includes a comprehensive test suite with multiple test files covering various scenarios.

### Run All Tests

```bash
flutter test
```

### Test Files

- **integration_tests.dart**: Comprehensive integration tests including:
  - Seat bounds validation (1-10 seats)
  - Price bounds validation (BD 1-500)
  - Date/time validation
  - Input sanitization
  - Ride filtering logic
  - Transaction safety tests
  
- **complete_flow_test.dart**: End-to-end user flow testing
- **simulation_test.dart**: Scenario-based simulation tests
- **widget_test.dart**: Basic widget functionality tests

### Test Statistics
- **Total Tests**: 50+ comprehensive test cases
- **Source Code**: ~12,744 lines
- **Test Code**: ~3,067 lines
- **Coverage Areas**: Authentication, validation, ride logic, transactions, UI components

---

## Architecture

### Design Patterns
- **Service Layer Pattern**: Separation of business logic into dedicated service classes
- **Repository Pattern**: Data access abstraction through Firestore
- **Singleton Pattern**: Service instances for Firebase and Firestore

### Key Architectural Decisions
1. **Transaction-based Seat Management**: Prevents race conditions when multiple passengers request the same ride
2. **Rate Limiting**: Debouncing for requests (3s) and messages (1s) prevents spam
3. **Atomic Operations**: Chat messages and notifications committed together for consistency
4. **Memory Management**: Proper disposal of controllers, focus nodes, and stream subscriptions
5. **Input Sanitization**: All user inputs validated and sanitized before processing
6. **Error Recovery**: User-friendly error messages with proper fallback handling

---

## Code Quality

### Current Status
- **Compilation Errors**: 0
- **Test Pass Rate**: 100%
- **Null Safety**: Complete
- **Total Lines of Code**: ~15,811
  - Source Code: ~12,744 lines
  - Test Code: ~3,067 lines

### Quality Features
- Comprehensive null safety checks
- Transaction-safe concurrent operations
- Proper async/await patterns
- Memory leak prevention
- Input validation and sanitization
- User-friendly error messages
- Extensive test coverage

---

## Roadmap

Future enhancements planned:

- [ ] Advanced ride filtering (price range, vehicle type, ratings)
- [ ] Ride history and detailed receipts
- [ ] Multi-stop routes support
- [ ] In-app payment integration
- [ ] Admin dashboard for monitoring
- [ ] Enhanced chat with media sharing and read receipts
- [ ] Ride scheduling for recurring trips
- [ ] Carbon footprint tracking
- [ ] Driver earnings dashboard

---

## License

This project is developed as part of **CMPE460** coursework at the American University of Bahrain (AUBH) and is intended for academic purposes only.

---

## Acknowledgments

- American University of Bahrain - CMPE460 Course
- Flutter and Firebase teams for excellent documentation
- Google Maps Platform for location services
- Open source community for various packages used