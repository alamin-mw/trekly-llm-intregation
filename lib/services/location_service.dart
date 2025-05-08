import 'package:geolocator/geolocator.dart' as geo;
import 'dart:async';

class LocationService {
  StreamSubscription<geo.Position>? _positionStream;

  Future<geo.Position> getCurrentPosition() async {
    final servicesEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      throw Exception('Location services are disabled');
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    return await geo.Geolocator.getCurrentPosition();
  }

  void startPositionTracking(void Function(geo.Position) onPositionUpdate) {
    _positionStream = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 100,
      ),
    ).listen(onPositionUpdate);
  }

  void stopPositionTracking() {
    _positionStream?.cancel();
  }
}
