import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/supabase_initializer.dart';
import '../data/social_repository.dart';

class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.name,
    this.radius = 22,
    this.avatarPath,
    this.imageBytes,
  });
  final String name;
  final double radius;
  final String? avatarPath;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase(),
      style: TextStyle(fontSize: radius * .7, fontWeight: FontWeight.w700),
    );
    final url = avatarPath != null && isSupabaseConfigured
        ? SocialRepository.instance.avatarUrl(avatarPath!)
        : null;
    return Semantics(
      image: true,
      label: '$name 프로필 사진',
      excludeSemantics: true,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryBlueSoft,
        foregroundColor: AppColors.primaryBlueDark,
        child: imageBytes == null && url == null
            ? fallback
            : ClipOval(
                child: SizedBox.square(
                  dimension: radius * 2,
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(child: fallback),
                        )
                      : Image.network(
                          url!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(child: fallback),
                        ),
                ),
              ),
      ),
    );
  }
}

class SocialPersonTile extends StatelessWidget {
  const SocialPersonTile({
    super.key,
    required this.name,
    required this.handle,
    this.onTap,
    this.trailing,
    this.avatarPath,
  });
  final String name;
  final String handle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            SocialAvatar(name: name, avatarPath: avatarPath),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@$handle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    ),
  );
}
