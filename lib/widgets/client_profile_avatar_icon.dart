import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/storage_url_resolver.dart';
import '../theme/app_colors.dart';

class ClientProfileAvatarIcon extends StatefulWidget {
  const ClientProfileAvatarIcon({
    super.key,
    this.imageUrl = '',
    this.displayName = '',
    this.size = 20,
    this.resolveCurrentUserFallback = false,
  });

  final String imageUrl;
  final String displayName;
  final double size;
  final bool resolveCurrentUserFallback;

  @override
  State<ClientProfileAvatarIcon> createState() =>
      _ClientProfileAvatarIconState();
}

class _ClientProfileAvatarIconState extends State<ClientProfileAvatarIcon> {
  String _displayName = '';
  String _avatarUrl = '';
  String _secondaryAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _hydrateAvatar();
  }

  @override
  void didUpdateWidget(covariant ClientProfileAvatarIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.displayName != widget.displayName ||
        oldWidget.resolveCurrentUserFallback !=
            widget.resolveCurrentUserFallback) {
      _hydrateAvatar();
    }
  }

  Future<void> _hydrateAvatar() async {
    final seedName = widget.displayName.trim();
    final seedAvatar = _cleanAvatarValue(widget.imageUrl);
    final User? user = Supabase.instance.client.auth.currentUser;
    final String uid = (user?.id ?? '').trim();
    final String email = (user?.email ?? '').trim().toLowerCase();
    final String resolvedSeedAvatar = _resolveAvatarUrlSync(seedAvatar);
    final String directPrimary =
        widget.resolveCurrentUserFallback && uid.isNotEmpty
        ? _publicStorageUrl(
            'profile-pictures',
            'client_artists/$uid/profile/avatar.jpg',
          )
        : '';
    final String directSecondary =
        widget.resolveCurrentUserFallback && uid.isNotEmpty
        ? _publicStorageUrl(
            'profile-pictures',
            'clients/$uid/profile/avatar.jpg',
          )
        : '';

    if (!mounted) return;
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

    if (!widget.resolveCurrentUserFallback) {
      if (resolvedSeedAvatar.isNotEmpty || seedAvatar.isEmpty) return;
      final String asyncResolvedSeedAvatar = await _resolveAvatarUrl(
        seedAvatar,
      );
      if (!mounted || asyncResolvedSeedAvatar.isEmpty) return;
      setState(() => _avatarUrl = asyncResolvedSeedAvatar);
      return;
    }

    if (resolvedSeedAvatar.isNotEmpty || directPrimary.isNotEmpty) return;

    try {
      if (uid.isEmpty && email.isEmpty) {
        return;
      }

      final Map<String, dynamic> clientData =
          await _readUserRow(table: 'client_artist', uid: uid, email: email) ??
          await _readUserRow(table: 'client', uid: uid, email: email) ??
          const <String, dynamic>{};

      final Map<String, dynamic> profile = _asMap(clientData['profile']);
      final Map<String, dynamic> basic = _asMap(clientData['basic']);
      final Map<String, dynamic> client = _asMap(clientData['client']);
      final Map<String, dynamic> clientProfile = _asMap(client['profile']);

      final String resolvedName = _firstNonEmpty(<Object?>[
        seedName,
        basic['displayName'],
        basic['display_name'],
        basic['name'],
        profile['displayName'],
        profile['display_name'],
        profile['name'],
        clientProfile['displayName'],
        clientProfile['display_name'],
        clientProfile['name'],
        clientData['panel_displayName'],
        clientData['panel_display_name'],
        clientData['displayName'],
        clientData['display_name'],
        clientData['name'],
        email.contains('@') ? email.split('@').first : email,
        'A',
      ]);

      final String rawAvatar = _firstNonEmpty(<Object?>[
        seedAvatar,
        basic['profileImageUrl'],
        basic['profile_image_url'],
        basic['profilePhotoUrl'],
        basic['profile_photo_url'],
        basic['photoUrl'],
        basic['photo_url'],
        basic['avatarUrl'],
        basic['avatar_url'],
        profile['profileImageUrl'],
        profile['profile_image_url'],
        profile['profilePhotoUrl'],
        profile['profile_photo_url'],
        profile['photoUrl'],
        profile['photo_url'],
        profile['avatarUrl'],
        profile['avatar_url'],
        clientProfile['profileImageUrl'],
        clientProfile['profile_image_url'],
        clientProfile['profilePhotoUrl'],
        clientProfile['profile_photo_url'],
        clientProfile['photoUrl'],
        clientProfile['photo_url'],
        clientProfile['avatarUrl'],
        clientProfile['avatar_url'],
        clientData['panel_profileImageUrl'],
        clientData['panel_profile_image_url'],
        clientData['profileImageUrl'],
        clientData['profile_image_url'],
        clientData['profilePhotoUrl'],
        clientData['profile_photo_url'],
        clientData['photoUrl'],
        clientData['photo_url'],
        clientData['avatarUrl'],
        clientData['avatar_url'],
        clientData['imageUrl'],
        clientData['image_url'],
        clientData['photo'],
      ]);

      final String resolvedAvatar = _firstNonEmpty(<String>[
        await _resolveAvatarUrl(rawAvatar),
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

  Future<Map<String, dynamic>?> _readUserRow({
    required String table,
    required String uid,
    required String email,
  }) async {
    final SupabaseClient supabase = Supabase.instance.client;

    Future<Map<String, dynamic>?> tryEq(String column, String value) async {
      if (value.trim().isEmpty) return null;
      try {
        final List<dynamic> rows = await supabase
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
        await tryEq('client_uid', uid) ??
        await tryEq('auth_uid', uid) ??
        await tryEq('user_id', uid) ??
        await tryEq('email', email) ??
        await tryEq('client_email', email);
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  String _firstNonEmpty(List<Object?> values) {
    for (final Object? raw in values) {
      final String value = (raw ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _cleanAvatarValue(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return '';

    final String lower = text.toLowerCase();
    if (lower.startsWith('assets/')) return '';
    if (lower.startsWith('company/')) return '';
    if (lower.contains('profile_placeholder')) return '';
    if (lower.contains('avatar_placeholder')) return '';
    if (lower == 'null' || lower == 'none' || lower == '-') return '';

    return text;
  }

  Future<String> _resolveAvatarUrl(String value) async {
    final String syncValue = _resolveAvatarUrlSync(value);
    if (syncValue.isNotEmpty) return syncValue;

    final String raw = _cleanAvatarValue(value);
    if (raw.isEmpty) return '';

    final String? resolved = await StorageUrlResolver.resolve(raw);
    final String normalized = (resolved ?? '').trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    if (_looksLikeStorageReference(raw)) {
      var path = raw;
      if (path.startsWith('/')) path = path.substring(1);
      if (path.startsWith('profile-pictures/')) {
        path = path.replaceFirst('profile-pictures/', '');
      }
      return _publicStorageUrl('profile-pictures', path);
    }

    return '';
  }

  String _resolveAvatarUrlSync(String value) {
    final String raw = _cleanAvatarValue(value);
    if (raw.isEmpty) return '';
    if (raw.startsWith('data:image/')) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    if (_looksLikeStorageReference(raw)) {
      var path = raw;
      if (path.startsWith('/')) path = path.substring(1);
      if (path.startsWith('profile-pictures/')) {
        path = path.replaceFirst('profile-pictures/', '');
      }
      return _publicStorageUrl('profile-pictures', path);
    }

    return '';
  }

  bool _looksLikeStorageReference(String value) {
    final String lower = value.trim().toLowerCase();
    return lower.startsWith('gs://') ||
        lower.startsWith('profile-pictures/') ||
        lower.startsWith('clients/') ||
        lower.startsWith('artists/') ||
        lower.startsWith('client_artists/');
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
    final String src = _avatarUrl.trim();
    if (src.isEmpty) {
      return SizedBox.square(dimension: widget.size, child: _fallback());
    }

    final int cacheSize =
        (widget.size * (MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0))
            .round();

    if (src.startsWith('data:image/')) {
      try {
        final int comma = src.indexOf(',');
        final String encoded = comma >= 0 ? src.substring(comma + 1) : src;
        final Uint8List bytes = base64Decode(encoded);
        return SizedBox.square(
          dimension: widget.size,
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: cacheSize,
            cacheHeight: cacheSize,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          ),
        );
      } catch (_) {
        return SizedBox.square(dimension: widget.size, child: _fallback());
      }
    }

    return SizedBox.square(
      dimension: widget.size,
      child: _buildNetworkImage(src, cacheSize, _secondaryAvatarUrl.trim()),
    );
  }

  Widget _buildNetworkImage(String url, int cacheSize, String secondaryUrl) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            if (secondaryUrl.isNotEmpty && secondaryUrl != url) {
              return Image.network(
                secondaryUrl,
                fit: BoxFit.cover,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) => _fallback(),
              );
            }
            return _fallback();
          },
    );
  }

  Widget _fallback() {
    final String letter = _avatarLetter(
      _displayName.isEmpty ? widget.displayName : _displayName,
    );
    return SizedBox.square(
      dimension: widget.size,
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
                fontSize: widget.size * 0.52,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _avatarLetter(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return 'A';
    final String first = trimmed.substring(0, 1).toUpperCase();
    return first.trim().isEmpty ? 'A' : first;
  }
}
