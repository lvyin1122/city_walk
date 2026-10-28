import 'package:flutter/material.dart';

import 'features/auth/sign_in_page.dart';
import 'features/auth/sign_up_page.dart';
import 'theme/tokens.dart';
import 'widgets/botanical.dart';
import 'widgets/fresh_surface.dart';

/// First screen for signed-out users: a quiet welcome and two ways in.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder:
                (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        FreshSpace.page + 8,
                        FreshSpace.section,
                        FreshSpace.page,
                        FreshSpace.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Align(
                                alignment: Alignment(0.55, 0),
                                child: Botanical(kind: BotanicalKind.sprig, size: 96),
                              ),
                              const SizedBox(height: FreshSpace.xxl),
                              Text('Mambo 漫步', style: text.displaySmall),
                              const SizedBox(height: FreshSpace.md),
                              Text(
                                '在熟悉的城市里，\n慢慢走，留意那些被忽略的细节。',
                                style: text.bodyLarge!.copyWith(color: FreshColors.body),
                              ),
                            ],
                          ),
                          const SizedBox(height: FreshSpace.section),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(builder: (context) => const SignUpPage()),
                                    ),
                                child: const Text('我是新用户'),
                              ),
                              const SizedBox(height: FreshSpace.md),
                              OutlinedButton(
                                onPressed:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(builder: (context) => const SignInPage()),
                                    ),
                                child: const Text('我已有账号'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}
