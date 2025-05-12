import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../view_models/home_view_model.dart';
import '../widgets/search.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _fabElevation = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(homeViewModelProvider);
    return Scaffold(
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: viewModel.setMapController,
            styleUri: MapboxStyles.DARK,
            onTapListener: (ctx) => viewModel.handleMapTap(ctx.point),
          ),
          MapSearchWidget(
            suggestions: viewModel.suggestions,
            onSearch: viewModel.searchPlaces,
            onSuggestionSelected: viewModel.selectSuggestion,
            onCenterUserLocation: viewModel.centerOnUserLocation,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!viewModel.isTourActive)
                  FloatingActionButton.extended(
                    onPressed: viewModel.startTour,
                    backgroundColor: Theme.of(context).primaryColor,
                    elevation: _fabElevation,
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
                                viewModel.currentTourStop > 0
                                    ? viewModel.previousTourStop
                                    : null,
                            color: Colors.white,
                          ),
                          Text(
                            '${viewModel.currentTourStop + 1}/${viewModel.tourLocations.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed:
                                viewModel.currentTourStop <
                                        viewModel.tourLocations.length - 1
                                    ? viewModel.nextTourStop
                                    : null,
                            color: Colors.white,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: viewModel.endTour,
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
                    onPressed: viewModel.flyToUserLocation,
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
                    onPressed: viewModel.activateWanderMode,
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
}
