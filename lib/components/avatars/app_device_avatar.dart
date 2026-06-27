// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/foundation/typography.dart';
import '../../tokens/mapper/color_tokens.dart';

// =====================================================================
// ============================== 二、BrandAvatar（品牌头像渲染） ==============================
// =====================================================================
//
// 规则（全 App 一致）：
// 1) SANY / HITACHI 使用统一绘制的品牌色徽章
// 2) 其他品牌优先 brand 对应的 assets/brands/*.png，并加统一徽章质感
// 3) 失败回退首字母占位
//
// 设计目标：
// - 只吃 brand 字符串（用于“新增弹窗/品牌选择/编号预览”等场景）
// - 避免 DevicePage 再写一套 brandKey/brandAvatar 逻辑
// =====================================================================

class BrandAvatar extends StatelessWidget {
  final String brand;
  final double radius;

  const BrandAvatar({super.key, required this.brand, this.radius = 18});

  static const Color _sanyTop = Color(0xFFF04B5D);
  static const Color _sanyCenter = Color(0xFFE23D4F);
  static const Color _sanyBottom = Color(0xFFC93043);
  static const Color _hitachiTop = AppColors.brand;
  static const Color _hitachiCenter = AppColors.brand;
  static const Color _hitachiBottom = AppColors.brand;
  static const Color _fallbackTop = Color(0xFF9A9188);
  static const Color _fallbackCenter = Color(0xFF8A8178);
  static const Color _fallbackBottom = Color(0xFF706860);
  static const Color _outerStroke = Color(0x26000000);
  static const Color _innerStroke = Color(0x80FFFFFF);
  static const Color _highlightTop = Color(0x38FFFFFF);
  static const Color _highlightBottom = Color(0x00FFFFFF);
  static const Color _bottomShade = Color(0x14000000);
  static final Color _shadowColor = AppColors.brand.withValues(alpha: 0.22);
  static const double _softBlurSigma = 0.22;

  // -------------------------------------------------------------------
  // brand -> key（用于映射 assets 文件名）
  // 规则：小写 + 空格转下划线 + 去符号（适配 john_deere.png）
  // -------------------------------------------------------------------
  String _brandKey(String brand) {
    final b = brand.trim();
    if (b.isEmpty) return '';

    var key = b.toLowerCase().replaceAll(' ', '_');
    key = key.replaceAll(RegExp(r'[^a-z0-9_]+'), '');

    const special = <String, String>{
      'liugong': 'liugong',
      'liu_gong': 'liugong',
      'john_deere': 'john_deere',
      'johndeere': 'john_deere',
      'develon': 'develon',
    };

    return special[key] ?? key;
  }

  _BrandBadgeSpec? _brandBadgeSpec(String brand) {
    switch (_brandKey(brand)) {
      case 'sany':
        return const _BrandBadgeSpec(
          label: 'SANY',
          top: _sanyTop,
          center: _sanyCenter,
          bottom: _sanyBottom,
        );
      case 'hitachi':
        return const _BrandBadgeSpec(
          label: 'HITACHI',
          top: _hitachiTop,
          center: _hitachiCenter,
          bottom: _hitachiBottom,
        );
    }
    return null;
  }

  // -------------------------------------------------------------------
  // brand -> assets 路径
  // -------------------------------------------------------------------
  String? _brandAssetPath(String brand) {
    final key = _brandKey(brand);
    if (key.isEmpty) return null;
    return 'assets/brands/$key.png';
  }

  // -------------------------------------------------------------------
  // fallback：首字母占位
  // -------------------------------------------------------------------
  Widget _fallback(BuildContext context) {
    final text = brand.trim().isEmpty ? '?' : brand.trim().characters.first;

    return _badge(
      context: context,
      label: text.toUpperCase(),
      top: _fallbackTop,
      center: _fallbackCenter,
      bottom: _fallbackBottom,
    );
  }

