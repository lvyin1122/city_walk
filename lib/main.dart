import 'package:mambo/theme/app_theme.dart';
import 'package:mambo/theme/tokens.dart';
import 'package:mambo/widgets/botanical.dart';
import 'package:mambo/widgets/fresh_surface.dart';
import 'package:mambo/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/env.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every screen is laid out for portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await initializeDateFormatting('zh_CN');
  Intl.defaultLocale = 'zh_CN';

  final missing = Env.missing;
  if (missing.isNotEmpty) {
    runApp(
      StartupErrorApp(
        title: '应用尚未完成配置',
        message:
            '构建时缺少以下配置：\n${missing.join('\n')}\n\n'
            '请使用 flutter run --dart-define-from-file=.env 运行。',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialisation failed: $e');
    runApp(
      const StartupErrorApp(
        title: '启动失败',
        message: '无法连接到账号服务，请检查网络后重新打开应用。',
      ),
    );
    return;
  }

  runApp(const MyApp());
}

/// Shown instead of the app when it cannot start, so the user never faces a
/// blank screen.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: PaperBackground(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(FreshSpace.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Botanical(kind: BotanicalKind.ginkgo, size: 64),
                        const SizedBox(height: FreshSpace.xl),
                        Text(title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: FreshSpace.md),
                        Text(message, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mambo 漫步',
      theme: AppTheme.light(),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Check and refresh session if needed
      await _authService.refreshSession();
      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _initialized = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.2)),
      );
    }

    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Check for persisted session first
        if (_authService.isAuthenticated()) {
          return const HomePage();
        }
        
        // Then check stream data
        if (snapshot.hasData) {
          final AuthState? authState = snapshot.data;
          if (authState?.event == AuthChangeEvent.signedIn) {
            return const HomePage();
          }
        }
        return const SplashScreen();
      },
    );
  }
}
