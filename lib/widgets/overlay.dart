import 'package:flutter/material.dart';

class LocationOverlay extends StatelessWidget {
  final num latitude;
  final num longitude;
  final String? name;
  final String? address;
  final String? category;
  final Map<String, dynamic>? placeData;
  final VoidCallback onClose;

  const LocationOverlay({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
    this.category,
    this.placeData,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final feature = placeData?['features'][0];
    final properties = feature?['properties'];
    final contextData = properties?['context'];

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        color: Colors.black87,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name with close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      properties?['name'] ?? 'Unknown Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),

              // Full address
              if (properties?['full_address'] != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    properties!['full_address'],
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

              // Categories
              if (properties?['poi_category'] != null)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children:
                        (properties!['poi_category'] as List)
                            .map(
                              (category) => Chip(
                                label: Text(
                                  category.toString().toUpperCase(),
                                  style: TextStyle(fontSize: 12),
                                ),
                                backgroundColor: Colors.blue.withOpacity(0.3),
                                labelStyle: TextStyle(color: Colors.white),
                              ),
                            )
                            .toList(),
                  ),
                ),

              // Location details
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (contextData?['neighborhood']?['name'] != null)
                      Text(
                        'Neighborhood: ${contextData!['neighborhood']['name']}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    if (contextData?['place']?['name'] != null)
                      Text(
                        'City: ${contextData!['place']['name']}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    if (contextData?['region']?['name'] != null)
                      Text(
                        'State: ${contextData!['region']['name']}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    if (contextData?['country']?['name'] != null)
                      Text(
                        'Country: ${contextData!['country']['name']}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    SizedBox(height: 8),
                    Text(
                      'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
