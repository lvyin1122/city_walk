import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../services/log_service.dart';

class LogEntryDetailPage extends StatelessWidget {
  final LogEntry entry;

  const LogEntryDetailPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        DateFormat('EEEE, MMM d, yyyy · h:mm a').format(entry.timestamp.toLocal());
    final hasLocation = entry.lat != null && entry.lng != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back, color: AppColors.textColor, size: 22),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                entry.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.separatorColor,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 64),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Question (no section title)
                if (entry.question != null && entry.question!.isNotEmpty) ...[
                  Text(
                    entry.question!,
                    style: AppTextStyles.bodyText1.copyWith(
                      fontSize: 12,
                      height: 1.5,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Reflection text
                if (entry.description != null && entry.description!.isNotEmpty) ...[
                  Text(
                    'Reflection',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.description!,
                    style: AppTextStyles.bodyText1.copyWith(
                      fontSize: 17,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Address
                if (entry.address != null && entry.address!.isNotEmpty) ...[
                  Text(
                    'Location',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.secondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.address!,
                          style: AppTextStyles.bodyText1.copyWith(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                // Timestamp
                Text(
                  'Date & Time',
                  style: AppTextStyles.headline5.copyWith(
                    color: AppColors.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppColors.secondaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: AppTextStyles.bodyText2.copyWith(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Map
                if (hasLocation) ...[
                  Text(
                    'Map',
                    style: AppTextStyles.headline5.copyWith(
                      color: AppColors.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 220,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(entry.lat!, entry.lng!),
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('entry'),
                            position: LatLng(entry.lat!, entry.lng!),
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomGesturesEnabled: true,
                        scrollGesturesEnabled: true,
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
