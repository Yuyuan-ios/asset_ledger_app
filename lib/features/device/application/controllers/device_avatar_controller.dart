import 'package:image_picker/image_picker.dart';

import '../../../../data/services/avatar_storage_service.dart';

class DeviceAvatarController {
  const DeviceAvatarController();

  Future<String> savePickedAvatar(XFile file) {
    return AvatarStorageService.saveXFile(file);
  }
}
