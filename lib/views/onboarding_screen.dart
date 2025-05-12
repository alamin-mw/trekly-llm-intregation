import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../view_models/home_view_model.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(homeViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Download Offline Map',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextButton(
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.blue),
              ),
              onPressed: () async {
                // Use a tour location or user location as the center
                final center =
                    viewModel.tourLocations.isNotEmpty
                        ? Point(
                          coordinates: viewModel.tourLocations[0].coordinates,
                        )
                        : Point(
                          coordinates: Position(0, 0),
                        ); // Fallback or get user location
                await viewModel.startOfflineDownload(center);
              },
              child: const Text('Start Download'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 100,
              width: 300,
              child: Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StreamBuilder<double>(
                      stream: viewModel.stylePackProgress,
                      initialData: 0.0,
                      builder: (context, snapshot) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Style Pack: ${(snapshot.data! * 100).toStringAsFixed(0)}%',
                            ),
                            LinearProgressIndicator(value: snapshot.data),
                          ],
                        );
                      },
                    ),
                    StreamBuilder<double>(
                      stream: viewModel.tileRegionLoadProgress,
                      initialData: 0.0,
                      builder: (context, snapshot) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tile Region: ${(snapshot.data! * 100).toStringAsFixed(0)}%',
                            ),
                            LinearProgressIndicator(value: snapshot.data),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  viewModel.isOfflineMapDownloaded
                      ? () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      }
                      : null,
              child: const Text('Proceed to Map'),
            ),
          ],
        ),
      ),
    );
  }
}
