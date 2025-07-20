import 'package:mambo/services/auth_service.dart';
import 'package:mambo/splash_screen.dart';
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_colors.dart';

class UserProfile extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    print(currentUser?.userMetadata);

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: AppTextStyles.headline2),
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
            currentUser?.userMetadata?['name'] ?? 'No Name',
            style: AppTextStyles.headline2
          ),
          SizedBox(height: 4),
          Text(
            currentUser?.email ?? 'No Email',
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
                leading: Icon(Icons.info, color: AppColors.primaryColor),
                title: Text('Information', style: AppTextStyles.bodyText1),
                onTap: () {
                  // Handle information tap
                },
              ),
              Divider(color: AppColors.primaryColor.withOpacity(0.2)),
              ListTile(
                leading: Icon(Icons.logout, color: AppColors.primaryColor),
                title: Text('Logout', style: AppTextStyles.bodyText1),
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
}
