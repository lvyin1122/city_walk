import 'package:flutter/material.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/splash_screen.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class UserProfile extends StatelessWidget {
  UserProfile({super.key});

  final AuthService _authService = AuthService();

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('退出登录？'),
            content: const Text('退出后需要重新登录才能查看你的漫步记录。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('退出登录'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SplashScreen()),
      (route) => false,
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Mambo 漫步',
      children: const [Text('告诉 Mambo 你有多少时间、对什么感兴趣，它把你眼前的街区变成一场有小任务的城市漫步。')],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    final avatarUrl = currentUser?.userMetadata?['avatar_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text('个人资料', style: AppTextStyles.headline2),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.secondaryColor,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child:
                avatarUrl == null
                    ? Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.buttonTextColor,
                    )
                    : null,
          ),
          const SizedBox(height: 10),
          Text(
            currentUser?.userMetadata?['name'] ?? '未设置姓名',
            style: AppTextStyles.headline2,
          ),
          const SizedBox(height: 4),
          Text(currentUser?.email ?? '未设置邮箱', style: AppTextStyles.bodyText1),
          const SizedBox(height: 20),
          ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: Icon(Icons.info, color: AppColors.primaryColor),
                title: Text('关于', style: AppTextStyles.bodyText1),
                onTap: () => _showAbout(context),
              ),
              Divider(color: AppColors.primaryColor.withValues(alpha: 0.2)),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.primaryColor),
                title: Text('退出登录', style: AppTextStyles.bodyText1),
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
