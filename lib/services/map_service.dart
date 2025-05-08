import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapService {
  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<List<dynamic>> getSearchSuggestions(String query) async {
    if (query.isEmpty) return [];
    final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;
    final response = await http.get(
      Uri.parse(
        'https://api.mapbox.com/search/searchbox/v1/suggest?q=$query&session_token=${_generateSessionToken()}&access_token=$accessToken',
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['suggestions'] as List;
    }
    throw Exception('Failed to fetch suggestions');
  }

  Future<Map<String, dynamic>> retrievePlace(String mapboxId) async {
    final accessToken = dotenv.env['MAPBOX_ACCESS_TOKEN']!;
    final response = await http.get(
      Uri.parse(
        'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId?session_token=${_generateSessionToken()}&access_token=$accessToken',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to retrieve place');
  }

  Future<LineString?> getRoute(Point origin, Point destination) async {
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
}
