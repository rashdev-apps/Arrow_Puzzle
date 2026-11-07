import 'package:arrow_puzzle/features/settings/presentation/arrow_gallery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arrow Gallery renders all 4 directions straight and bent', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ArrowGalleryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Arrow Gallery (Debug)'), findsOneWidget);
    expect(find.text('Straight Arrows (Up, Down, Left, Right)'), findsOneWidget);
    expect(find.text('Bent Arrows (Up, Down, Left, Right)'), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
  });
}
