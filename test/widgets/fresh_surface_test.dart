import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mambo/widgets/fresh_surface.dart';

void main() {
  testWidgets('a ListTile inside a FreshCard keeps its ink visible', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FreshCard(
            padding: EdgeInsets.zero,
            child: ListTile(title: const Text('关于'), onTap: () => taps++),
          ),
        ),
      ),
    );

    // ListTile reports an error when a coloured box sits between it and the
    // nearest Material.
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
