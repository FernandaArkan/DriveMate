import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Diagnostik keypad Material dan InkWell', (tester) async {
    debugPrint('[KEYPAD DIAG] A: mulai');

    Widget keypadButton(String value) {
      return SizedBox(
        width: 72,
        height: 72,
        child: Material(
          child: InkWell(
            onTap: () {},
            child: Center(
              child: Text(value),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int row = 0; row < 3; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int column = 0; column < 3; column++)
                        keypadButton('${row * 3 + column + 1}'),
                    ],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    keypadButton('0'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    debugPrint('[KEYPAD DIAG] B: pumpWidget selesai');

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);

    debugPrint('[KEYPAD DIAG] C: semua pemeriksaan selesai');
  });
}
