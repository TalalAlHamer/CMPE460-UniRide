const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();

// Store your Google API key in Firebase environment config (see instructions below)
const GOOGLE_API_KEY = functions.config().google?.api_key || 'YOUR_API_KEY_HERE';

/**
 * Google Places Autocomplete Proxy
 * Usage: POST /placesAutocomplete with body: { query: "search term" }
 */
exports.placesAutocomplete = functions.https.onCall(async (data, context) => {
  // Optional: Authenticate requests
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to use this function.'
    );
  }

  const { query } = data;

  if (!query || query.trim().length < 2) {
    return { predictions: [] };
  }

  try {
    const response = await axios.get(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
      {
        params: {
          input: query,
          key: GOOGLE_API_KEY,
          location: '26.0667,50.5577', // Bahrain coordinates
          radius: 50000,
          components: 'country:bh',
          types: 'establishment|geocode'
        }
      }
    );

    if (response.data.status !== 'OK' && response.data.status !== 'ZERO_RESULTS') {
      console.error('Google Places API error:', response.data);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to fetch location suggestions'
      );
    }

    // Return predictions with limited data to reduce bandwidth
    const predictions = (response.data.predictions || []).slice(0, 5).map(p => ({
      placeId: p.place_id,
      description: p.description
    }));

    return { predictions };
  } catch (error) {
    console.error('Error calling Places API:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error fetching location suggestions'
    );
  }
});

/**
 * Google Place Details Proxy
 * Usage: POST /placeDetails with body: { placeId: "ChIJ..." }
 */
exports.placeDetails = functions.https.onCall(async (data, context) => {
  // Optional: Authenticate requests
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to use this function.'
    );
  }

  const { placeId } = data;

  if (!placeId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'placeId is required'
    );
  }

  try {
    const response = await axios.get(
      'https://maps.googleapis.com/maps/api/place/details/json',
      {
        params: {
          place_id: placeId,
          key: GOOGLE_API_KEY,
          fields: 'geometry'
        }
      }
    );

    if (response.data.status !== 'OK') {
      console.error('Google Place Details API error:', response.data);
      throw new functions.https.HttpsError(
        'internal',
        'Failed to fetch place details'
      );
    }

    const location = response.data.result?.geometry?.location;
    if (!location) {
      throw new functions.https.HttpsError(
        'not-found',
        'Location not found for this place'
      );
    }

    return {
      lat: location.lat,
      lng: location.lng
    };
  } catch (error) {
    console.error('Error calling Place Details API:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error fetching place details'
    );
  }
});

/**
 * Google Geocoding (Reverse) Proxy
 * Usage: POST /reverseGeocode with body: { lat: 26.0667, lng: 50.5577 }
 */
exports.reverseGeocode = functions.https.onCall(async (data, context) => {
  // Optional: Authenticate requests
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to use this function.'
    );
  }

  const { lat, lng } = data;

  if (lat === undefined || lng === undefined) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'lat and lng are required'
    );
  }

  try {
    const response = await axios.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      {
        params: {
          latlng: `${lat},${lng}`,
          key: GOOGLE_API_KEY
        }
      }
    );

    if (response.data.status !== 'OK') {
      console.error('Google Geocoding API error:', response.data);
      return { address: null };
    }

    const results = response.data.results || [];
    const address = results.length > 0 ? results[0].formatted_address : null;

    return { address };
  } catch (error) {
    console.error('Error calling Geocoding API:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Error fetching address'
    );
  }
});

/**
 * Notification Triggers
 * These functions monitor Firestore and send push notifications via FCM
 */

