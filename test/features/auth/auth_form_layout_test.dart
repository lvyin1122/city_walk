import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/features/auth/auth_form_layout.dart';

void main() {
  Widget buildForm() {
    return MaterialApp(
      home: Scaffold(
        body: AuthFormLayout(
          form: Column(
            children: [
              const Text('创建你的\n账户', style: TextStyle(fontSize: 36)),
              for (var i = 0; i < 4; i++) const TextField(),
              const SizedBox(height: 40),
              ElevatedButton(onPressed: () {}, child: const Text('注册')),
            ],
          ),
          footer: const Text('已有账户？'),
        ),
      ),
    );
  }

  testWidgets('does not overflow on a small screen with the keyboard open', (
    tester,
  ) async {
    // 320 x 568 logical pixels (iPhone SE, 1st gen) with a 300 px keyboard.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildForm());

    // A RenderFlex overflow is reported as an exception by the test binding.
    expect(tester.takeException(), isNull);
    expect(find.text('注册'), findsOneWidget);
  });

  testWidgets('pushes the footer to the bottom when there is room', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildForm());

    final footerBottom = tester.getBottomLeft(find.text('已有账户？')).dy;
    expect(footerBottom, greaterThan(800));
  });
}
