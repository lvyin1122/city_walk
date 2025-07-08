import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mambo/services/graphql_service.dart';
import 'dart:math';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

class WalkSummary extends StatefulWidget {
  final String walkId;
  final List<dynamic> locations;
  final int locationsCollected;
  final int tasksCompleted;
  final String timeSpent;
  final double distanceWalked;
  final List<LatLng> locationPoints;

  const WalkSummary({
    super.key,
    required this.walkId,
    required this.locations,
    required this.locationsCollected,
    required this.tasksCompleted,
    required this.timeSpent,
    required this.distanceWalked,
    required this.locationPoints,
  });

  @override
  State<WalkSummary> createState() => _WalkSummaryState();
}

class _WalkSummaryState extends State<WalkSummary> {
  final GraphQLService _graphQLService = GraphQLService();
  List<String> _imageUrls = [];
  bool _isLoading = true;
  Set<Polyline> _pathPolylines = {};
  GoogleMapController? _mapController;
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSaving = false;
  final GlobalKey _contentKey = GlobalKey();
  String? _walkSummary;

  @override
  void initState() {
    super.initState();
    _fetchImageUrls();
    _updatePathPolylines();
    _fetchWalkSummary();
  }

  void _updatePathPolylines() {
    if (widget.locationPoints.length < 2) return;

    setState(() {
      _pathPolylines = {
        Polyline(
          polylineId: const PolylineId('userPath'),
          points: widget.locationPoints,
          color: Colors.blue,
          width: 4,
        ),
      };
    });
  }

  LatLng _getMapCenter() {
    if (widget.locationPoints.isEmpty) {
      return LatLng(
        widget.locations[0]['coordinates']['latitude'],
        widget.locations[0]['coordinates']['longitude'],
      );
    }

    final firstPoint = widget.locationPoints.first;
    final lastPoint = widget.locationPoints.last;

    return LatLng(
      (firstPoint.latitude + lastPoint.latitude) / 2,
      (firstPoint.longitude + lastPoint.longitude) / 2,
    );
  }

  LatLngBounds _getBounds() {
    // Start with the first location point
    double minLat = widget.locations[0]['coordinates']['latitude'];
    double maxLat = widget.locations[0]['coordinates']['latitude'];
    double minLng = widget.locations[0]['coordinates']['longitude'];
    double maxLng = widget.locations[0]['coordinates']['longitude'];

    // Include all location points
    for (var location in widget.locations) {
      final lat = location['coordinates']['latitude'];
      final lng = location['coordinates']['longitude'];
      minLat = min(minLat, lat);
      maxLat = max(maxLat, lat);
      minLng = min(minLng, lng);
      maxLng = max(maxLng, lng);
    }

    // Include all tracking points
    for (var point in widget.locationPoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Add some padding to the bounds
    const double padding = 0.01; // approximately 1km
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final bounds = _getBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // 50 pixels padding
    );
  }

  Future<void> _fetchImageUrls() async {
    try {
      final result = await _graphQLService.getAllTasksImageUrls(
        walkId: widget.walkId,
      );
      setState(() {
        _imageUrls = List<String>.from(
          result['data']['getAllTasksImageUrls']['imageUrls'],
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load images: $e')));
      }
    }
  }

  Future<void> _fetchWalkSummary() async {
    try {
      final result = await _graphQLService.generateWalkSummary(
        walkId: widget.walkId,
      );
      setState(() {
        _walkSummary = result['data']['generateWalkSummary']['summary'];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load walk summary: $e')),
        );
      }
    }
  }

  Future<void> _saveScreenshot() async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Request storage permission
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('Storage permission is required to save screenshots');
        }
      } else if (Platform.isIOS) {
        // Request photo library permissions
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          if (mounted) {
            // Show a dialog explaining why we need the permission
            final shouldOpenSettings = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Photo Library Access Required'),
                    content: const Text(
                      'This app needs access to your photo library to save walk summaries and photos. Please grant full access in Settings.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );

            if (shouldOpenSettings == true) {
              await openAppSettings();
            }
          }
          throw Exception(
            'Photo library permission is required to save screenshots',
          );
        }
      }

      // Wait for the next frame to ensure all content is rendered
      await Future.delayed(const Duration(milliseconds: 100));

      // Capture the screenshot with full height
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );

      if (imageBytes == null) {
        throw Exception('Failed to capture screenshot');
      }

      // Save to gallery
      final result = await ImageGallerySaver.saveImage(
        imageBytes,
        quality: 100,
        name: "walk_summary_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screenshot saved to gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save screenshot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Screenshot(
        controller: _screenshotController,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
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
                const SizedBox(height: 24),

                // // Save Screenshot Button
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 16),
                //   child: ElevatedButton.icon(
                //     onPressed: _isSaving ? null : _saveScreenshot,
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.blue,
                //       padding: const EdgeInsets.symmetric(
                //         horizontal: 24,
                //         vertical: 12,
                //       ),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(12),
                //       ),
                //     ),
                //     icon:
                //         _isSaving
                //             ? const SizedBox(
                //               width: 20,
                //               height: 20,
                //               child: CircularProgressIndicator(
                //                 strokeWidth: 2,
                //                 valueColor: AlwaysStoppedAnimation<Color>(
                //                   Colors.white,
                //                 ),
                //               ),
                //             )
                //             : const Icon(Icons.save_alt, color: Colors.white),
                //     label: Text(
                //       _isSaving ? 'Saving...' : 'Save Summary',
                //       style: const TextStyle(
                //         color: Colors.white,
                //         fontSize: 16,
                //         fontWeight: FontWeight.bold,
                //       ),
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 24),

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
                            '${widget.locationsCollected}/${widget.locations.length}',
                          ),
                          const Divider(),
                          _buildStatRow(
                            context,
                            Icons.task_alt,
                            Colors.green,
                            'Tasks',
                            '${widget.tasksCompleted}',
                          ),
                          const Divider(),
                          _buildStatRow(
                            context,
                            Icons.timer,
                            Colors.purple,
                            'Time',
                            widget.timeSpent,
                          ),
                          const Divider(),
                          _buildStatRow(
                            context,
                            Icons.directions_walk,
                            Colors.orange,
                            'Distance',
                            '${widget.distanceWalked.toStringAsFixed(1)} km',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Walk Summary Block
                if (_walkSummary != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Scrollbar(
                          thumbVisibility: true, // Always show scrollbar
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.format_quote,
                                        color: Theme.of(context).primaryColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Your Walk Story',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _walkSummary!,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_walkSummary == null)
                  const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 24),

                // Map Preview
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _getMapCenter(),
                          zoom: 10,
                        ),
                        markers:
                            widget.locations
                                .map(
                                  (location) => Marker(
                                    markerId: MarkerId(location['name']),
                                    position: LatLng(
                                      location['coordinates']['latitude'],
                                      location['coordinates']['longitude'],
                                    ),
                                    icon:
                                        widget.locationsCollected > 0 &&
                                                widget.locations.indexOf(
                                                      location,
                                                    ) <
                                                    widget.locationsCollected
                                            ? BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor.hueGreen,
                                            )
                                            : BitmapDescriptor.defaultMarker,
                                  ),
                                )
                                .toSet(),
                        polylines: _pathPolylines,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                          _fitBounds();
                        },
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
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_imageUrls.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No photos taken during this walk',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: _imageUrls.length,
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _imageUrls[index],
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Back to Home Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
