import 'package:mambo/services/auth_service.dart';
import 'package:mambo/l10n/l10n.dart';
import 'package:mambo/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:mambo/services/app_locale_controller.dart';
import 'package:mambo/services/locale_controller_scope.dart';
import 'package:mambo/services/locale_preference_service.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class UserProfile extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();
    final localeController = LocaleControllerScope.of(context);
    final selectedMode = localeController.mode;

    print(currentUser?.userMetadata);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profile, style: AppTextStyles.headline2),
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
            backgroundImage: currentUser?.userMetadata?['avatar_url'] != null 
                ? NetworkImage(currentUser!.userMetadata?['avatar_url']!)
                : null,
            child: currentUser?.userMetadata?['avatar_url'] == null ? Icon(
              Icons.person,
              size: 50,
              color: AppColors.buttonTextColor,
            ) : null,
          ),
          SizedBox(height: 10),
          Text(
            currentUser?.userMetadata?['name'] ?? context.l10n.nameNotSet,
            style: AppTextStyles.headline2
          ),
          SizedBox(height: 4),
          Text(
            currentUser?.email ?? context.l10n.emailNotSet,
            style: AppTextStyles.bodyText1
          ),
          SizedBox(height: 20),
          // ElevatedButton(
          //   onPressed: () {
          //     // Handle edit profile logic
          //   },
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: AppColors.primaryColor,
          //   ),
          //   child: Text('Edit Profile', style: AppTextStyles.buttonTextWhite),
          // ),
          // SizedBox(height: 20),
          // menu items
          ListView(
            shrinkWrap: true,
            children: [
              // ListTile(
              //   leading: Icon(Icons.settings, color: AppColors.primaryColor),
              //   title: Text('Settings', style: AppTextStyles.bodyText1),
              //   onTap: () {
              //     // Handle settings tap
              //   },
              // ),
              // Divider(color: AppColors.primaryColor.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.language, color: AppColors.primaryColor),
                title: Text(context.l10n.language, style: AppTextStyles.bodyText1),
                subtitle: Text(_languageSubtitle(context, selectedMode)),
                onTap: () => _showLanguagePicker(context, localeController),
              ),
              Divider(color: AppColors.primaryColor.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.info, color: AppColors.primaryColor),
                title: Text(context.l10n.about, style: AppTextStyles.bodyText1),
                onTap: () {
                  // Handle information tap
                },
              ),
              Divider(color: AppColors.primaryColor.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.primaryColor),
                title: Text(context.l10n.signOut, style: AppTextStyles.bodyText1),
                onTap: () {
                  AuthService().signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => SplashScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _languageSubtitle(BuildContext context, AppLanguageMode mode) {
    switch (mode) {
      case AppLanguageMode.system:
        return context.l10n.followSystem;
      case AppLanguageMode.english:
        return context.l10n.english;
      case AppLanguageMode.chinese:
        return context.l10n.chinese;
    }
  }

  Future<void> _showLanguagePicker(
    BuildContext context,
    AppLocaleController localeController,
  ) async {
    final mode = await showModalBottomSheet<AppLanguageMode>(
      context: context,
      builder: (context) {
        final current = localeController.mode;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(context.l10n.followSystem),
                trailing: current == AppLanguageMode.system
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, AppLanguageMode.system),
              ),
              ListTile(
                title: Text(context.l10n.english),
                trailing: current == AppLanguageMode.english
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, AppLanguageMode.english),
              ),
              ListTile(
                title: Text(context.l10n.chinese),
                trailing: current == AppLanguageMode.chinese
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, AppLanguageMode.chinese),
              ),
            ],
          ),
        );
      },
    );

    if (mode != null) {
      await localeController.setMode(mode);
    }
  }
}
