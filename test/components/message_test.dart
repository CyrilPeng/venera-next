import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/components/message.dart';

void main() {
  testWidgets('showToast stacks multiple messages without overlap', (
    tester,
  ) async {
    late BuildContext toastContext;

    await tester.pumpWidget(
      MaterialApp(
        home: OverlayWidget(
          Builder(
            builder: (context) {
              toastContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showToast(message: 'First toast', context: toastContext, seconds: 1);
    showToast(message: 'Second toast', context: toastContext, seconds: 1);
    await tester.pump();

    final firstRect = tester.getRect(find.text('First toast'));
    final secondRect = tester.getRect(find.text('Second toast'));

    expect(firstRect.overlaps(secondRect), isFalse);
    expect(firstRect.top, lessThan(secondRect.top));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('First toast'), findsNothing);
    expect(find.text('Second toast'), findsNothing);
  });
}
