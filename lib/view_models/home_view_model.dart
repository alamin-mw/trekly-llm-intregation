import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:Trekly/model/tour_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import '../services/map_service.dart';
import '../services/location_service.dart';
import 'dart:math' as math;

final homeViewModelProvider = ChangeNotifierProvider<HomeViewModel>((ref) {
  return HomeViewModel();
});

class HomeViewModel extends ChangeNotifier {
  final MapService _mapService;
  final LocationService _locationService;

  MapboxMap? _mapboxMapController;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;
  List<dynamic> _suggestions = [];
  bool _isLoadingVoice = false;
  final AudioPlayer player = AudioPlayer();
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final StreamController<double> _stylePackProgress =
      StreamController.broadcast();
  final StreamController<double> _tileRegionLoadProgress =
      StreamController.broadcast();
  TileStore? _tileStore;
  OfflineManager? _offlineManager;
  final String _tileRegionId = "my-tile-region";
  bool _isOfflineMapDownloaded = false;

  Stream<double> get stylePackProgress => _stylePackProgress.stream;
  Stream<double> get tileRegionLoadProgress => _tileRegionLoadProgress.stream;
  bool get isOfflineMapDownloaded => _isOfflineMapDownloaded;

  final List<TourLocation> _tourLocations = [
    TourLocation(
      name: 'Eiffel Tower',
      coordinates: Position(2.2945, 48.8584),
      description: 'The iconic symbol of Paris, France, built in 1889.',
    ),
    TourLocation(
      name: 'Colosseum',
      coordinates: Position(12.4924, 41.8902),
      description: 'Ancient amphitheater in Rome, Italy',
    ),
    TourLocation(
      name: 'Taj Mahal',
      coordinates: Position(78.0421, 27.1751),
      description: 'Beautiful mausoleum in Agra, India',
    ),
  ];
  int _currentTourStop = 0;
  bool _isTourActive = false;

  HomeViewModel({MapService? mapService, LocationService? locationService})
    : _mapService = mapService ?? MapService(),
      _locationService = locationService ?? LocationService() {
    _setupPositionTracking();
  }

  List<dynamic> get suggestions => _suggestions;
  bool get isTourActive => _isTourActive;
  int get currentTourStop => _currentTourStop;
  List<TourLocation> get tourLocations => _tourLocations;

