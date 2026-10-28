import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:mambo/services/auth_service.dart';
import 'package:mambo/splash_screen.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';

/// The "我的" tab: who is signed in, about, and signing out.
class UserProfile extends StatelessWidget {
  const UserProfile({super.key});

  AuthService get _authService => AuthService();

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
      MaterialPageRoute<void>(builder: (context) => const SplashScreen()),
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
    final name = currentUser?.userMetadata?['name'] as String?;
    final text = context.text;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FreshSpace.page + 8,
        FreshSpace.section * 0.6,
        FreshSpace.page,
        FreshSpace.xxl,
      ),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              right: FreshSpace.lg,
              top: -FreshSpace.md,
              child: Botanical(kind: BotanicalKind.ginkgo, size: 80, opacity: 0.7),
            ),
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: FreshColors.tint(FreshColors.powder, 0.5),
                    border: FreshBorders.all,
                    image:
                        avatarUrl == null
                            ? null
                            : DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover),
                  ),
                  child:
                      avatarUrl == null
                          ? const Icon(Icons.person_outline, size: 32, color: FreshColors.inkSoft)
                          : null,
                ),
                const SizedBox(width: FreshSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty ? '未设置姓名' : name,
                        style: text.headlineSmall,
                      ),
                      const SizedBox(height: FreshSpace.xs),
                      Text(currentUser?.email ?? '未设置邮箱', style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: FreshSpace.section * 0.6),
        FreshCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('关于'),
                onTap: () => _showAbout(context),
              ),
              const Divider(height: 1, indent: FreshSpace.lg, endIndent: FreshSpace.lg),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('退出登录'),
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
