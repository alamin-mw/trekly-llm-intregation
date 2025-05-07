import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MapboxMap? mapboxMapController;
  PointAnnotationManager? pointAnnotationManager;
  StreamSubscription? userPositionStream;
  CircleAnnotationManager? circleAnnotationManager;

  // Add these properties
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;

  void initState() {
    super.initState();
    _setupPositionTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MapWidget(
        onMapCreated: _onMapCreated,
        styleUri: MapboxStyles.DARK,
        onTapListener: (ctx) => _handleMapTap(ctx.point),
      ),
    );
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    setState(() {
      mapboxMapController = mapboxMap;
    });
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    circleAnnotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager();
    mapboxMapController?.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  void _showOverlay(BuildContext context, Point point) {
    _hideOverlay();

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
                      'Location Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Latitude: ${point.coordinates.lat.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      'Longitude: ${point.coordinates.lng.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _hideOverlay,
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOverlayVisible = true;
  }

  void _hideOverlay() {
    if (_isOverlayVisible) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOverlayVisible = false;
    }
  }

  void _handleMapTap(Point point) async {
    if (pointAnnotationManager == null) return;

    final ByteData bytes = await rootBundle.load('assets/custom-icon.png');
    final Uint8List imageData = bytes.buffer.asUint8List();

    PointAnnotationOptions pointAnnotationOptions = PointAnnotationOptions(
      geometry: point,
      image: imageData,
      iconSize: 0.3,
    );
    CircleAnnotationOptions circleAnnotationOptions = CircleAnnotationOptions(
      geometry: point,
      circleRadius: 30,
      circleOpacity: 0.5,
    );
    await pointAnnotationManager?.deleteAll();
    await circleAnnotationManager?.deleteAll();
    await circleAnnotationManager?.create(circleAnnotationOptions);
    await pointAnnotationManager?.create(pointAnnotationOptions);

  }

  Future<void> _setupPositionTracking() async {
    bool servicesEnabled;
    geo.LocationPermission permission;
    servicesEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return Future.error('Location services are disabled.');
    }
    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    geo.LocationSettings locationSettings = geo.LocationSettings(
      accuracy: geo.LocationAccuracy.high,
      distanceFilter: 100,
    );
    userPositionStream?.cancel();
    userPositionStream = geo.Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((geo.Position position) {
      if (mapboxMapController != null && mapboxMapController != null) {
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
  }

  @override
  void dispose() {
    _hideOverlay();
    userPositionStream?.cancel();
    super.dispose();
  }
}
