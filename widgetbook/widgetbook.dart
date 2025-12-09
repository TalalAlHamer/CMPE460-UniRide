import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uniride_app/firebase_options.dart';

// Import your screens
import 'package:uniride_app/screens/login_screen.dart';
import 'package:uniride_app/screens/register_screen.dart';
import 'package:uniride_app/screens/home_screen.dart';
import 'package:uniride_app/screens/profile_screen.dart';
import 'package:uniride_app/screens/passenger_find_ride_screen.dart';
import 'package:uniride_app/screens/driver_create_vehicle_screen.dart';
import 'package:uniride_app/screens/driver_offer_ride_screen.dart';
import 'package:uniride_app/screens/my_rides_screen.dart';
import 'package:uniride_app/screens/incoming_ride_requests_screen.dart';
import 'package:uniride_app/screens/driver_vehicles_screen.dart';
import 'package:uniride_app/screens/driver_ride_published_confirmation_screen.dart';
import 'package:uniride_app/screens/passenger_request_confirmation_screen.dart';

void main() {
  runApp(const WidgetbookApp());
}

class WidgetbookApp extends StatelessWidget {
  const WidgetbookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeFirebase(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Error initializing Firebase: ${snapshot.error}'),
              ),
            ),
          );
        }

        return _buildWidgetbook();
      },
    );
  }

  Future<void> _initializeFirebase() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  Widget _buildWidgetbook() {
    return Widgetbook.material(
      directories: [
        WidgetbookFolder(
          name: 'Authentication',
          children: [
            WidgetbookComponent(
              name: 'Login',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const LoginScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Register',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const RegisterScreen(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Main Screens',
          children: [
            WidgetbookComponent(
              name: 'Home',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const HomeScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Profile',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Ride Management',
          children: [
            WidgetbookComponent(
              name: 'Passenger Find Ride',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const PassengerFindRideScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Driver Offer Ride',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const DriverOfferRideScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'My Rides',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const MyRidesScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Driver Ride Requests',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const IncomingRideRequestsScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Driver Ride Published',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const DriverRidePublishedConfirmationScreen(
                    from: 'American University of Bahrain',
                    to: 'City Center Mall',
                    date: '5/12/2025',
                    time: '7:00 PM',
                    price: '6.0',
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Passenger Request Confirmation',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const PassengerRequestConfirmationScreen(
                    driverName: 'Ahmed Ali',
                    from: 'American University of Bahrain',
                    to: 'Riffa',
                    date: '5/12/2025',
                    time: '7:00 PM',
                    price: '6.0',
                    seats: '2',
                    carMake: 'Toyota',
                    carModel: 'Camry',
                    carColor: 'Silver',
                    licensePlate: 'ABC-123',
                  ),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Vehicle Management',
          children: [
            WidgetbookComponent(
              name: 'Driver Create Vehicle',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const DriverCreateVehicleScreen(),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Driver Vehicles',
              useCases: [
                WidgetbookUseCase(
                  name: 'Default',
                  builder: (context) => const DriverVehiclesScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      addons: [
        DeviceFrameAddon(
          devices: [
            Devices.ios.iPhone13,
            Devices.ios.iPhoneSE,
            Devices.android.samsungGalaxyS20,
          ],
        ),
        TextScaleAddon(
          min: 1.0,
          max: 2.0,
          initialScale: 1.0,
        ),
      ],
      appBuilder: (context, child) {
        return MaterialApp(
          home: child,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