  void setMapController(MapboxMap mapboxMap) async {
    _mapboxMapController = mapboxMap;
    try {
      _pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      _circleAnnotationManager =
          await mapboxMap.annotations.createCircleAnnotationManager();
      _polylineAnnotationManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      await mapboxMap.location.updateSettings(
        LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    } catch (e) {
      debugPrint('Error initializing annotations: $e');
    }
    notifyListeners();
  }

  Future<void> initOfflineMap() async {
    try {
      _offlineManager = await OfflineManager.create();
      _tileStore = await TileStore.createDefault();
      _tileStore?.setDiskQuota(null); // Reset disk quota to default
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to initialize offline map: $e';
      notifyListeners();
    }
  }

  Future<void> downloadStylePack() async {
    try {
      final stylePackLoadOptions = StylePackLoadOptions(
        glyphsRasterizationMode:
            GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
        metadata: {"tag": "test"},
        acceptExpired: false,
      );
      await _offlineManager
          ?.loadStylePack(
            MapboxStyles.DARK, // Match your map style
            stylePackLoadOptions,
            (progress) {
              final percentage =
                  progress.completedResourceCount /
                  progress.requiredResourceCount;
              if (!_stylePackProgress.isClosed) {
                _stylePackProgress.sink.add(percentage);
              }
            },
          )
          .then((value) {
            _stylePackProgress.sink.add(1);
            if (!_stylePackProgress.isClosed) {
              _stylePackProgress.sink.close();
            }
          });
    } catch (e) {
      _errorMessage = 'Failed to download style pack: $e';
      notifyListeners();
    }
  }

  // Download tile region
  Future<void> downloadTileRegion(Point center) async {
    try {
      final tileRegionLoadOptions = TileRegionLoadOptions(
        geometry:
            center
                .toJson(), // Center on specified point (e.g., user location or tour location)
        descriptorsOptions: [
          TilesetDescriptorOptions(
            styleURI: MapboxStyles.DARK, // Match your map style
            minZoom: 0,
            maxZoom: 16,
          ),
        ],
        acceptExpired: true,
        networkRestriction: NetworkRestriction.NONE,
      );

      await _tileStore
          ?.loadTileRegion(_tileRegionId, tileRegionLoadOptions, (progress) {
            final percentage =
                progress.completedResourceCount /
                progress.requiredResourceCount;
            if (!_tileRegionLoadProgress.isClosed) {
              _tileRegionLoadProgress.sink.add(percentage);
            }
          })
          .then((value) {
            _tileRegionLoadProgress.sink.add(1);
            _isOfflineMapDownloaded = true;
            if (!_tileRegionLoadProgress.isClosed) {
              _tileRegionLoadProgress.sink.close();
            }
            notifyListeners();
          });
    } catch (e) {
      _errorMessage = 'Failed to download tile region: $e';
      notifyListeners();
    }
  }

  // Clean up offline resources
  Future<void> removeTileRegionAndStylePack() async {
    try {
      await _tileStore?.removeRegion(_tileRegionId);
      _tileStore?.setDiskQuota(0); // Clear predictive cache
      await _offlineManager?.removeStylePack(MapboxStyles.DARK);
      _isOfflineMapDownloaded = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to clean up offline resources: $e';
      notifyListeners();
    }
  }

  void setUserPreferences({
    required List<String> interests,
    required String walkingSpeed,
  }) {}
  // Start offline map download for a specific location
  Future<void> startOfflineDownload(Point center) async {
    await initOfflineMap();
    await downloadStylePack();
    await downloadTileRegion(center);
    await OfflineSwitch.shared.setMapboxStackConnected(
      false,
    ); // Simulate offline mode
  }

  Future<void> searchPlaces(String query) async {
    try {
      _suggestions = await _mapService.getSearchSuggestions(query);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  Future<void> selectSuggestion(dynamic suggestion) async {
    try {
      final data = await _mapService.retrievePlace(suggestion['mapbox_id']);
      final coordinates = data['features'][0]['geometry']['coordinates'];
      final point = Point(
        coordinates: Position(coordinates[0], coordinates[1]),
      );
      _mapboxMapController?.flyTo(
        CameraOptions(center: point, zoom: 15, bearing: 180, pitch: 30),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
      await _handleMapTap(point, placeData: data);
    } catch (e) {
      debugPrint('Error selecting suggestion: $e');
    }
  }

  Future<void> centerOnUserLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final point = Point(
        coordinates: Position(position.longitude, position.latitude),
      );
      _mapboxMapController?.flyTo(
        CameraOptions(center: point, zoom: 15),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
    } catch (e) {
      debugPrint('Error centering on user location: $e');
    }
  }

  void setIsLoadingVoice(bool value) {
    _isLoadingVoice = value;
    notifyListeners();
  }

  void startTour() {
    _isTourActive = true;
    _currentTourStop = 0;
    _navigateToTourLocation(_currentTourStop);
    notifyListeners();
  }

  void nextTourStop() {
    if (_currentTourStop < _tourLocations.length - 1) {
      _currentTourStop++;
      _navigateToTourLocation(_currentTourStop);
      notifyListeners();
    }
  }

  void previousTourStop() {
    if (_currentTourStop > 0) {
      _currentTourStop--;
      _navigateToTourLocation(_currentTourStop);
      notifyListeners();
    }
  }

  void endTour() {
    _isTourActive = false;
    _hideOverlay();
    notifyListeners();
  }

  Future<void> flyToUserLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final point = Point(
        coordinates: Position(position.longitude, position.latitude),
      );
      _mapboxMapController?.flyTo(
        CameraOptions(center: point, zoom: 15, bearing: 0, pitch: 0),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
    } catch (e) {
      debugPrint('Error flying to user location: $e');
    }
  }

  Future<void> playTextToSpeech(String text) async {
    print("Playing text to speech: $text");
    setIsLoadingVoice(true);
    final apiKey = dotenv.env['ELEVEN_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setIsLoadingVoice(false);
      _errorMessage = 'ElevenLabs API key is not set';
      notifyListeners();
      throw Exception('ElevenLabs API key is not set');
    }

    const voiceRachel = '21m00Tcm4TlvDq8ikWAM';
    const url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceRachel';
    print("Request URL: $url");

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'accept': 'audio/mpeg',
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          "text": text,
          "model_id": "eleven_monolingual_v1",
          "voice_settings": {"stability": 0.15, "similarity_boost": 0.75},
        }),
      );

