import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class TourLocation {
  final String name;
  final Position coordinates; // Use mapbox_maps_flutter.Position
  final String description;

  TourLocation({
    required this.name,
    required this.coordinates,
    required this.description,
  });
}
