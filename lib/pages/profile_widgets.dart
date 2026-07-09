import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../app/image_sources.dart';
import '../app/models.dart';

/// 用户头像：有自定义图则渲染，否则用昵称首字母的字母头像。
/// 我的页、个人资料页共用。
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, required this.radius});

  final UserProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (profile.avatarDataUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: imageProviderForSource(profile.avatarDataUrl),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: veriRoyal,
      child: Text(
        profile.nickname.isEmpty ? 'VF' : profile.nickname.characters.first,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 我的页概览的单个统计项（大号数值 + 小标签）。
class ProfileStat extends StatelessWidget {
  const ProfileStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
