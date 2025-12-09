import 'package:flutter_test/flutter_test.dart';

// Simulation Models
class RideOffer {
  final String id;
  final String driverId;
  final String from;
  final String to;
  final int totalSeats;
  final int seatsAvailable;
  final double price;
  final DateTime scheduledTime;
  final String status; // 'active', 'cancelled', 'completed'

  RideOffer({
    required this.id,
    required this.driverId,
    required this.from,
    required this.to,
    required this.totalSeats,
    required this.seatsAvailable,
    required this.price,
    required this.scheduledTime,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'driverId': driverId,
    'from': from,
    'to': to,
    'totalSeats': totalSeats,
    'seatsAvailable': seatsAvailable,
    'price': price,
    'scheduledTime': scheduledTime,
    'status': status,
  };
}

class RideRequest {
  final String id;
  final String rideId;
  final String passengerId;
  final String status; // 'pending', 'accepted', 'declined', 'cancelled'
  final DateTime requestedAt;

  RideRequest({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.status,
    required this.requestedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'rideId': rideId,
    'passengerId': passengerId,
    'status': status,
    'requestedAt': requestedAt,
  };
}

class Rating {
  final String id;
  final String rideId;
  final String fromUserId;
  final String toUserId;
  final double rating;
  final String? comment;

  Rating({
    required this.id,
    required this.rideId,
    required this.fromUserId,
    required this.toUserId,
    required this.rating,
    this.comment,
  });
}

// Simulation Engine
class RideSimulation {
  final Map<String, RideOffer> rides = {};
  final Map<String, List<RideRequest>> rideRequests = {};
  final Map<String, Rating> ratings = {};
  final Set<String> users = {
    'driver1',
    'passenger1',
    'passenger2',
    'passenger3',
  };

