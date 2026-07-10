import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

class ArtistProfileAvatarIcon extends StatefulWidget {
  const ArtistProfileAvatarIcon({
    super.key,
    this.backgroundColor = AppColors.balletSlippers,
    this.textColor,
    this.size,
    this.displayName,
    this.profileImageUrl,
  });

  final Color backgroundColor;
  final Color? textColor;
  final double? size;
  final String? displayName;
  final String? profileImageUrl;

  @override
  State<ArtistProfileAvatarIcon> createState() =>
      _ArtistProfileAvatarIconState();
}

class _ArtistProfileAvatarIconState extends State<ArtistProfileAvatarIcon> {
  String _displayName = '';
  String _avatarUrl = '';
  String _secondaryAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _hydrateAvatar();
  }

  @override
  void didUpdateWidget(covariant ArtistProfileAvatarIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayName != widget.displayName ||
        oldWidget.profileImageUrl != widget.profileImageUrl) {
      _hydrateAvatar();
    }
  }

  Future<void> _hydrateAvatar() async {
    final seedName = (widget.displayName ?? '').trim();
    final seedAvatar = _cleanAvatarValue((widget.profileImageUrl ?? '').trim());
    final user = Supabase.instance.client.auth.currentUser;
    final uid = (user?.id ?? '').trim();
    final email = (user?.email ?? '').trim().toLowerCase();
    final directPrimary = uid.isEmpty
        ? ''
        : _publicStorageUrl(
            'profile-pictures',
            'artists/$uid/profile/avatar.jpg',
          );
    final directSecondary = uid.isEmpty
        ? ''
        : _publicStorageUrl(
            'profile-pictures',
            'client_artists/$uid/profile/avatar.jpg',
          );
    final resolvedSeedAvatar = _resolveAvatarUrl(seedAvatar);

    if (seedName.isNotEmpty ||
        resolvedSeedAvatar.isNotEmpty ||
        directPrimary.isNotEmpty) {
      setState(() {
        _displayName = seedName;
        _avatarUrl = resolvedSeedAvatar.isNotEmpty
            ? resolvedSeedAvatar
            : directPrimary;
        _secondaryAvatarUrl =
            resolvedSeedAvatar.isNotEmpty || directPrimary.isEmpty
            ? ''
            : directSecondary;
      });
      if (resolvedSeedAvatar.isNotEmpty || directPrimary.isNotEmpty) return;
    }

    try {
      if (uid.isEmpty && email.isEmpty) {
        return;
      }

      final artistData =
          await _readArtistRow(table: 'artist', uid: uid, email: email) ??
          await _readArtistRow(
            table: 'client_artist',
            uid: uid,
            email: email,
          ) ??
          const <String, dynamic>{};

      final profile = _asMap(artistData['profile']);
      final basic = _asMap(artistData['basic']);
      final artist = _asMap(artistData['artist']);

      final resolvedName = _firstNonEmpty([
        seedName,
        profile['displayName'],
        profile['display_name'],
        profile['studioName'],
        profile['studio_name'],
        profile['name'],
        artist['displayName'],
        artist['display_name'],
        artist['nameOrStudio'],
        artist['name_or_studio'],
        artist['name'],
        basic['displayName'],
        basic['display_name'],
        basic['name'],
        artistData['panel_displayName'],
        artistData['panel_display_name'],
        artistData['displayName'],
        artistData['display_name'],
        artistData['studioName'],
        artistData['studio_name'],
        artistData['nameOrStudio'],
        artistData['name_or_studio'],
        artistData['name'],
        email.contains('@') ? email.split('@').first : email,
        'Artist',
      ]);

      final rawAvatar = _cleanAvatarValue(
        _firstNonEmpty([
          seedAvatar,
          profile['profileImageUrl'],
          profile['profile_image_url'],
          profile['profilePhotoUrl'],
          profile['profile_photo_url'],
          profile['photoUrl'],
          profile['photo_url'],
          profile['avatarUrl'],
          profile['avatar_url'],
          artist['profileImageUrl'],
          artist['profile_image_url'],
          artist['profilePhotoUrl'],
          artist['profile_photo_url'],
          artist['photoUrl'],
          artist['photo_url'],
          artist['avatarUrl'],
          artist['avatar_url'],
          basic['profileImageUrl'],
          basic['profile_image_url'],
          basic['photoUrl'],
          basic['photo_url'],
          basic['avatarUrl'],
          basic['avatar_url'],
          artistData['panel_profileImageUrl'],
          artistData['panel_profile_image_url'],
          artistData['profileImageUrl'],
          artistData['profile_image_url'],
          artistData['profilePhotoUrl'],
          artistData['profile_photo_url'],
          artistData['photoUrl'],
          artistData['photo_url'],
          artistData['avatarUrl'],
          artistData['avatar_url'],
          artistData['imageUrl'],
          artistData['image_url'],
          artistData['photo'],
        ]),
      );

      final resolvedAvatar = _firstNonEmpty([
        _resolveAvatarUrl(rawAvatar),
        directPrimary,
        directSecondary,
      ]);

      if (!mounted) return;
      setState(() {
        _displayName = resolvedName;
        _avatarUrl = resolvedAvatar;
        _secondaryAvatarUrl = '';
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readArtistRow({
    required String table,
    required String uid,
    required String email,
  }) async {
    final supabase = Supabase.instance.client;

    Future<Map<String, dynamic>?> tryEq(String column, String value) async {
      if (value.trim().isEmpty) return null;
      try {
        final rows = await supabase
            .from(table)
            .select()
            .eq(column, value)
            .limit(1);
        if (rows.isNotEmpty) {
          return Map<String, dynamic>.from(rows.first as Map);
        }
      } catch (_) {}
      return null;
    }

    return await tryEq('id', uid) ??
        await tryEq('uid', uid) ??
        await tryEq('artist_uid', uid) ??
        await tryEq('auth_uid', uid) ??
        await tryEq('user_id', uid) ??
        await tryEq('email', email) ??
        await tryEq('artist_email', email);
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _cleanAvatarValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    final lower = text.toLowerCase();

    if (lower.startsWith('assets/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';
    if (lower == 'null' || lower == 'none' || lower == '-') return '';

    return text;
  }

  String _resolveAvatarUrl(String value) {
    final raw = _cleanAvatarValue(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('data:image/')) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    var path = raw;
    if (path.startsWith('/')) path = path.substring(1);

    if (path.startsWith('profile-pictures/')) {
      return _publicStorageUrl(
        'profile-pictures',
        path.replaceFirst('profile-pictures/', ''),
      );
    }

    if (path.startsWith('artists/')) {
      return _publicStorageUrl('profile-pictures', path);
    }

    if (path.startsWith('artist/')) {
      return _publicStorageUrl('profile-pictures', path);
    }

    if (path.contains('/')) {
      return _publicStorageUrl('profile-pictures', path);
    }

    return '';
  }

  String _publicStorageUrl(String bucket, String path) {
    try {
      return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final src = _avatarUrl.trim();
    if (src.isEmpty) return _fallback();

    final size = widget.size ?? 36.0;
    final pixelRatio = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final cacheSize = (size * pixelRatio).round();

    if (src.startsWith('data:image/')) {
      final comma = src.indexOf(',');
      if (comma <= 0 || comma >= src.length - 1) return _fallback();
      try {
        final bytes = base64Decode(src.substring(comma + 1));
        return _frame(
          Image.memory(
            Uint8List.fromList(bytes),
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            errorBuilder: (_, _, _) => _fallback(),
          ),
        );
      } catch (_) {
        return _fallback();
      }
    }

    return _frame(
      _buildNetworkImage(src, cacheSize, _secondaryAvatarUrl.trim()),
    );
  }

  Widget _buildNetworkImage(String url, int cacheSize, String secondaryUrl) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      errorBuilder: (_, _, _) {
        if (secondaryUrl.isNotEmpty && secondaryUrl != url) {
          return Image.network(
            secondaryUrl,
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            errorBuilder: (_, _, _) => _fallback(),
          );
        }
        return _fallback();
      },
    );
  }

  Widget _fallback() {
    final letter = _avatarLetter(_displayName);

    return _frame(
      Container(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.balletSlippers),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: (widget.size ?? 36) * 0.52,
            color: widget.textColor ?? AppColors.blackCat,
          ),
        ),
      ),
    );
  }

  String _avatarLetter(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'A';
    final first = trimmed.characters.first.toUpperCase();
    return first.trim().isEmpty ? 'A' : first;
  }

  Widget _frame(Widget child) {
    final size = widget.size;
    final clipped = ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox.expand(child: child),
    );

    if (size == null) return clipped;

    return SizedBox.square(dimension: size, child: clipped);
  }
}
