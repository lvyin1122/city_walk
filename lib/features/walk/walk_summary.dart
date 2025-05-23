import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WalkSummary extends StatelessWidget {
  final String walkId;
  final List<dynamic> locations;
  final int locationsCollected;
  final int tasksCompleted;
  final int pointsEarned;
  final String timeSpent;
  final double distanceWalked;

  const WalkSummary({
    super.key,
    required this.walkId,
    required this.locations,
    required this.locationsCollected,
    required this.tasksCompleted,
    required this.pointsEarned,
    required this.timeSpent,
    required this.distanceWalked,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Congratulations Section
              const Icon(Icons.celebration, size: 80, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Congratulations!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'ve completed your walk',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),

              // Stats Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow(
                          context,
                          Icons.place,
                          Colors.blue,
                          'Locations',
                          '$locationsCollected/${locations.length}',
                        ),
                        const Divider(),
                        _buildStatRow(
                          context,
                          Icons.task_alt,
                          Colors.green,
                          'Tasks',
                          '$tasksCompleted',
                        ),
                        const Divider(),
                        _buildStatRow(
                          context,
                          Icons.stars,
                          Colors.amber,
                          'Points',
                          '$pointsEarned',
                        ),
                        const Divider(),
                        _buildStatRow(
                          context,
                          Icons.timer,
                          Colors.purple,
                          'Time',
                          timeSpent,
                        ),
                        const Divider(),
                        _buildStatRow(
                          context,
                          Icons.directions_walk,
                          Colors.orange,
                          'Distance',
                          '${distanceWalked.toStringAsFixed(1)} km',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Map Preview
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          locations[0]['coordinates']['latitude'],
                          locations[0]['coordinates']['longitude'],
                        ),
                        zoom: 12,
                      ),
                      markers:
                          locations
                              .map(
                                (location) => Marker(
                                  markerId: MarkerId(location['name']),
                                  position: LatLng(
                                    location['coordinates']['latitude'],
                                    location['coordinates']['longitude'],
                                  ),
                                ),
                              )
                              .toSet(),
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Photo Gallery
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Photos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: 6, // Placeholder count
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.photo,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
