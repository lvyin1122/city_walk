import 'walk_history_detail.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/graphql_service.dart';
import 'package:intl/intl.dart';
import '../../walk/walk_summary.dart';
import 'utils.dart';

class WalkHistoryPage extends StatefulWidget {
  @override
  _WalkHistoryPageState createState() => _WalkHistoryPageState();
}

class _WalkHistoryPageState extends State<WalkHistoryPage> {
  final GraphQLService _graphQLService = GraphQLService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _completedWalks = [];

  @override
  void initState() {
    super.initState();
    _fetchCompletedWalks();
  }

  Future<void> _fetchCompletedWalks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = AuthService().getCurrentUser();
      if (user == null) {
        setState(() {
          _error = '用户未登录。';
          _isLoading = false;
        });
        return;
      }
      final result = await _graphQLService.getCompletedWalks(userId: user.id);
      final walks = result['data']?['completedWalksByUserId'] ?? [];
      // Sort walks by createdAt descending (latest first)
      walks.sort((a, b) {
        final aDate = a['createdAt'] != null ? DateTime.tryParse(a['createdAt']) : null;
        final bDate = b['createdAt'] != null ? DateTime.tryParse(b['createdAt']) : null;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      setState(() {
        _completedWalks = walks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载已完成的步行失败：$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('步行历史', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_error!, style: AppTextStyles.bodyText1),
                  ),
                )
              : _completedWalks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('暂无已完成的步行。', style: AppTextStyles.bodyText1),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchCompletedWalks,
                      child: ListView.builder(
                        itemCount: _completedWalks.length,
                        itemBuilder: (context, index) {
                          final walk = _completedWalks[index];
                          // Parse date and time
                          DateTime? createdAt = walk['createdAt'] != null ? DateTime.tryParse(walk['createdAt']) : null;
                          String dayOfWeek = createdAt != null ? [
                            'SUN', 'MON', 'TUES', 'WED', 'THU', 'FRI', 'SAT'][createdAt.weekday % 7] : 'N/A';
                          String dateStr = createdAt != null ? '${createdAt.month}/${createdAt.day}' : 'N/A';
                          String timeStr = createdAt != null ? DateFormat('h:mm a').format(createdAt.toLocal()) : 'N/A';
                          String timeSpent = walk['timeSpent'] != null 
                              ? formatDuration(int.parse(walk['timeSpent'].toString()))
                              : walk['totalDuration'] != null 
                                  ? formatDuration(int.parse(walk['totalDuration'].toString()))
                                  : 'N/A';
                          String distance = walk['distanceTraveled'] != null ? walk['distanceTraveled'].toStringAsFixed(1) + ' km' : 'N/A';
                          String userAddress = formatUserAddress(walk['userAddress']);
                          // Stats
                          int locationsCollected = 0;
                          if (walk['locations'] is List) {
                            locationsCollected = (walk['locations'] as List).where((loc) => loc['collected'] == true).length;
                          }
                          int tasksCompleted = walk['tasks'] is List ? (walk['tasks'] as List).where((t) => t['status'] == 'completed').length : 0;
                          int favoriteLocations = walk['favoriteLocations'] is List ? (walk['favoriteLocations'] as List).length : 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                            child: InkWell(
                              onTap: () {
                                // Navigate to WalkSummary, passing walk id and isNew: false
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WalkSummary(
                                      walkId: walk['id'] ?? walk['Id'],
                                      isNew: false,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                                child: Row(
                                  children: [
                                    // Left block (20%)
                                    Flexible(
                                      flex: 2,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text(dayOfWeek, style: AppTextStyles.headline4),
                                          Text(dateStr, style: AppTextStyles.headline5),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              Icon(Icons.timer, size: 16, color: AppColors.primaryColor),
                                              const SizedBox(width: 4),
                                              Text(timeSpent, style: AppTextStyles.bodyText2),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              Icon(Icons.social_distance, size: 16, color: AppColors.primaryColor),
                                              const SizedBox(width: 4),
                                              Text(distance, style: AppTextStyles.bodyText2),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Separator
                                    Container(
                                      width: 1,
                                      height: 100,
                                      color: AppColors.separatorColor,
                                      margin: const EdgeInsets.symmetric(horizontal: 12.0),
                                    ),
                                    // Middle block (70%)
                                    Flexible(
                                      flex: 7,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(timeStr, style: AppTextStyles.bodyText2),
                                            Text(
                                              '城市漫步于',
                                              style: AppTextStyles.bodyText2,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              userAddress,
                                              style: AppTextStyles.headline4,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.place, size: 24, color: AppColors.primaryColor),
                                                    const SizedBox(width: 4),
                                                    Text('$locationsCollected', style: AppTextStyles.bodyText1),
                                                  ],
                                                ),
                                                const SizedBox(width: 16),
                                                Row(
                                                  children: [
                                                    Icon(Icons.check_circle, size: 24, color: AppColors.primaryColor),
                                                    const SizedBox(width: 4),
                                                    Text('$tasksCompleted', style: AppTextStyles.bodyText1),
                                                  ],
                                                ),
                                                const SizedBox(width: 16),
                                                Row(
                                                  children: [
                                                    Icon(Icons.star, size: 24, color: AppColors.primaryColor),
                                                    const SizedBox(width: 4),
                                                    Text('$favoriteLocations', style: AppTextStyles.bodyText1),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