// Send notification when a new ride request is made
exports.onRideRequest = functions.firestore
  .document('rides/{rideId}/requests/{requestId}')
  .onCreate(async (snap, context) => {
    const request = snap.data();
    const rideId = context.params.rideId;

    try {
      // Get ride details to find the driver
      const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return;

      const ride = rideDoc.data();
      const driverId = ride.driverId;

      // Get passenger details
      const passengerDoc = await admin.firestore().collection('users').doc(request.passengerId).get();
      if (!passengerDoc.exists) return;

      const passenger = passengerDoc.data();

      // Get driver's FCM token
      const driverDoc = await admin.firestore().collection('users').doc(driverId).get();
      if (!driverDoc.exists) return;

      const driver = driverDoc.data();
      const fcmToken = driver.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token for driver:', driverId);
        return;
      }

      // Send notification
      const message = {
        token: fcmToken,
        notification: {
          title: 'New Ride Request',
          body: `${passenger.name} wants to join your ride from ${ride.from} to ${ride.to}`,
        },
        data: {
          type: 'ride_request',
          rideId: rideId,
          requestId: snap.id,
          passengerId: request.passengerId,
        },
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      };

      await admin.messaging().send(message);
      console.log('Notification sent to driver:', driverId);

      // Create notification document
      await admin.firestore().collection('notifications').add({
        recipientId: driverId,
        senderId: request.passengerId,
        senderName: passenger.name,
        title: 'New Ride Request',
        body: `${passenger.name} wants to join your ride`,
        type: 'ride_request',
        rideId: rideId,
        requestId: snap.id,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      console.error('Error sending ride request notification:', error);
    }
  });

// Send notification when ride request is accepted
exports.onRideAccept = functions.firestore
  .document('rides/{rideId}/requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const rideId = context.params.rideId;

    // Only trigger if status changed to accepted
    if (before.status !== 'accepted' && after.status === 'accepted') {
      try {
        // Get ride details
        const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
        if (!rideDoc.exists) return;

        const ride = rideDoc.data();

        // Get driver details
        const driverDoc = await admin.firestore().collection('users').doc(ride.driverId).get();
        if (!driverDoc.exists) return;

        const driver = driverDoc.data();

        // Get passenger's FCM token
        const passengerDoc = await admin.firestore().collection('users').doc(after.passengerId).get();
        if (!passengerDoc.exists) return;

        const passenger = passengerDoc.data();
        const fcmToken = passenger.fcmToken;

        if (!fcmToken) {
          console.log('No FCM token for passenger:', after.passengerId);
          return;
        }

        // Send notification
        const message = {
          token: fcmToken,
          notification: {
            title: 'Ride Request Accepted',
            body: `${driver.name} accepted your request for the ride from ${ride.from} to ${ride.to}`,
          },
          data: {
            type: 'ride_accepted',
            rideId: rideId,
            requestId: change.after.id,
            driverId: ride.driverId,
          },
          android: {
            priority: 'high',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        };

        await admin.messaging().send(message);
        console.log('Notification sent to passenger:', after.passengerId);

        // Create notification document
        await admin.firestore().collection('notifications').add({
          recipientId: after.passengerId,
          senderId: ride.driverId,
          senderName: driver.name,
          title: 'Ride Request Accepted',
          body: `${driver.name} accepted your ride request`,
          type: 'ride_accepted',
          rideId: rideId,
          requestId: change.after.id,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error('Error sending ride accept notification:', error);
      }
    }
  });

// Send notification when ride request is declined
exports.onRideDecline = functions.firestore
  .document('rides/{rideId}/requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const rideId = context.params.rideId;

    // Only trigger if status changed to declined
    if (before.status !== 'declined' && after.status === 'declined') {
      try {
        // Get ride details
        const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
        if (!rideDoc.exists) return;

        const ride = rideDoc.data();

        // Get driver details
        const driverDoc = await admin.firestore().collection('users').doc(ride.driverId).get();
        if (!driverDoc.exists) return;

        const driver = driverDoc.data();

        // Get passenger's FCM token
        const passengerDoc = await admin.firestore().collection('users').doc(after.passengerId).get();
        if (!passengerDoc.exists) return;

        const passenger = passengerDoc.data();
        const fcmToken = passenger.fcmToken;

        if (!fcmToken) {
          console.log('No FCM token for passenger:', after.passengerId);
          return;
        }

        // Send notification
        const message = {
          token: fcmToken,
          notification: {
            title: 'Ride Request Declined',
            body: `${driver.name} declined your request for the ride from ${ride.from} to ${ride.to}`,
          },
          data: {
            type: 'ride_declined',
            rideId: rideId,
            requestId: change.after.id,
            driverId: ride.driverId,
          },
          android: {
            priority: 'high',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        };

        await admin.messaging().send(message);
        console.log('Notification sent to passenger:', after.passengerId);

        // Create notification document
        await admin.firestore().collection('notifications').add({
          recipientId: after.passengerId,
          senderId: ride.driverId,
          senderName: driver.name,
          title: 'Ride Request Declined',
          body: `${driver.name} declined your ride request`,
          type: 'ride_declined',
          rideId: rideId,
          requestId: change.after.id,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error('Error sending ride decline notification:', error);
      }
    }
  });

// Send notification when ride is cancelled by driver
exports.onRideCancelled = functions.firestore
  .document('rides/{rideId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const rideId = context.params.rideId;

    // Only trigger if status changed to cancelled
    if (before.status !== 'cancelled' && after.status === 'cancelled') {
      try {
        // Get driver details
        const driverDoc = await admin.firestore().collection('users').doc(after.driverId).get();
        if (!driverDoc.exists) return;

        const driver = driverDoc.data();

        // Get all accepted passengers for this ride
        const requestsSnapshot = await admin.firestore()
          .collection('rides')
          .doc(rideId)
          .collection('requests')
          .where('status', '==', 'accepted')
          .get();

        // Send notification to each accepted passenger
        const notifications = requestsSnapshot.docs.map(async (requestDoc) => {
          const request = requestDoc.data();
          const passengerId = request.passengerId;

          // Get passenger's FCM token
          const passengerDoc = await admin.firestore().collection('users').doc(passengerId).get();
          if (!passengerDoc.exists) return;

          const passenger = passengerDoc.data();
          const fcmToken = passenger.fcmToken;

          if (!fcmToken) {
            console.log('No FCM token for passenger:', passengerId);
            return;
          }

          // Send notification
          const message = {
            token: fcmToken,
            notification: {
              title: 'Ride Cancelled',
              body: `${driver.name} cancelled the ride from ${after.from} to ${after.to} on ${after.date} at ${after.time}`,
            },
            data: {
              type: 'ride_cancelled',
              rideId: rideId,
              driverId: after.driverId,
            },
            android: {
              priority: 'high',
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                },
              },
            },
          };

          await admin.messaging().send(message);
          console.log('Notification sent to passenger:', passengerId);

          // Create notification document
          await admin.firestore().collection('notifications').add({
            recipientId: passengerId,
            senderId: after.driverId,
            senderName: driver.name,
            title: 'Ride Cancelled',
            body: `${driver.name} cancelled the ride`,
            type: 'ride_cancelled',
            rideId: rideId,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        await Promise.all(notifications);
      } catch (error) {
        console.error('Error sending ride cancellation notifications:', error);
      }
    }
  });

// Send notification when passenger cancels their request
exports.onRequestCancelled = functions.firestore
  .document('ride_requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const requestId = context.params.requestId;

    // Only trigger if status changed to cancelled
    if (before.status !== 'cancelled' && after.status === 'cancelled') {
      try {
        const rideId = after.rideId;
        
        // Get ride details to find the driver
        const rideDoc = await admin.firestore().collection('rides').doc(rideId).get();
        if (!rideDoc.exists) return;

        const ride = rideDoc.data();
        const driverId = ride.driverId;

        // Get passenger details
        const passengerDoc = await admin.firestore().collection('users').doc(after.passengerId).get();
        if (!passengerDoc.exists) return;

        const passenger = passengerDoc.data();

        // Get driver's FCM token
        const driverDoc = await admin.firestore().collection('users').doc(driverId).get();
        if (!driverDoc.exists) return;

        const driver = driverDoc.data();
        const fcmToken = driver.fcmToken;

        if (!fcmToken) {
          console.log('No FCM token for driver:', driverId);
          return;
        }

        // Send notification
        const message = {
          token: fcmToken,
          notification: {
            title: 'Ride Request Cancelled',
            body: `${passenger.name} cancelled their request for the ride from ${after.from} to ${after.to}`,
          },
          data: {
            type: 'request_cancelled',
            rideId: rideId,
            requestId: requestId,
            passengerId: after.passengerId,
          },
          android: {
            priority: 'high',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
              },
            },
          },
        };

        await admin.messaging().send(message);
        console.log('Notification sent to driver:', driverId);

        // Create notification document
        await admin.firestore().collection('notifications').add({
          recipientId: driverId,
          senderId: after.passengerId,
          senderName: passenger.name,
          title: 'Ride Request Cancelled',
          body: `${passenger.name} cancelled their ride request`,
          type: 'request_cancelled',
          rideId: rideId,
          requestId: requestId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error('Error sending request cancellation notification:', error);
      }
    }
  });

// Send notification when a new chat message is sent
exports.onMessageSent = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();

    // Only process chat message notifications
    if (notification.type !== 'chat_message') return;

    try {
      // Get recipient's FCM token
      const recipientDoc = await admin.firestore()
        .collection('users')
        .doc(notification.recipientId)
        .get();

      if (!recipientDoc.exists) return;

      const recipient = recipientDoc.data();
      const fcmToken = recipient.fcmToken;

      if (!fcmToken) {
        console.log('No FCM token for user:', notification.recipientId);
        return;
      }

      // Send notification
      const message = {
        token: fcmToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          type: 'chat_message',
          chatRoomId: notification.chatRoomId,
          senderId: notification.senderId,
          senderName: notification.senderName || 'User',
        },
        android: {
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      };

      await admin.messaging().send(message);
      console.log('Chat notification sent to user:', notification.recipientId);
    } catch (error) {
      console.error('Error sending chat notification:', error);
    }
  });

// Scheduled function to automatically complete rides 6 hours after start time
// Runs every hour
exports.autoCompleteExpiredRides = functions.pubsub
  .schedule('0 * * * *') // Run at the start of every hour
  .timeZone('Asia/Bahrain')
  .onRun(async (context) => {
    console.log('Running auto-complete expired rides job...');

    try {
      const now = new Date();
      const db = admin.firestore();

      // Query all active rides (not completed or cancelled)
      const ridesSnapshot = await db.collection('rides')
        .where('status', '!=', 'completed')
        .get();

      let completedCount = 0;

      for (const rideDoc of ridesSnapshot.docs) {
        const ride = rideDoc.data();
        
        // Skip cancelled rides
        if (ride.status === 'cancelled') continue;

        // Parse ride date and time
        const rideDate = ride.date; // Format: "DD/MM/YYYY"
        const rideTime = ride.time; // Format: "HH:mm"

        if (!rideDate || !rideTime) continue;

        // Parse date string (DD/MM/YYYY)
        const [day, month, year] = rideDate.split('/').map(Number);
        const [hours, minutes] = rideTime.split(':').map(Number);

        // Create Date object for ride start time
        const rideDateTime = new Date(year, month - 1, day, hours, minutes);
        
        // Calculate time difference in hours
        const hoursSinceStart = (now - rideDateTime) / (1000 * 60 * 60);

        // If more than 6 hours have passed, auto-complete the ride
        if (hoursSinceStart > 6) {
          console.log(`Auto-completing ride ${rideDoc.id} (started ${hoursSinceStart.toFixed(1)} hours ago)`);

          // Get all ride requests for this ride
          const requestsSnapshot = await db.collection('rides')
            .doc(rideDoc.id)
            .collection('requests')
            .get();

          const acceptedPassengers = requestsSnapshot.docs
            .filter(doc => doc.data().status === 'accepted')
            .map(doc => ({
              id: doc.id,
              ...doc.data()
            }));

          // Create batch for atomic updates
          const batch = db.batch();

          // Update ride status to completed
          batch.update(rideDoc.ref, {
            status: 'completed',
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            autoCompleted: true // Flag to indicate it was auto-completed
          });

          // Update all ride requests to completed status
          for (const requestDoc of requestsSnapshot.docs) {
            batch.update(requestDoc.ref, {
              status: 'completed',
              completedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          // Update driver's totalRides
          const driverRef = db.collection('users').doc(ride.driverId);
          batch.update(driverRef, {
            totalRides: admin.firestore.FieldValue.increment(1)
          });

          // Update each accepted passenger's totalRides and create pending ratings
          for (const passenger of acceptedPassengers) {
            const passengerRef = db.collection('users').doc(passenger.passengerId);
            batch.update(passengerRef, {
              totalRides: admin.firestore.FieldValue.increment(1)
            });

            // Create pending rating document for passenger
            const pendingRatingRef = db.collection('pending_ratings').doc();
            batch.set(pendingRatingRef, {
              passengerId: passenger.passengerId,
              driverId: ride.driverId,
              driverName: ride.driverName || 'Driver',
              rideId: rideDoc.id,
              from: ride.from || '',
              to: ride.to || '',
              date: ride.date || '',
              time: ride.time || '',
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              completed: false
            });
          }

          // Commit batch
          await batch.commit();
          completedCount++;

          console.log(`Successfully auto-completed ride ${rideDoc.id}`);
        }
      }

      console.log(`Auto-complete job finished. Completed ${completedCount} rides.`);
      return null;
    } catch (error) {
      console.error('Error in auto-complete expired rides job:', error);
      return null;
    }
  });
