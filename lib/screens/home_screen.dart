import 'dart:async';
import 'dart:convert';
import 'package:Trekly/widgets/search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? mapboxMapController;
  PointAnnotationManager? pointAnnotationManager;
  CircleAnnotationManager? circleAnnotationManager;
  StreamSubscription? userPositionStream;
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;
  List _suggestions = []; // Add this line

  void initState() {
    super.initState();
    _setupPositionTracking();
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

                // Pass the place data to _handleMapTap
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
        ],
      ),
    );
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    setState(() {
      mapboxMapController = mapboxMap;
    });

    try {
      pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      circleAnnotationManager =
          await mapboxMap.annotations.createCircleAnnotationManager();

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
        if (mapboxMapController != null) {
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

  @override
  void dispose() {
    _hideOverlay();
    userPositionStream?.cancel();
    super.dispose();
  }

  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
