import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Diagnostik layout Column dan Spacer', (tester) async {
    debugPrint('[DIAG] A: mulai');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Spacer(flex: 2),
                    Text('Aplikasi Terkunci'),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('1'),
                        Text('2'),
                        Text('3'),
                      ],
                    ),
                    Spacer(flex: 2),
                    Text('Keluar'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    debugPrint('[DIAG] B: pumpWidget selesai');
    expect(find.text('Aplikasi Terkunci'), findsOneWidget);
  });
}
