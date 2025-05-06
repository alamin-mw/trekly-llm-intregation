import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State createState() => MyAppState();
  // This widget is the root of your application.
}

class MyAppState extends State<MyApp> {
  late MapboxMap mapboxMap;
  PointAnnotationManager? pointAnnotationManager;
  geo.Position? userLocation;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return;
      }
    }

    userLocation = await geo.Geolocator.getCurrentPosition();
    if (mounted) setState(() {});
  }

  @override
  _onMapCreated(MapboxMap mapboxMap) async {
    this.mapboxMap = mapboxMap;
    pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    if (userLocation != null) {
      PointAnnotationOptions pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            userLocation!.longitude,
            userLocation!.latitude,
          ),
        ),
        iconSize: 1.0,
      );

      pointAnnotationManager?.create(pointAnnotationOptions);
    }
    
  }

  @override
  Widget build(BuildContext context) {
    WidgetsFlutterBinding.ensureInitialized();

    String ACCESS_TOKEN = const String.fromEnvironment("ACCESS_TOKEN");
    MapboxOptions.setAccessToken(ACCESS_TOKEN);

    CameraOptions camera = CameraOptions(
      center: Point(
        coordinates: Position(
          userLocation?.longitude ?? 0.0,
          userLocation?.latitude ?? 0.0,
        ),
      ),
      zoom: 9.6,
      bearing: 0,
      pitch: 30,
    );

    return MaterialApp(
      title: 'Flutter Demo',
      home:
          userLocation == null
              ? Center(child: CircularProgressIndicator())
              : MapWidget(cameraOptions: camera, onMapCreated: _onMapCreated),
    );
  }
}