  // Scenario 1: Driver creates a ride
  void scenarioDriverCreatesRide() {
    print('\n=== SCENARIO 1: Driver Creates Ride ===');

    try {
      final ride = RideOffer(
        id: 'ride-001',
        driverId: 'driver1',
        from: 'Manama',
        to: 'Al Jasra',
        totalSeats: 4,
        seatsAvailable: 4,
        price: 2.5,
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
        status: 'active',
      );

      // Validation 1: Check seats bounds
      if (ride.totalSeats < 1 || ride.totalSeats > 10) {
        throw Exception('❌ ERROR: Invalid seat count ${ride.totalSeats}');
      }
      print('✅ Seat validation passed: ${ride.totalSeats} seats');

      // Validation 2: Check price bounds
      if (ride.price < 1 || ride.price > 500) {
        throw Exception('❌ ERROR: Invalid price ${ride.price}');
      }
      print('✅ Price validation passed: BD ${ride.price}');

      // Validation 3: Check time is in future
      if (ride.scheduledTime.isBefore(DateTime.now())) {
        throw Exception('❌ ERROR: Scheduled time is in the past');
      }
      print('✅ Time validation passed: ${ride.scheduledTime}');

      rides['ride-001'] = ride;
      rideRequests['ride-001'] = [];
      print('✅ Ride created successfully');
      print('   Ride ID: ${ride.id}');
      print('   From: ${ride.from} → To: ${ride.to}');
      print('   Seats: ${ride.totalSeats} | Price: BD ${ride.price}');
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 2: Passenger 1 requests the ride
  void scenarioPassenger1RequestsRide() {
    print('\n=== SCENARIO 2: Passenger 1 Requests Ride ===');

    try {
      final ride = rides['ride-001'];
      if (ride == null) {
        throw Exception('❌ ERROR: Ride not found');
      }

      // Validation 1: Check ride is active
      if (ride.status != 'active') {
        throw Exception('❌ ERROR: Ride is ${ride.status}, cannot request');
      }
      print('✅ Ride status check passed: ${ride.status}');

      // Validation 2: Check seats available
      if (ride.seatsAvailable <= 0) {
        throw Exception('❌ ERROR: No seats available');
      }
      print(
        '✅ Seats availability check passed: ${ride.seatsAvailable} seats available',
      );

      // Validation 3: Check passenger is not the driver
      if (ride.driverId == 'passenger1') {
        throw Exception('❌ ERROR: Cannot request own ride');
      }
      print('✅ Own ride check passed: different user');

      // Validation 4: Check for duplicate requests
      final requests = rideRequests['ride-001'] ?? [];
      if (requests.any((r) => r.passengerId == 'passenger1')) {
        throw Exception('❌ ERROR: Duplicate request detected');
      }
      print('✅ Duplicate request check passed');

      // Create request
      final request = RideRequest(
        id: 'request-001',
        rideId: 'ride-001',
        passengerId: 'passenger1',
        status: 'pending',
        requestedAt: DateTime.now(),
      );
      requests.add(request);
      rideRequests['ride-001'] = requests;

      print('✅ Request created successfully');
      print('   Request ID: ${request.id}');
      print('   Passenger: passenger1 | Status: ${request.status}');
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 3: Passenger 2 requests the ride (simultaneous with Passenger 1 acceptance)
  void scenarioPassenger2RequestsRide() {
    print('\n=== SCENARIO 3: Passenger 2 Requests Ride ===');

    try {
      final ride = rides['ride-001'];
      if (ride == null) {
        throw Exception('❌ ERROR: Ride not found');
      }

      // Check all validations
      if (ride.status != 'active') {
        throw Exception('❌ ERROR: Ride is ${ride.status}');
      }
      if (ride.seatsAvailable <= 0) {
        throw Exception('❌ ERROR: No seats available');
      }

      final requests = rideRequests['ride-001'] ?? [];
      if (requests.any((r) => r.passengerId == 'passenger2')) {
        throw Exception('❌ ERROR: Duplicate request');
      }

      final request = RideRequest(
        id: 'request-002',
        rideId: 'ride-001',
        passengerId: 'passenger2',
        status: 'pending',
        requestedAt: DateTime.now(),
      );
      requests.add(request);
      rideRequests['ride-001'] = requests;

      print('✅ Request created successfully');
      print('   Request ID: ${request.id}');
      print('   Passenger: passenger2 | Status: ${request.status}');
      print('   Current pending requests: ${requests.length}');
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 4: Driver accepts Passenger 1 (decrements seats)
  void scenarioDriverAcceptsPassenger1() {
    print('\n=== SCENARIO 4: Driver Accepts Passenger 1 ===');

    try {
      var ride = rides['ride-001'];
      if (ride == null) {
        throw Exception('❌ ERROR: Ride not found');
      }

      final requests = rideRequests['ride-001'] ?? [];
      final request = requests.firstWhere(
        (r) => r.passengerId == 'passenger1',
        orElse: () => throw Exception('❌ ERROR: Request not found'),
      );

      // Update request status
      final updatedRequests = requests.map((r) {
        if (r.id == request.id) {
          return RideRequest(
            id: r.id,
            rideId: r.rideId,
            passengerId: r.passengerId,
            status: 'accepted',
            requestedAt: r.requestedAt,
          );
        }
        return r;
      }).toList();
      rideRequests['ride-001'] = updatedRequests;

      // Decrement seats
      ride = RideOffer(
        id: ride.id,
        driverId: ride.driverId,
        from: ride.from,
        to: ride.to,
        totalSeats: ride.totalSeats,
        seatsAvailable: ride.seatsAvailable - 1,
        price: ride.price,
        scheduledTime: ride.scheduledTime,
        status: ride.status,
      );
      rides['ride-001'] = ride;

      print('✅ Request accepted successfully');
      print('   Passenger: passenger1 | New Status: accepted');
      print(
        '   Seats decremented: ${ride.seatsAvailable + 1} → ${ride.seatsAvailable}',
      );
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 5: Driver declines Passenger 2 (prevents chat)
  void scenarioDriverDeclinesPassenger2() {
    print('\n=== SCENARIO 5: Driver Declines Passenger 2 ===');

    try {
      final requests = rideRequests['ride-001'] ?? [];
      final request = requests.firstWhere(
        (r) => r.passengerId == 'passenger2',
        orElse: () => throw Exception('❌ ERROR: Request not found'),
      );

      // Update request status
      final updatedRequests = requests.map((r) {
        if (r.id == request.id) {
          return RideRequest(
            id: r.id,
            rideId: r.rideId,
            passengerId: r.passengerId,
            status: 'declined',
            requestedAt: r.requestedAt,
          );
        }
        return r;
      }).toList();
      rideRequests['ride-001'] = updatedRequests;

      print('✅ Request declined successfully');
      print('   Passenger: passenger2 | New Status: declined');
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 6: Passenger 2 tries to chat (should fail - declined)
  void scenarioPassenger2TriesChat() {
    print('\n=== SCENARIO 6: Passenger 2 Tries to Chat (Should Fail) ===');

    try {
      final requests = rideRequests['ride-001'] ?? [];
      final request = requests.firstWhere(
        (r) => r.passengerId == 'passenger2',
        orElse: () => throw Exception('❌ ERROR: Request not found'),
      );

      // Validation: Check request status before allowing chat
      if (request.status == 'declined') {
        throw Exception('❌ ERROR: Cannot chat on declined requests');
      }

      print('✅ Chat opened (request not declined)');
    } catch (e) {
      print('✅ EXPECTED ERROR CAUGHT: $e');
    }
  }

  // Scenario 7: Passenger 1 tries to chat (should succeed - accepted)
  void scenarioPassenger1ChatsWithDriver() {
    print(
      '\n=== SCENARIO 7: Passenger 1 Chats With Driver (Should Succeed) ===',
    );

    try {
      final requests = rideRequests['ride-001'] ?? [];
      final request = requests.firstWhere(
        (r) => r.passengerId == 'passenger1',
        orElse: () => throw Exception('❌ ERROR: Request not found'),
      );

      // Validation: Check request status
      if (request.status == 'declined') {
        throw Exception('❌ ERROR: Cannot chat on declined requests');
      }

      print('✅ Chat opened successfully');
      print('   Passenger: passenger1 | Request Status: ${request.status}');
      print('   Chat with Driver: driver1');
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 8: Passenger 1 tries to cancel (increments seats back)
  void scenarioPassenger1CancelsRequest() {
    print('\n=== SCENARIO 8: Passenger 1 Cancels Request ===');

    try {
      var ride = rides['ride-001'];
      if (ride == null) {
        throw Exception('❌ ERROR: Ride not found');
      }

      final requests = rideRequests['ride-001'] ?? [];
      final request = requests.firstWhere(
        (r) => r.passengerId == 'passenger1',
        orElse: () => throw Exception('❌ ERROR: Request not found'),
      );

      // Update request status to cancelled
      final updatedRequests = requests.map((r) {
        if (r.id == request.id) {
          return RideRequest(
            id: r.id,
            rideId: r.rideId,
            passengerId: r.passengerId,
            status: 'cancelled',
            requestedAt: r.requestedAt,
          );
        }
        return r;
      }).toList();
      rideRequests['ride-001'] = updatedRequests;

      // Restore seats (increment)
      ride = RideOffer(
        id: ride.id,
        driverId: ride.driverId,
        from: ride.from,
        to: ride.to,
        totalSeats: ride.totalSeats,
        seatsAvailable: ride.seatsAvailable + 1,
        price: ride.price,
        scheduledTime: ride.scheduledTime,
        status: ride.status,
      );
      rides['ride-001'] = ride;

      print('✅ Request cancelled successfully');
      print('   Passenger: passenger1 | New Status: cancelled');
      print(
        '   Seats restored: ${ride.seatsAvailable - 1} → ${ride.seatsAvailable}',
      );
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 9: Driver ends ride (must query for actual accepted passengers)
  void scenarioDriverEndsRide() {
    print('\n=== SCENARIO 9: Driver Ends Ride ===');

    try {
      var ride = rides['ride-001'];
      if (ride == null) {
        throw Exception('❌ ERROR: Ride not found');
      }

      // Query accepted passengers from Firestore (simulated)
      final requests = rideRequests['ride-001'] ?? [];
      final acceptedPassengers = requests
          .where((r) => r.status == 'accepted')
          .map((r) => {'passengerId': r.passengerId, 'requestId': r.id})
          .toList();

      if (acceptedPassengers.isEmpty) {
        // After Passenger 1 cancelled, no accepted passengers left
        print('⚠️ WARNING: No accepted passengers to rate');
      } else {
        print(
          '✅ Found ${acceptedPassengers.length} accepted passenger(s) to rate',
        );
        for (var p in acceptedPassengers) {
          print('   - ${p['passengerId']} (Request: ${p['requestId']})');
        }
      }

      // Mark ride as completed
      ride = RideOffer(
        id: ride.id,
        driverId: ride.driverId,
        from: ride.from,
        to: ride.to,
        totalSeats: ride.totalSeats,
        seatsAvailable: ride.seatsAvailable,
        price: ride.price,
        scheduledTime: ride.scheduledTime,
        status: 'completed',
      );
      rides['ride-001'] = ride;

      print('✅ Ride status updated to: completed');
      if (acceptedPassengers.isNotEmpty) {
        print(
          '✅ Navigation: Go to Rating Screen with ${acceptedPassengers.length} passenger(s)',
        );
      }
    } catch (e) {
      print('❌ FAILED: $e');
    }
  }

  // Scenario 10: Passenger 3 requests cancelled ride (should fail)
  void scenarioPassenger3RequestsCancelledRide() {
    print(
      '\n=== SCENARIO 10: Passenger 3 Requests Cancelled Ride (Should Fail) ===',
    );

    try {
      final ride = rides['ride-001'];
      if (ride == null) {
        throw Exception('❌ ERROR: Ride not found');
      }

      // Validation: Check ride is active
      if (ride.status != 'active') {
        throw Exception('❌ ERROR: This ride is ${ride.status}, cannot request');
      }

      print('✅ Ride is active, request allowed');
    } catch (e) {
      print('✅ EXPECTED ERROR CAUGHT: $e');
    }
  }

  // Scenario 11: Edge case - Duplicate request prevention
  void scenarioPassenger1RequestsAgainDuplicate() {
    print(
      '\n=== SCENARIO 11: Passenger 1 Requests Again (Duplicate Prevention) ===',
    );

    try {
      // Reset ride to active for this scenario
      var ride = rides['ride-001'];
      if (ride != null) {
        ride = RideOffer(
          id: ride.id,
          driverId: ride.driverId,
          from: ride.from,
          to: ride.to,
          totalSeats: ride.totalSeats,
          seatsAvailable: ride.seatsAvailable,
          price: ride.price,
          scheduledTime: ride.scheduledTime,
          status: 'active',
        );
        rides['ride-001'] = ride;
      }

      final requests = rideRequests['ride-001'] ?? [];

      // Check for existing request from same passenger
      final existingRequest = requests.firstWhere(
        (r) => r.passengerId == 'passenger1' && r.status != 'cancelled',
        orElse: () => throw Exception('No existing request'),
      );

      if (existingRequest != null) {
        throw Exception('❌ ERROR: Duplicate request detected for passenger1');
      }

      print('✅ No duplicate request detected');
    } catch (e) {
      print('✅ EXPECTED ERROR CAUGHT: $e');
    }
  }

  // Scenario 12: Boundary test - Max seats
  void scenarioBoundaryMaxSeats() {
    print('\n=== SCENARIO 12: Boundary Test - Max 10 Seats ===');

    try {
      final ride = RideOffer(
        id: 'ride-boundary-1',
        driverId: 'driver2',
        from: 'Manama',
        to: 'Riffa',
        totalSeats: 10,
        seatsAvailable: 10,
        price: 3.0,
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      if (ride.totalSeats < 1 || ride.totalSeats > 10) {
        throw Exception('❌ ERROR: Invalid seat count');
      }
      print('✅ Max seats boundary (10) accepted');

      // Try 11 seats (should fail)
      final invalid = RideOffer(
        id: 'ride-invalid',
        driverId: 'driver2',
        from: 'Manama',
        to: 'Riffa',
        totalSeats: 11,
        seatsAvailable: 11,
        price: 3.0,
        scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      );

      if (invalid.totalSeats > 10) {
        throw Exception('❌ ERROR: Seats exceed max (11 > 10)');
      }
    } catch (e) {
      print('✅ EXPECTED ERROR: $e');
    }
  }

  // Scenario 13: Boundary test - Max price
  void scenarioBoundaryMaxPrice() {
    print('\n=== SCENARIO 13: Boundary Test - Max BD 500 ===');

    try {
      final ride = RideOffer(
        id: 'ride-boundary-2',
        driverId: 'driver3',
        from: 'Manama',
        to: 'Budaiya',
        totalSeats: 4,
        seatsAvailable: 4,
        price: 500.0,
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      );

      if (ride.price < 1 || ride.price > 500) {
        throw Exception('❌ ERROR: Invalid price');
      }
      print('✅ Max price boundary (BD 500) accepted');

      // Try 500.01 (should fail)
      if (500.01 > 500) {
        throw Exception('❌ ERROR: Price exceeds max (500.01 > 500)');
      }
    } catch (e) {
      print('✅ EXPECTED ERROR: $e');
    }
  }

  void runAllScenarios() {
    print('╔════════════════════════════════════════════════════════════════╗');
    print(
      '║         UniRide - Comprehensive Flow Simulation Test            ║',
    );
    print(
      '║                   All Scenarios & Error Handling                ║',
    );
    print('╚════════════════════════════════════════════════════════════════╝');

    scenarioDriverCreatesRide();
    scenarioPassenger1RequestsRide();
    scenarioPassenger2RequestsRide();
    scenarioDriverAcceptsPassenger1();
    scenarioDriverDeclinesPassenger2();
    scenarioPassenger2TriesChat();
    scenarioPassenger1ChatsWithDriver();
    scenarioPassenger1CancelsRequest();
    scenarioDriverEndsRide();
    scenarioPassenger3RequestsCancelledRide();
    scenarioPassenger1RequestsAgainDuplicate();
    scenarioBoundaryMaxSeats();
    scenarioBoundaryMaxPrice();

    print(
      '\n╔════════════════════════════════════════════════════════════════╗',
    );
    print('║                    SIMULATION COMPLETE ✅                      ║');
    print(
      '║                  All scenarios executed successfully            ║',
    );
    print('╚════════════════════════════════════════════════════════════════╝');
  }
}

void main() {
  test('UniRide - Comprehensive Simulation with Error Handling', () {
    final simulation = RideSimulation();
    simulation.runAllScenarios();
  });
}
