import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'onboarding_screen.dart';
import '../view_models/home_view_model.dart';

class WelcomeCarouselScreen extends ConsumerStatefulWidget {
  const WelcomeCarouselScreen({super.key});

  @override
  ConsumerState<WelcomeCarouselScreen> createState() =>
      _WelcomeCarouselScreenState();
}

class _WelcomeCarouselScreenState extends ConsumerState<WelcomeCarouselScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          _buildWelcomeCard(
            title: 'Welcome to Trekly',
            description:
                'Discover cities with AI-guided tours and serendipitous exploration.',
            image: Icons.explore,
          ),
          _buildWelcomeCard(
            title: 'Permissions Needed',
            description:
                'We need location and microphone access to provide real-time guidance and voice interactions.',
            image: Icons.security,
            buttonText: 'Grant Permissions',
          ),
          _buildProfileQuizCard(context),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentPage > 0)
              TextButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Back'),
              )
            else
              const SizedBox(),
            ElevatedButton(
              onPressed: () {
                if (_currentPage < 2) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OnboardingScreen(),
                    ),
                  );
                }
              },
              child: Text(_currentPage < 2 ? 'Next' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard({
    required String title,
    required String description,
    required IconData image,
    String? buttonText,
    VoidCallback? onButtonPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(image, size: 100, color: Theme.of(context).primaryColor),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onButtonPressed,
                child: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileQuizCard(BuildContext context) {
    final viewModel = ref.watch(homeViewModelProvider);
    final interests = ['History', 'Food', 'Kid-Friendly', 'Art', 'Safety+'];
    final walkingSpeeds = ['Leisurely', 'Moderate', 'Power Walk'];
    List<String> selectedInterests = [];
    String? selectedSpeed;

    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Tell Us About You',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Select your interests and walking speed to personalize your experience.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text(
                'Interests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8.0,
                children:
                    interests.map((interest) {
                      return ChoiceChip(
                        label: Text(interest),
                        selected: selectedInterests.contains(interest),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedInterests.add(interest);
                            } else {
                              selectedInterests.remove(interest);
                            }
                          });
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Walking Speed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                hint: const Text('Select Walking Speed'),
                value: selectedSpeed,
                items:
                    walkingSpeeds.map((speed) {
                      return DropdownMenuItem(value: speed, child: Text(speed));
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSpeed = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    selectedInterests.isNotEmpty && selectedSpeed != null
                        ? () {
                          // Save preferences to HomeViewModel
                          viewModel.setUserPreferences(
                            interests: selectedInterests,
                            walkingSpeed: selectedSpeed!,
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OnboardingScreen(),
                            ),
                          );
                        }
                        : null,
                child: const Text('Save Preferences'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
