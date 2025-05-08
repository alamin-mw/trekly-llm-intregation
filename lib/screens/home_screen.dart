import 'dart:async';
import 'dart:convert';
import 'package:Trekly/widgets/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:math' as math;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _fabElevation = 4.0;
  static const _fabSize = 56.0;

  MapboxMap? mapboxMapController;
  PointAnnotationManager? pointAnnotationManager;
  CircleAnnotationManager? circleAnnotationManager;
  PolylineAnnotationManager? polylineAnnotationManager;
  StreamSubscription? userPositionStream;
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;
  List _suggestions = [];

  final List<Map<String, dynamic>> _tourLocations = [
    {
      'name': 'Eiffel Tower',
      'coordinates': Position(2.2945, 48.8584),
      'description': 'The iconic symbol of Paris, France, built in 1889.',
    },
    {
      'name': 'Colosseum',
      'coordinates': Position(12.4924, 41.8902),
      'description': 'Ancient amphitheater in Rome, Italy',
    },
    {
      'name': 'Taj Mahal',
      'coordinates': Position(78.0421, 27.1751),
      'description': 'Beautiful mausoleum in Agra, India',
    },
  ];

  int _currentTourStop = 0;
  bool _isTourActive = false;

  @override
  void initState() {
    super.initState();
    _setupPositionTracking();
  }

  @override
  void dispose() {
    _hideOverlay();
    userPositionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            styleUri: MapboxStyles.DARK,
            onTapListener: (ctx) => _handleMapTap(ctx.point),
          ),
          MapSearchWidget(
            suggestions: _suggestions,
            onSearch: (query) async {
              if (query.isEmpty) return;

              final response = await http.get(
                Uri.parse(
                  'https://api.mapbox.com/search/searchbox/v1/suggest?q=$query&session_token=${_generateSessionToken()}&access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                ),
              );

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                final suggestions = data['suggestions'] as List;
                setState(() {
                  _suggestions = suggestions;
                });
              }
            },
            onSuggestionSelected: (suggestion) async {
              final response = await http.get(
                Uri.parse(
                  'https://api.mapbox.com/search/searchbox/v1/retrieve/${suggestion['mapbox_id']}?session_token=${_generateSessionToken()}&access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN']}',
                ),
              );

              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                final coordinates =
                    data['features'][0]['geometry']['coordinates'];
                final point = Point(
                  coordinates: Position(coordinates[0], coordinates[1]),
                );

                mapboxMapController?.flyTo(
                  CameraOptions(
                    center: point,
                    zoom: 15,
                    bearing: 180,
                    pitch: 30,
                  ),
                  MapAnimationOptions(duration: 2000, startDelay: 0),
                );

                _handleMapTap(point, placeData: data);
              }
            },
            onCenterUserLocation: () async {
              final position = await geo.Geolocator.getCurrentPosition();
              final point = Point(
                coordinates: Position(position.longitude, position.latitude),
              );
              mapboxMapController?.flyTo(
                CameraOptions(center: point, zoom: 15),
                MapAnimationOptions(duration: 2000, startDelay: 0),
              );
            },
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isTourActive)
                  FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        _isTourActive = true;
                        _currentTourStop = 0;
                      });
                      _navigateToTourLocation(_currentTourStop);
                    },
                    backgroundColor: Theme.of(context).primaryColor,
                    elevation: 4,
                    icon: const Icon(Icons.tour, color: Colors.white),
                    label: const Text(
                      'Start Guided Tour',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: _fabElevation,
                    color: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed:
                                _currentTourStop > 0
                                    ? () {
                                      setState(() {
                                        _currentTourStop--;
                                      });
                                      _navigateToTourLocation(_currentTourStop);
                                    }
                                    : null,
                            color: Colors.white,
                          ),
                          Text(
                            '${_currentTourStop + 1}/${_tourLocations.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed:
                                _currentTourStop < _tourLocations.length - 1
                                    ? () {
                                      setState(() {
                                        _currentTourStop++;
                                      });
                                      _navigateToTourLocation(_currentTourStop);
                                    }
                                    : null,
                            color: Colors.white,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _isTourActive = false;
                                _hideOverlay();
                              });
                            },
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: 'centerOnMe',
                    onPressed: _flyToUserLocation,
                    backgroundColor: Theme.of(context).primaryColor,
                    elevation: _fabElevation,
                    shape: const CircleBorder(),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: 'wanderMode',
                    onPressed: _activateWanderMode,
                    backgroundColor: Theme.of(context).primaryColor,
                    elevation: _fabElevation,
                    shape: const CircleBorder(),
                    child: const Icon(
                      Icons.directions_walk,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    setState(() {
      mapboxMapController = mapboxMap;
    });

    try {
      pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      circleAnnotationManager =
          await mapboxMap.annotations.createCircleAnnotationManager();
      polylineAnnotationManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();

      await mapboxMap.location.updateSettings(
        LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    } catch (e) {
      print('Error initializing annotations: $e');
    }
  }

  void _showOverlay(
    BuildContext context,
    Point point, {
    Map<String, dynamic>? placeData,
  }) {
    _hideOverlay();

    final properties = placeData?['features']?[0]?['properties'];

    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Material(
              elevation: 4.0,
              borderRadius: BorderRadius.circular(12),
              color: const Color.fromARGB(255, 21, 27, 31),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      properties?['name'] ?? 'Location Details',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (properties?['full_address'] != null)
                      Text(
                        properties!['full_address'],
                        style: const TextStyle(color: Colors.white70),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates: ${point.coordinates.lat.toStringAsFixed(6)}, ${point.coordinates.lng.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _hideOverlay,
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    if (mounted) {
      Overlay.of(context).insert(_overlayEntry!);
      _isOverlayVisible = true;
    }
  }

  void _hideOverlay() {
    if (_isOverlayVisible) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOverlayVisible = false;
    }
  }

  void _handleMapTap(Point point, {Map<String, dynamic>? placeData}) async {
    if (pointAnnotationManager == null) return;

    try {
      final ByteData bytes = await rootBundle.load('assets/custom-icon.png');
      final Uint8List imageData = bytes.buffer.asUint8List();

      await pointAnnotationManager?.deleteAll();
      await circleAnnotationManager?.deleteAll();

      await pointAnnotationManager?.create(
        PointAnnotationOptions(
          geometry: point,
          image: imageData,
          iconSize: 0.3,
        ),
      );

      await circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: point,
          circleRadius: 30,
          circleColor: Colors.blue.value,
          circleOpacity: 0.5,
          circleStrokeWidth: 2,
          circleStrokeColor: Colors.white.value,
        ),
      );

      _showOverlay(context, point, placeData: placeData);
    } catch (e) {
      print('Error handling map tap: $e');
    }
  }

  void _navigateToTourLocation(int index) {
    if (index >= 0 && index < _tourLocations.length) {
      final location = _tourLocations[index];
      final point = Point(coordinates: location['coordinates']);

      mapboxMapController?.flyTo(
        CameraOptions(center: point, zoom: 15, bearing: 180, pitch: 30),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );

      _handleMapTap(
        point,
        placeData: {
          'features': [
            {
              'properties': {
                'name': location['name'],
                'full_address': location['description'],
              },
            },
          ],
        },
      );
    }
  }

  Future<void> _setupPositionTracking() async {
    try {
      final servicesEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!servicesEnabled) {
        return Future.error('Location services are disabled');
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        return Future.error('Location permissions are permanently denied');
      }

      userPositionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 100,
        ),
      ).listen((geo.Position position) {
        if (mapboxMapController != null && !_isTourActive) {
          mapboxMapController?.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(position.longitude, position.latitude),
              ),
              zoom: 15,
            ),
          );
        }
      });
    } catch (e) {
      print('Error setting up position tracking: $e');
    }
  }

  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  void _flyToUserLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      final point = Point(
        coordinates: Position(position.longitude, position.latitude),
      );

      mapboxMapController?.flyTo(
        CameraOptions(center: point, zoom: 15, bearing: 0, pitch: 0),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
    } catch (e) {
      print('Error getting user location: $e');
    }
  }

  void _activateWanderMode() async {
    try {
      // Get user position
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      // Find nearest landmark
      Map<String, dynamic>? nearestLandmark;
      double minDistance = double.infinity;
      for (var landmark in _tourLocations) {
        final distance = geo.Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          landmark['coordinates'].lat.toDouble(),
          landmark['coordinates'].lng.toDouble(),
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestLandmark = landmark;
        }
      }

      if (nearestLandmark == null) {
        _showError('No landmarks available');
        return;
      }

      final targetPoint = Point(coordinates: nearestLandmark['coordinates']);
      String guidanceText;
      Map<String, dynamic> placeData = {
        'features': [
          {
            'properties': {
              'name': nearestLandmark['name'],
              'full_address': nearestLandmark['description'],
            },
          },
        ],
      };

      Point destination;
      if (minDistance <= 200.0) {
        // Within 200m, navigate directly to landmark
        destination = targetPoint;
        guidanceText =
            'You are near the ${nearestLandmark['name']}. ${nearestLandmark['description']} Follow the path to explore.';
      } else {
        // Calculate a point 200m closer to the landmark
        destination = await _getPointCloser(
          position,
          nearestLandmark['coordinates'],
          minDistance,
        );
        guidanceText =
            'You are ${minDistance.round()} meters from the ${nearestLandmark['name']}. '
            'Follow the route to get closer to ${nearestLandmark['description']}';
      }

      // Start navigation to destination
      await _startNavigation(position, destination);

      // Show overlay with guidance text
      _showOverlay(context, destination, placeData: placeData);
    } catch (e) {
      _showError('Error in Wander Mode: $e');
    }
  }

  Future<Point> _getPointCloser(
    geo.Position current,
    Position target,
    double distance,
  ) async {
    // Fetch route to get intermediate points
    final route = await _getRoute(
      Point(coordinates: Position(current.longitude, current.latitude)),
      Point(coordinates: target),
    );

    if (route != null && route.coordinates.isNotEmpty) {
      // Find a point approximately 200m closer along the route
      double accumulatedDistance = 0.0;
      Position lastCoord = route.coordinates.first;
      for (var coord in route.coordinates.skip(1)) {
        final segmentDistance = geo.Geolocator.distanceBetween(
          lastCoord.lat.toDouble(),
          lastCoord.lng.toDouble(),
          coord.lat.toDouble(),
          coord.lng.toDouble(),
        );
        accumulatedDistance += segmentDistance;
        if (accumulatedDistance >= (distance - 200.0)) {
          return Point(coordinates: lastCoord);
        }
        lastCoord = coord;
      }
      // If route is too short, return the last point
      return Point(coordinates: route.coordinates.last);
    }

    // Fallback: Calculate a point 200m closer using spherical geometry
    final bearing = geo.Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      target.lat.toDouble(),
      target.lng.toDouble(),
    );

    // Earth's radius in meters
    const earthRadius = 6371000.0;
    final distanceToTravel = distance - 200.0; // Move 200m closer
    final angularDistance = distanceToTravel / earthRadius;

    final lat1 = current.latitude * math.pi / 180;
    final lon1 = current.longitude * math.pi / 180;
    final bearingRad = bearing * math.pi / 180;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearingRad),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearingRad) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    final newLat = lat2 * 180 / math.pi;
    final newLon = lon2 * 180 / math.pi;

    return Point(coordinates: Position(newLon, newLat));
  }

  Future<void> _startNavigation(
    geo.Position position,
    Point destination,
  ) async {
    if (mapboxMapController == null || pointAnnotationManager == null) return;

    // Clear existing annotations
    await pointAnnotationManager?.deleteAll();
    await circleAnnotationManager?.deleteAll();
    await polylineAnnotationManager?.deleteAll();

    // Add user marker
    final userPoint = Point(
      coordinates: Position(position.longitude, position.latitude),
    );
    final userIconBytes = await rootBundle.load('assets/user-icon.png');
    final userIconData = userIconBytes.buffer.asUint8List();
    await pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: userPoint,
        image: userIconData,
        iconSize: 0.3,
      ),
    );

    // Add destination marker
    final destIconBytes = await rootBundle.load('assets/custom-icon.png');
    final destIconData = destIconBytes.buffer.asUint8List();
    await pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: destination,
        image: destIconData,
        iconSize: 0.3,
      ),
    );

    // Fetch and draw route
    final route = await _getRoute(userPoint, destination);
    if (route != null) {
      await polylineAnnotationManager?.create(
        PolylineAnnotationOptions(
          geometry: route,
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );
    }

    // Center map on user
    mapboxMapController?.flyTo(
      CameraOptions(center: userPoint, zoom: 15, bearing: 0, pitch: 0),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  Future<LineString?> _getRoute(Point origin, Point destination) async {
    final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;
    final url =
        'https://api.mapbox.com/directions/v5/mapbox/walking/${origin.coordinates.lng},${origin.coordinates.lat};${destination.coordinates.lng},${destination.coordinates.lat}?geometries=geojson&access_token=$accessToken';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
      return LineString(
        coordinates:
            coordinates.map((coord) => Position(coord[0], coord[1])).toList(),
      );
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(
    MaterialApp(
      home: const HomeScreen(),
      theme: ThemeData(primarySwatch: Colors.blue),
    ),
  );
}