  Widget _badge({
    required BuildContext context,
    required String label,
    required Color top,
    required Color center,
    required Color bottom,
  }) {
    final diameter = radius * 2;
    final innerInset = radius * 0.08;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: center,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 7,
              offset: Offset(0, 2.5),
            ),
          ],
        ),
        child: ClipOval(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _softBlurSigma,
              sigmaY: _softBlurSigma,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [top, center, bottom],
                      stops: const [0, 0.52, 1],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [_bottomShade, _highlightBottom],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      stops: [0, 0.58],
                      colors: [_highlightTop, _highlightBottom],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _outerStroke, width: 1),
                  ),
                ),
                Positioned.fill(
                  left: innerInset,
                  top: innerInset,
                  right: innerInset,
                  bottom: innerInset,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _innerStroke, width: 1),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: radius * 0.2),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: AppTypography.body(
                          context,
                          color: Colors.white,
                          fontSize: radius * 0.52,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _assetBadge(BuildContext context, String asset) {
    final diameter = radius * 2;
    final innerInset = radius * 0.08;

    return SizedBox(
      width: diameter,
      height: diameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 7,
              offset: Offset(0, 2.5),
            ),
          ],
        ),
        child: ClipOval(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _softBlurSigma,
              sigmaY: _softBlurSigma,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  asset,
                  width: diameter,
                  height: diameter,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _fallback(context);
                  },
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      stops: [0, 0.58],
                      colors: [_highlightTop, _highlightBottom],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _outerStroke, width: 1),
                  ),
                ),
                Positioned.fill(
                  left: innerInset,
                  top: innerInset,
                  right: innerInset,
                  bottom: innerInset,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _innerStroke, width: 1),
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _innerStroke, width: 1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeSpec = _brandBadgeSpec(brand);
    if (badgeSpec != null) {
      return _badge(
        context: context,
        label: badgeSpec.label,
        top: badgeSpec.top,
        center: badgeSpec.center,
        bottom: badgeSpec.bottom,
      );
    }

    final asset = _brandAssetPath(brand);
    if (asset == null) return _fallback(context);

    // ✅ 用 Image.asset + errorBuilder，避免 CircleAvatar.backgroundImage 失败时空白
    return _assetBadge(context, asset);
  }
}

class _BrandBadgeSpec {
  const _BrandBadgeSpec({
    required this.label,
    required this.top,
    required this.center,
    required this.bottom,
  });

  final String label;
  final Color top;
  final Color center;
  final Color bottom;
}

// =====================================================================
// ============================== 三、DeviceAvatar（统一设备头像渲染） ==============================
// =====================================================================
//
// 规则（全 App 一致）：
// 1) customAvatarPath 优先（本地文件）
// 2) 否则走 BrandAvatar（brand assets）
// 3) 再否则回退首字母占位（由 BrandAvatar 内部兜底）
//
// 设计原则：
// - 头像渲染统一在这里，DevicePage/TimingPage 不写重复逻辑
// =====================================================================

class DeviceAvatar extends StatelessWidget {
  final String brand;
  final String? customAvatarPath;
  final double radius;

  const DeviceAvatar({
    super.key,
    required this.brand,
    this.customAvatarPath,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final p0 = (customAvatarPath ?? '').trim();

    // ---------------------------------------------------------------
    // ① 优先：自定义头像（本地文件路径）
    // ---------------------------------------------------------------
    if (p0.isNotEmpty) {
      final f = File(p0);

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: ClipOval(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: BrandAvatar._softBlurSigma,
              sigmaY: BrandAvatar._softBlurSigma,
            ),
            child: Image.file(
              f,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                // 路径失效 -> 回退 brand assets
                return BrandAvatar(brand: brand, radius: radius);
              },
            ),
          ),
        ),
      );
    }

    // ---------------------------------------------------------------
    // ② 回退：brand assets / 首字母
    // ---------------------------------------------------------------
    return BrandAvatar(brand: brand, radius: radius);
  }
}
