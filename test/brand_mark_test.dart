import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yolyoldasi/core/theme/app_theme.dart';
import 'package:yolyoldasi/core/widgets/brand_mark.dart';

/// The logo shipped stretched into a rectangle once, because a `ListView`
/// hands its children a tight width. It has to stay square under any
/// constraints its parent imposes.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );

  Size markSize(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(BrandMark),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );

  testWidgets('stays square inside a ListView', (tester) async {
    await tester.pumpWidget(
      wrap(ListView(children: const [BrandMark(size: 56)])),
    );

    expect(markSize(tester), const Size(56, 56));
  });

  testWidgets('stays square inside a stretched Column', (tester) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [BrandMark(size: 40)],
        ),
      ),
    );

    expect(markSize(tester), const Size(40, 40));
  });

  testWidgets('shrink-wraps inside a Row', (tester) async {
    await tester.pumpWidget(
      wrap(const Row(children: [BrandMark(size: 30), Text('Yol Yoldaşı')])),
    );

    expect(tester.getSize(find.byType(BrandMark)), const Size(30, 30));
  });
}
