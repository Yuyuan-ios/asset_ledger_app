import '../../../../data/services/inbound_share_file_channel.dart';
import 'pick_external_work_share_file_use_case.dart';

/// 处理系统外部打开的 `.jzt` 文件载荷，复用 App 内文件选择导入相同的
/// 结果类型与错误码。只做扩展名 + 非空校验，envelope / payload_sha256 /
/// backup 拒绝 / duplicate / importer 继续交由现有 parser / preview 流程。
class HandleInboundShareFileUseCase {
  const HandleInboundShareFileUseCase();

  PickShareFileResult handle(InboundShareFile file) {
    if (!PickExternalWorkShareFileUseCase.isJztExtension(file.name)) {
      return const PickShareFileError(PickShareFileErrorCode.invalidType);
    }
    if (file.content.trim().isEmpty) {
      return const PickShareFileError(PickShareFileErrorCode.readFailure);
    }
    return PickShareFileContent(file.content);
  }
}
