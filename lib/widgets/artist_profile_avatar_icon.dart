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
  });

  final Color backgroundColor;
  final Color? textColor;
  final double? size;

  @override
  State<ArtistProfileAvatarIcon> createState() =>
      _ArtistProfileAvatarIconState();
}

class _ArtistProfileAvatarIconState extends State<ArtistProfileAvatarIcon> {
  String _displayName = '';
  String _avatar = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadArtistProfile();
  }

  Future<void> _loadArtistProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      final uid = (user?.id ?? '').trim();
      final email = (user?.email ?? '').trim().toLowerCase();

      if (uid.isEmpty && email.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      Map<String, dynamic>? artistData;

      artistData = await _readArtistRow(
        table: 'artist',
        uid: uid,
        email: email,
      );

      artistData ??= await _readArtistRow(
        table: 'client_artist',
        uid: uid,
        email: email,
      );

      final data = artistData ?? const <String, dynamic>{};
      final profile = _asMap(data['profile']);
      final basic = _asMap(data['basic']);

      final name = _firstNonEmpty([
        profile['displayName'],
        profile['studioName'],
        profile['name'],
        data['display_name'],
        data['displayName'],
        data['studio_name'],
        data['studioName'],
        data['name'],
        basic['name'],
        email.contains('@') ? email.split('@').first : email,
        'Artist',
      ]);

      final avatar = _cleanAvatarValue(
        _firstNonEmpty([
          profile['profileImageUrl'],
          profile['profilePhotoUrl'],
          profile['photoUrl'],
          profile['avatarUrl'],
          data['profile_image_url'],
          data['profileImageUrl'],
          data['profilePhotoUrl'],
          data['photoUrl'],
          data['avatarUrl'],
          basic['profileImageUrl'],
          basic['photoUrl'],
          basic['avatarUrl'],
        ]),
      );

      debugPrint('ARTIST AVATAR NAME = $name');
      debugPrint('ARTIST AVATAR URL = $avatar');

      if (!mounted) return;
      setState(() {
        _displayName = name;
        _avatar = avatar;
        _loading = false;
      });
    } catch (e) {
      debugPrint('ARTIST AVATAR LOAD FAILED: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _readArtistRow({
    required String table,
    required String uid,
    required String email,
  }) async {
    final supabase = Supabase.instance.client;

    if (uid.isNotEmpty) {
      final rows = await supabase.from(table).select().eq('id', uid).limit(1);

      if (rows.isNotEmpty) {
        final first = rows.first;
        return Map<String, dynamic>.from(first);
            }
    }

    if (email.isNotEmpty) {
      final rows = await supabase
          .from(table)
          .select()
          .eq('email', email)
          .limit(1);

      if (rows.isNotEmpty) {
        final first = rows.first;
        return Map<String, dynamic>.from(first);
            }
    }

    return null;
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

    return text;
  }

  @override
  Widget build(BuildContext context) {
    final src = _avatar.trim();

    if (_loading && src.isEmpty) {
      return _fallback();
    }

    if (src.isEmpty) {
      return _fallback();
    }

    if (src.startsWith('data:image/')) {
      final comma = src.indexOf(',');
      if (comma > 0 && comma < src.length - 1) {
        try {
          final Uint8List bytes = base64Decode(src.substring(comma + 1));
          return _frame(
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(),
            ),
          );
        } catch (_) {
          return _fallback();
        }
      }
      return _fallback();
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return _frame(
        Image.network(
          src,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    }

    return _fallback();
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
    final first = trimmed.substring(0, 1).toUpperCase();
    return first.trim().isEmpty ? 'A' : first;
  }

  Widget _frame(Widget child) {
    final size = widget.size;
    final clipped = ClipRRect(
      borderRadius: BorderRadius.zero,
      child: SizedBox.expand(child: child),
    );

    if (size == null) return clipped;

    return SizedBox.square(
      dimension: size,
      child: clipped,
    );
  }
}
