import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model for location suggestions
class LocationSuggestion {
  final String displayName;
  final String placeId;
  final double lat;
  final double lon;

  LocationSuggestion({
    required this.displayName,
    required this.placeId,
    required this.lat,
    required this.lon,
  });
}

/// Secure Google Places API service using Firebase Cloud Functions
class SecurePlacesService {
  static final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Search for places using autocomplete and fetch coordinates
  static Future<List<LocationSuggestion>> search(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final callable = _functions.httpsCallable('placesAutocomplete');
      final result = await callable.call({'query': query});
      
      final predictions = result.data['predictions'] as List? ?? [];
      
      // Fetch coordinates for each prediction
      final List<LocationSuggestion> results = [];
      for (final p in predictions) {
        final placeId = p['placeId'] ?? '';
        final description = p['description'] ?? '';
        
        // Get coordinates for this place
        final coords = await _getPlaceDetails(placeId);
        if (coords != null) {
          results.add(LocationSuggestion(
            displayName: description,
            placeId: placeId,
            lat: coords['lat']!,
            lon: coords['lng']!,
          ));
        }
        
        // Limit to 5 results
        if (results.length >= 5) break;
      }
      
      return results;
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return [];
    }
  }

  /// Get place details (coordinates) by place ID
  static Future<Map<String, double>?> _getPlaceDetails(String placeId) async {
    try {
      final callable = _functions.httpsCallable('placeDetails');
      final result = await callable.call({'placeId': placeId});
      
      return {
        'lat': (result.data['lat'] as num).toDouble(),
        'lng': (result.data['lng'] as num).toDouble(),
      };
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return null;
    }
  }

  /// Reverse geocode coordinates to address
  static Future<String?> reverse(LatLng point) async {
    try {
      final callable = _functions.httpsCallable('reverseGeocode');
      final result = await callable.call({
        'lat': point.latitude,
        'lng': point.longitude,
      });
      
      return result.data['address'] as String?;
    } catch (e) {
    // Error handling: silently catch to prevent crashes
      return null;
    }
  }
}
