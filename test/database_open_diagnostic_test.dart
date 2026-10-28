
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drivemate/database/platform_init.dart';
import 'package:drivemate/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Diagnostik pembukaan database DriveMate',
    () async {
      debugPrint('[DB TEST] A: mulai inisialisasi FFI');

      initPlatformDatabase();

      debugPrint('[DB TEST] B: FFI selesai');
      debugPrint('[DB TEST] C: meminta DatabaseHelper.database');

      final db = await DatabaseHelper.instance.database;

      debugPrint('[DB TEST] D: database berhasil dibuka');

      final result = await db.rawQuery('SELECT 1 AS value');

      debugPrint('[DB TEST] E: query berhasil: $result');

      expect(result.first['value'], 1);
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
