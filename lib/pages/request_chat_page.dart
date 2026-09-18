import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notifications_service.dart';
import '../theme/app_colors.dart';

Future<void> showRequestChatModal({
  required BuildContext context,
  required String requestId,
  required String clientEmail,
  required String artistEmail,
  required String clientName,
  required String artistName,
  // Distinguishes a separate thread (e.g. a group order's per-recipient
  // chats) for the same request without corrupting requestId, which must
  // stay a valid uuid — it's
  // written as-is into request_chat_messages.request_id / request_chats
  // .request_id, both uuid columns.
  String conversationSuffix = '',
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Chat',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) {
      return SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight;
            final panelWidth = (maxWidth * 0.92).clamp(300.0, 390.0);
            final panelHeight = (maxHeight * 0.72).clamp(420.0, 690.0);
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              child: Align(
                alignment: Alignment.bottomRight,
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Material(
                    color: AppColors.alabaster,
                    child: SizedBox(
                      width: panelWidth,
                      height: panelHeight,
                      child: RequestChatModal(
                        requestId: requestId,
                        clientEmail: clientEmail,
                        artistEmail: artistEmail,
                        clientName: clientName,
                        artistName: artistName,
                        conversationSuffix: conversationSuffix,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
    transitionBuilder: (_, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curve),
          child: child,
        ),
      );
    },
  );
}

class RequestChatModal extends StatefulWidget {
  const RequestChatModal({
    super.key,
    required this.requestId,
    required this.clientEmail,
    required this.artistEmail,
    required this.clientName,
    required this.artistName,
    this.conversationSuffix = '',
  });

  final String requestId;
  final String clientEmail;
  final String artistEmail;
  final String clientName;
  final String artistName;
  final String conversationSuffix;

  @override
  State<RequestChatModal> createState() => _RequestChatModalState();
}

class _RequestChatModalState extends State<RequestChatModal> {
  static const String _attachmentBucket = 'request-chat-attachments';

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _sending = false;
  _PeerPresence _peerPresence = _PeerPresence.offline;
  RealtimeChannel? _presenceChannel;

  SupabaseClient get _supabase => Supabase.instance.client;

  String get _conversationId {
    final base = _conversationIdForRequest(widget.requestId);
    final suffix = widget.conversationSuffix.trim();
    return suffix.isEmpty ? base : '${base}_$suffix';
  }

  String get _currentEmail => _normalizeEmail(
        _supabase.auth.currentUser?.email ?? '',
      );

  String get _peerEmail {
    final client = _normalizeEmail(widget.clientEmail);
    final artist = _normalizeEmail(widget.artistEmail);
    return _currentEmail == client ? artist : client;
  }

  String get _currentName {
    final user = _supabase.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final display = _firstNonEmpty([
      metadata['displayName'],
      metadata['display_name'],
      metadata['fullName'],
      metadata['full_name'],
      metadata['name'],
    ]);
    if (display.isNotEmpty) return display;

    final email = (user?.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String get _chatTitle {
    if (_currentEmail == _normalizeEmail(widget.clientEmail)) {
      final artist = widget.artistName.trim();
      return artist.isNotEmpty ? artist : 'Artist';
    }
    final client = widget.clientName.trim();
    return client.isNotEmpty ? client : 'Client';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_ensureRoom().catchError((Object e, StackTrace st) {
      debugPrint('RequestChatModal: failed to ensure room: $e');
    }));
    _initPresenceChannel();
    if (_currentEmail.isNotEmpty) {
      unawaited(
        NotificationsService.markChatNotificationsReadForConversation(
          receiverEmail: _currentEmail,
          conversationId: _conversationId,
        ),
      );
    }
  }

  @override
  void dispose() {
    final channel = _presenceChannel;
    if (channel != null) {
      unawaited(channel.untrack());
      unawaited(_supabase.removeChannel(channel));
    }
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureRoom() async {
    final nowIso = DateTime.now().toIso8601String();
    // "id" is the actual primary key (and the FK target from
    // request_chat_messages.conversation_id) — it must be set explicitly.
    // "conversation_id" alone has no unique constraint, so upserting on it
    // fails outright, which previously blocked every message send.
    await _supabase.from('request_chats').upsert(
      {
        'id': _conversationId,
        'conversation_id': _conversationId,
        'request_id': widget.requestId,
        'client_email': _normalizeEmail(widget.clientEmail),
        'artist_email': _normalizeEmail(widget.artistEmail),
        'client_name': widget.clientName.trim(),
        'artist_name': widget.artistName.trim(),
        'updated_at': nowIso,
      },
      onConflict: 'id',
    );
  }

  // Real online/offline status via Supabase Realtime Presence, scoped to
  // this conversation. The previous implementation read is_online/
  // last_seen_at/presence columns that don't exist anywhere in the schema,
  // so it always reported "Offline" regardless of the peer's actual state.
  void _initPresenceChannel() {
    final channel = _supabase.channel('presence:$_conversationId');
    _presenceChannel = channel;

    channel.onPresenceSync((_) => _updatePresenceFromChannel());
    channel.onPresenceJoin((_) => _updatePresenceFromChannel());
    channel.onPresenceLeave((_) => _updatePresenceFromChannel());

    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed && _currentEmail.isNotEmpty) {
        try {
          await channel.track({'email': _currentEmail});
        } catch (e) {
          debugPrint('RequestChatModal: failed to track presence: $e');
        }
      }
    });
  }

  void _updatePresenceFromChannel() {
    final channel = _presenceChannel;
    if (channel == null || !mounted) return;

    final peer = _peerEmail;
    final isPeerPresent = channel.presenceState().any(
          (state) => state.presences.any(
            (p) => _normalizeEmail((p.payload['email'] ?? '').toString()) == peer,
          ),
        );

    setState(() {
      _peerPresence = isPeerPresent ? _PeerPresence.available : _PeerPresence.offline;
    });
  }

  void _refreshPeerPresence() => _updatePresenceFromChannel();

  Future<void> _sendText() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _sendMessage(text: text);
      _messageCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      _showSendError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSendError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not send message: $error')),
    );
  }

  Future<void> _sendMessage({
    required String text,
    String attachmentUrl = '',
    String attachmentType = '',
    String attachmentName = '',
  }) async {
    await _ensureRoom();

    final nowIso = DateTime.now().toIso8601String();
    final row = <String, dynamic>{
      'conversation_id': _conversationId,
      'request_id': widget.requestId,
      'client_email': _normalizeEmail(widget.clientEmail),
      'artist_email': _normalizeEmail(widget.artistEmail),
      'client_name': widget.clientName.trim(),
      'artist_name': widget.artistName.trim(),
      'sender_email': _currentEmail,
      'sender_name': _currentName,
      'text': text.trim(),
      'attachment_url': attachmentUrl.trim(),
      'attachment_type': attachmentType.trim(),
      'attachment_name': attachmentName.trim(),
      'created_at': nowIso,
      'updated_at': nowIso,
    };

    await _supabase.from('request_chat_messages').insert(row);

    await _supabase
        .from('request_chats')
        .update({
          'last_message': text.trim().isNotEmpty
              ? text.trim()
              : (attachmentType == 'image' ? 'Photo' : 'Attachment'),
          'last_message_at': nowIso,
          'last_sender_email': _currentEmail,
          'updated_at': nowIso,
        })
        .eq('id', _conversationId);

    // Let the peer know a message is waiting -- reuses the existing in-app
    // notification pipeline (bell badge, notifications list) rather than a
    // chat-specific one. Best-effort: a failed notification insert
    // shouldn't surface as a send error, since the message itself already
    // sent successfully.
    final peer = _peerEmail;
    if (peer.isNotEmpty) {
      unawaited(
        NotificationsService.createUserNotification(
          receiverEmail: peer,
          title: 'New message from $_currentName',
          body: text.trim().isNotEmpty
              ? text.trim()
              : (attachmentType == 'image' ? 'Sent a photo' : 'Sent an attachment'),
          type: 'chat_message',
          orderId: widget.requestId,
          extra: <String, dynamic>{
            'requestId': widget.requestId,
            'conversationId': _conversationId,
            'conversationSuffix': widget.conversationSuffix,
            'clientEmail': widget.clientEmail,
            'artistEmail': widget.artistEmail,
            'clientName': widget.clientName,
            'artistName': widget.artistName,
            'senderName': _currentName,
          },
        ).catchError((Object e, StackTrace st) {
          debugPrint('RequestChatModal: failed to notify peer: $e');
        }),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _watchMessages() {
    return _supabase
        .from('request_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', _conversationId)
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false),
        );
  }

  Future<void> _openAttachmentOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: AppColors.alabaster,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.zero,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: AppColors.snow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: const BorderSide(color: AppColors.alabaster),
              ),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndSendImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: AppColors.snow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: const BorderSide(color: AppColors.alabaster),
              ),
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _pickAndSendImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = _inferExt(file.name);
      final storagePath =
          '$_conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from(_attachmentBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentTypeForExt(ext),
              upsert: true,
            ),
          );

      final url = _supabase.storage
          .from(_attachmentBucket)
          .getPublicUrl(storagePath)
          .trim();

      await _sendMessage(
        text: _messageCtrl.text.trim(),
        attachmentUrl: url,
        attachmentType: 'image',
        attachmentName: file.name.trim(),
      );
      _messageCtrl.clear();
      _scrollToBottom();
    } catch (e) {
      _showSendError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _inferExt(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 84,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Request chat',
      child: Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close chat',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            _PresenceDot(status: _peerPresence),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      fontFamily: 'Arial',
                    ),
                  ),
                  Text(
                    _peerPresence.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh status',
            onPressed: _refreshPeerPresence,
            icon: const Icon(Icons.refresh_rounded, size: 18),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _watchMessages(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Start the discussion.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                      ),
                    ),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final data = rows[index];
                    final senderEmail = _normalizeEmail(
                      _value(data, 'sender_email', 'senderEmail'),
                    );
                    final isMine = senderEmail == _currentEmail;
                    final senderName = _value(data, 'sender_name', 'senderName');
                    final text = _value(data, 'text');
                    final attachmentUrl = _value(
                      data,
                      'attachment_url',
                      'attachmentUrl',
                    );
                    final attachmentType = _value(
                      data,
                      'attachment_type',
                      'attachmentType',
                    ).toLowerCase();
                    final hasAttachment = attachmentUrl.isNotEmpty;
                    return Align(
                      alignment:
                          isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: isMine ? AppColors.blackCat : AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: AppColors.alabaster),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMine && senderName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  senderName,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                              ),
                            if (hasAttachment && attachmentType == 'image')
                              Semantics(
                                button: true,
                                label: 'View attachment full screen',
                                child: ExcludeSemantics(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _openImagePreview(attachmentUrl),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.zero,
                                      child: Image.network(
                                        attachmentUrl,
                                        fit: BoxFit.cover,
                                        height: 170,
                                        width: 220,
                                        cacheWidth: 660,
                                        cacheHeight: 510,
                                        errorBuilder: (_, _, _) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (hasAttachment && attachmentType == 'image')
                              const SizedBox(height: 6),
                            if (text.isNotEmpty)
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: isMine
                                      ? AppColors.snow
                                      : AppColors.blackCat,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            decoration: BoxDecoration(
              color: AppColors.alabaster,
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _openAttachmentOptions,
                  icon: const Icon(Icons.attach_file_rounded),
                  tooltip: 'Attachment',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: InputDecoration(
                      hintText: 'Type a message',
                      filled: true,
                      fillColor: AppColors.snow,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: const BorderSide(
                          color: AppColors.alabaster,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: const BorderSide(
                          color: AppColors.alabaster,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                    ),
                    onPressed: _sending ? null : _sendText,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Send',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              fontFamily: 'Arial',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  // Higher than kMaxImageDecodeDimension: this preview
                  // allows 4x pinch-zoom (InteractiveViewer maxScale: 4),
                  // so a tighter cap would look visibly soft when zoomed.
                  cacheWidth: 2048,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close image preview',
                onPressed: () => Navigator.pop(context),
                icon:
                    const Icon(Icons.close_rounded, color: AppColors.blackCat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _conversationIdForRequest(String requestId) {
  final clean = requestId.trim();
  return clean.isEmpty ? 'request_unknown' : 'request_$clean';
}

/// Public mirror of [RequestChatModal]'s own `_conversationId` getter, so
/// callers that need to know a conversation id *before* opening the modal
/// (e.g. a group-member picker checking which recipient has an unread
/// message) can compute the exact same id without duplicating the format.
String buildChatConversationId(
  String requestId, {
  String conversationSuffix = '',
}) {
  final base = _conversationIdForRequest(requestId);
  final suffix = conversationSuffix.trim();
  return suffix.isEmpty ? base : '${base}_$suffix';
}

String _normalizeEmail(String email) => email.trim().toLowerCase();

String _firstNonEmpty(List<Object?> values) {
  for (final raw in values) {
    final value = (raw ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _value(
  Map<String, dynamic> data,
  String first, [
  String? second,
  String? third,
]) {
  final raw = data[first] ?? (second == null ? null : data[second]) ??
      (third == null ? null : data[third]);
  return (raw ?? '').toString().trim();
}

enum _PeerPresence {
  available('Available', Color(0xFF2E8B57)),
  offline('Offline', Color(0xFF9E9E9E));

  const _PeerPresence(this.label, this.color);
  final String label;
  final Color color;
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.status});

  final _PeerPresence status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
    );
  }
}