      print("API Response Status: ${response.statusCode}");
      print("API Response Headers: ${response.headers}");
      print("API Response Body Length: ${response.bodyBytes.length}");

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isEmpty) {
          throw Exception('Received empty audio data from API');
        }

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await tempFile.writeAsBytes(bytes);
        print("Saved audio to: ${tempFile.path}");

        await player.stop();
        await player.setAudioSource(AudioSource.file(tempFile.path));
        await player.play();

        // Clean up temporary file after playback
        player.playbackEventStream.listen((event) {
          if (event.processingState == ProcessingState.completed) {
            tempFile.delete().then(
              (_) => print("Deleted temp file: ${tempFile.path}"),
            );
          }
        }, onError: (e) => print("Playback error: $e"));
      } else {
        String errorMessage;
        switch (response.statusCode) {
          case 401:
            errorMessage = 'Invalid ElevenLabs API key';
            break;
          case 429:
            errorMessage = 'API rate limit exceeded';
            break;
          default:
            errorMessage = 'Failed to load audio: ${response.statusCode}';
        }
        print("API Error: $errorMessage, Body: ${response.body}");
        _errorMessage = errorMessage;
        notifyListeners();
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Error in playTextToSpeech: $e");
      _errorMessage = 'Failed to play audio: $e';
      notifyListeners();
      throw Exception('Failed to play audio: $e');
    } finally {
      setIsLoadingVoice(false);
    }
  }

  Future<void> activateWanderMode() async {
    try {
      print('Finding landmark');
      final position = await _locationService.getCurrentPosition();
      TourLocation? nearestLandmark;
      double minDistance = double.infinity;
      for (var landmark in _tourLocations) {
        final distance = geo.Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          landmark.coordinates.lat.toDouble(),
          landmark.coordinates.lng.toDouble(),
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestLandmark = landmark;
        }
      }
      if (nearestLandmark == null) {
        _errorMessage = 'No landmarks available';
        notifyListeners();
        throw Exception('No landmarks available');
      }

      final targetPoint = Point(coordinates: nearestLandmark.coordinates);
      String guidanceText;
      Map<String, dynamic> placeData = {
        'features': [
          {
            'properties': {
              'name': nearestLandmark.name,
              'full_address': nearestLandmark.description,
            },
          },
        ],
      };

      Point destination;
      if (minDistance <= 200.0) {
        destination = targetPoint;
        guidanceText =
            'You are near the ${nearestLandmark.name}. ${nearestLandmark.description} Follow the path to explore.';
      } else {
        destination = await _getPointCloser(
          position,
          nearestLandmark.coordinates,
          minDistance,
        );
        guidanceText =
            'You are ${minDistance.round()} meters from the ${nearestLandmark.name}. '
            'Follow the route to get closer to ${nearestLandmark.description}';
      }

      try {
        await playTextToSpeech(guidanceText);
      } catch (e) {
        debugPrint('Error playing TTS in Wander Mode: $e');
        _errorMessage = 'Failed to play audio guidance: $e';
        notifyListeners();
      }

      await _startNavigation(position, destination);
      _showOverlay(destination, placeData: placeData);
    } catch (e) {
      debugPrint('Error in Wander Mode: $e');
      _errorMessage = 'Wander Mode error: $e';
      notifyListeners();
    }
  }

  Future<void> handleMapTap(
    Point point, {
    Map<String, dynamic>? placeData,
  }) async {
    await _handleMapTap(point, placeData: placeData);
  }

  void _showOverlay(Point point, {Map<String, dynamic>? placeData}) {
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

    _isOverlayVisible = true;
    notifyListeners();
  }

  void _hideOverlay() {
    if (_isOverlayVisible) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _isOverlayVisible = false;
    }
    notifyListeners();
  }

  Future<void> _handleMapTap(
    Point point, {
    Map<String, dynamic>? placeData,
  }) async {
    if (_pointAnnotationManager == null) return;
    try {
      final ByteData bytes = await rootBundle.load('assets/custom-icon.png');
      final Uint8List imageData = bytes.buffer.asUint8List();
      await _pointAnnotationManager?.deleteAll();
      await _circleAnnotationManager?.deleteAll();
      await _pointAnnotationManager?.create(
        PointAnnotationOptions(
          geometry: point,
          image: imageData,
          iconSize: 0.3,
        ),
      );
      await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: point,
          circleRadius: 30,
          circleColor: Colors.blue.value,
          circleOpacity: 0.5,
          circleStrokeWidth: 2,
          circleStrokeColor: Colors.white.value,
        ),
      );
      _showOverlay(point, placeData: placeData);
    } catch (e) {
      debugPrint('Error handling map tap: $e');
      _errorMessage = 'Failed to handle map tap: $e';
      notifyListeners();
    }
  }

  void _navigateToTourLocation(int index) {
    if (index >= 0 && index < _tourLocations.length) {
      final location = _tourLocations[index];
      final point = Point(coordinates: location.coordinates);
      _mapboxMapController?.flyTo(
        CameraOptions(center: point, zoom: 15, bearing: 180, pitch: 30),
        MapAnimationOptions(duration: 2000, startDelay: 0),
      );
      _handleMapTap(
        point,
        placeData: {
          'features': [
            {
              'properties': {
                'name': location.name,
                'full_address': location.description,
              },
            },
          ],
        },
      );
    }
  }

  void _setupPositionTracking() {
    _locationService.startPositionTracking((position) {
      if (_mapboxMapController != null && !_isTourActive) {
        _mapboxMapController?.setCamera(
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

  Future<Point> _getPointCloser(
    geo.Position current,
    Position target,
    double distance,
  ) async {
    final route = await _mapService.getRoute(
      Point(coordinates: Position(current.longitude, current.latitude)),
      Point(coordinates: target),
    );

    if (route != null && route.coordinates.isNotEmpty) {
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
      return Point(coordinates: route.coordinates.last);
    }

    final bearing = geo.Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      target.lat.toDouble(),
      target.lng.toDouble(),
    );
    const earthRadius = 6371000.0;
    final distanceToTravel = distance - 200.0;
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
    if (_mapboxMapController == null || _pointAnnotationManager == null) return;

    await _pointAnnotationManager?.deleteAll();
    await _circleAnnotationManager?.deleteAll();
    await _polylineAnnotationManager?.deleteAll();

    final userPoint = Point(
      coordinates: Position(position.longitude, position.latitude),
    );
    final userIconBytes = await rootBundle.load('assets/user-icon.png');
    final userIconData = userIconBytes.buffer.asUint8List();
    await _pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: userPoint,
        image: userIconData,
        iconSize: 0.3,
      ),
    );

    final destIconBytes = await rootBundle.load('assets/custom-icon.png');
    final destIconData = destIconBytes.buffer.asUint8List();
    await _pointAnnotationManager?.create(
      PointAnnotationOptions(
        geometry: destination,
        image: destIconData,
        iconSize: 0.3,
      ),
    );

    final route = await _mapService.getRoute(userPoint, destination);
    if (route != null) {
      await _polylineAnnotationManager?.create(
        PolylineAnnotationOptions(
          geometry: route,
          lineColor: Colors.blue.value,
          lineWidth: 5.0,
          lineOpacity: 0.8,
        ),
      );
    }

    _mapboxMapController?.flyTo(
      CameraOptions(center: userPoint, zoom: 15, bearing: 0, pitch: 0),
      MapAnimationOptions(duration: 2000, startDelay: 0),
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stylePackProgress.close();
    _tileRegionLoadProgress.close();
    player.dispose();
    _hideOverlay();
    _locationService.stopPositionTracking();
    super.dispose();
  }
}

class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  final String contentType;

  MyCustomSource(this.bytes, {this.contentType = 'audio/mpeg'}) {
    print(
      "MyCustomSource initialized with ${bytes.length} bytes, contentType: $contentType",
    );
    if (bytes.isEmpty) {
      throw Exception('Audio source bytes cannot be empty');
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    if (start < 0 || end > bytes.length || start > end) {
      throw Exception('Invalid byte range: $start-$end');
    }
    print("MyCustomSource request: $start-$end, total length: ${bytes.length}");
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: contentType,
    );
  }
}
