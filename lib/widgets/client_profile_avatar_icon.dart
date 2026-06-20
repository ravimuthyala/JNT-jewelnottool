import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ClientProfileAvatarIcon extends StatelessWidget {
  const ClientProfileAvatarIcon({
    super.key,
    this.imageUrl = '',
    this.displayName = '',
    this.size = 20,
  });

  final String imageUrl;
  final String displayName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final src = _cleanAvatarValue(imageUrl);

    if (src.isEmpty) {
      return SizedBox.square(dimension: size, child: _fallback());
    }

    final cacheSize = (size * (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0)).round();

    if (src.startsWith('data:image/')) {
      try {
        final comma = src.indexOf(',');
        final encoded = comma >= 0 ? src.substring(comma + 1) : src;
        final bytes = base64Decode(encoded);
        return SizedBox.square(
          dimension: size,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          ),
        );
      } catch (_) {
        return SizedBox.square(dimension: size, child: _fallback());
      }
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return SizedBox.square(
        dimension: size,
        child: Image.network(
          src,
          fit: BoxFit.cover,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }

    return SizedBox.square(dimension: size, child: _fallback());
  }

  Widget _fallback() {
    final letter = _avatarLetter(displayName);
    return SizedBox.square(
      dimension: size,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.balletSlippers,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.balletSlippers),
        ),
        alignment: Alignment.center,
        child: Semantics(
          label: 'Avatar initial. Capital $letter',
          child: ExcludeSemantics(
            child: Text(
              letter,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: size * 0.52,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _avatarLetter(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'A';
    final first = trimmed.substring(0, 1).toUpperCase();
    return first.trim().isEmpty ? 'A' : first;
  }

  String _cleanAvatarValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final lower = text.toLowerCase();
    if (lower.startsWith('assets/')) return '';
    if (lower.startsWith('gs://')) return '';
    if (lower.startsWith('clients/')) return '';
    if (lower.startsWith('artists/')) return '';
    if (lower.startsWith('client_artists/')) return '';
    if (lower.startsWith('company/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';

    return text;
  }
}
