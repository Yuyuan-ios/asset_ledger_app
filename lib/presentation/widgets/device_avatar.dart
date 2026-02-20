// =====================================================================
// ============================== 一、导入依赖库 ==============================
// =====================================================================

import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/device.dart';

// =====================================================================
// ============================== 二、BrandAvatar（品牌头像渲染） ==============================
// =====================================================================
//
// 规则（全 App 一致）：
// 1) 优先 brand 对应的 assets/brands/*.png
// 2) 失败回退首字母占位
//
// 设计目标：
// - 只吃 brand 字符串（用于“新增弹窗/品牌选择/编号预览”等场景）
// - 避免 DevicePage 再写一套 brandKey/brandAvatar 逻辑
// =====================================================================

class BrandAvatar extends StatelessWidget {
  final String brand;
  final double radius;

  const BrandAvatar({super.key, required this.brand, this.radius = 18});

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
  Widget _fallback() {
    final text = brand.trim().isEmpty ? '?' : brand.trim().characters.first;

    return CircleAvatar(
      radius: radius,
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asset = _brandAssetPath(brand);
    if (asset == null) return _fallback();

    // ✅ 用 Image.asset + errorBuilder，避免 CircleAvatar.backgroundImage 失败时空白
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: ClipOval(
        child: Image.asset(
          asset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      ),
    );
  }
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
  final Device device;
  final double radius;

  const DeviceAvatar({super.key, required this.device, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final p0 = (device.customAvatarPath ?? '').trim();

    // ---------------------------------------------------------------
    // ① 优先：自定义头像（本地文件路径）
    // ---------------------------------------------------------------
    if (p0.isNotEmpty) {
      final f = File(p0);

      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Image.file(
            f,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              // 路径失效 -> 回退 brand assets
              return BrandAvatar(brand: device.brand, radius: radius);
            },
          ),
        ),
      );
    }

    // ---------------------------------------------------------------
    // ② 回退：brand assets / 首字母
    // ---------------------------------------------------------------
    return BrandAvatar(brand: device.brand, radius: radius);
  }
}
