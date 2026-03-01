import 'dart:io';

import 'package:asset_ledger/data/services/avatar_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AvatarStorageService.deleteIfExists', () {
    test('returns quietly for null or blank paths', () async {
      await AvatarStorageService.deleteIfExists(null);
      await AvatarStorageService.deleteIfExists('   ');
    });

    test('deletes an existing file after trimming the input path', () async {
      final tempDir = await Directory.systemTemp.createTemp('avatar_test_');
      final file = File('${tempDir.path}/avatar.png');
      await file.writeAsString('avatar');

      await AvatarStorageService.deleteIfExists('  ${file.path}  ');

      expect(await file.exists(), isFalse);
      await tempDir.delete(recursive: true);
    });

    test('does nothing when the file does not exist', () async {
      final tempDir = await Directory.systemTemp.createTemp('avatar_test_');
      final missingPath = '${tempDir.path}/missing.png';

      await AvatarStorageService.deleteIfExists(missingPath);

      expect(await tempDir.exists(), isTrue);
      await tempDir.delete(recursive: true);
    });
  });
}
