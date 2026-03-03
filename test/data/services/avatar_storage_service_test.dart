import 'dart:io';

import 'package:asset_ledger/data/services/avatar_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  tearDown(AvatarStorageService.resetTestOverrides);

  group('AvatarStorageService.saveXFile', () {
    test('copies the source file into the app support directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('avatar_save_test_');
      final source = File('${tempDir.path}/source.png');
      await source.writeAsString('avatar');

      AvatarStorageService.setTestOverrides(
        supportDirectoryResolver: () async => tempDir,
        filenameResolver: () => 'avatar_test.png',
      );

      final savedPath = await AvatarStorageService.saveXFile(XFile(source.path));
      final saved = File(savedPath);

      expect(savedPath, '${tempDir.path}/device_avatars/avatar_test.png');
      expect(await saved.exists(), isTrue);
      expect(await saved.readAsString(), 'avatar');

      await tempDir.delete(recursive: true);
    });

    test('throws when the source file is missing', () async {
      final tempDir = await Directory.systemTemp.createTemp('avatar_save_test_');
      AvatarStorageService.setTestOverrides(
        supportDirectoryResolver: () async => tempDir,
      );

      await expectLater(
        AvatarStorageService.saveXFile(XFile('${tempDir.path}/missing.png')),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('图片文件不存在'),
          ),
        ),
      );

      await tempDir.delete(recursive: true);
    });
  });

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

    test('rejects deleting a directory path', () async {
      final tempDir = await Directory.systemTemp.createTemp('avatar_test_');

      await expectLater(
        AvatarStorageService.deleteIfExists(tempDir.path),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('头像路径不是文件'),
          ),
        ),
      );

      expect(await tempDir.exists(), isTrue);
      await tempDir.delete(recursive: true);
    });
  });
}
