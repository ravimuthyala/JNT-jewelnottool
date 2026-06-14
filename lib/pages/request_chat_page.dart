import 'package:flutter/material.dart';
import '../services/supabase_firebase_compat.dart';
import 'package:image_picker/image_picker.dart';

import '../services/request_chat_service.dart';
import '../theme/app_colors.dart';

Future<void> showRequestChatModal({
  required BuildContext context,
  required String requestId,
  required String clientEmail,
  required String artistEmail,
  required String clientName,
  required String artistName,
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
  });

  final String requestId;
  final String clientEmail;
  final String artistEmail;
  final String clientName;
  final String artistName;

  @override
  State<RequestChatModal> createState() => _RequestChatModalState();
}

class _RequestChatModalState extends State<RequestChatModal> {
  static const String _aiAssistantEmail = 'ai.chatbot@jnt.com';
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();
  bool _sending = false;
  _PeerPresence _peerPresence = _PeerPresence.offline;

  String get _conversationId =>
      RequestChatService.conversationIdForRequest(widget.requestId);

  String get _currentEmail => RequestChatService.normalizeEmail(
    FirebaseAuth.instance.currentUser?.email ?? '',
  );

  String get _peerEmail {
    final client = RequestChatService.normalizeEmail(widget.clientEmail);
    final artist = RequestChatService.normalizeEmail(widget.artistEmail);
    return _currentEmail == client ? artist : client;
  }

  String get _currentName {
    final user = FirebaseAuth.instance.currentUser;
    final display = (user?.displayName ?? '').trim();
    if (display.isNotEmpty) return display;
    final email = (user?.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String get _chatTitle {
    if (_currentEmail ==
        RequestChatService.normalizeEmail(widget.clientEmail)) {
      final artist = widget.artistName.trim();
      return artist.isNotEmpty ? artist : 'Artist';
    }
    final client = widget.clientName.trim();
    return client.isNotEmpty ? client : 'Client';
  }

  @override
  void initState() {
    super.initState();
    _ensureRoom();
    _refreshPeerPresence();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureRoom() async {
    await RequestChatService.ensureConversation(
      conversationId: _conversationId,
      requestId: widget.requestId,
      clientEmail: widget.clientEmail,
      artistEmail: widget.artistEmail,
      clientName: widget.clientName,
      artistName: widget.artistName,
    );
  }

  Future<void> _refreshPeerPresence() async {
    final status = await _resolvePresenceForEmail(_peerEmail);
    if (!mounted) return;
    setState(() => _peerPresence = status);
  }

  Future<_PeerPresence> _resolvePresenceForEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return _PeerPresence.offline;

    final db = FirebaseFirestore.instance;
    final collections = <String>['client', 'artist', 'client_artist'];
    Map<String, dynamic>? data;
    for (final c in collections) {
      final snap = await db
          .collection(c)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        data = snap.docs.first.data();
        break;
      }
    }

    if (data == null) return _PeerPresence.offline;

    final dynamic isOnlineRaw =
        data['isOnline'] ??
        data['online'] ??
        (data['presence'] as Map<String, dynamic>?)?['isOnline'];
    if (isOnlineRaw == true) return _PeerPresence.available;

    DateTime? toDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final lastSeen =
        toDate(data['lastSeenAt']) ??
        toDate(data['lastActiveAt']) ??
        toDate(data['updatedAt']) ??
        toDate((data['presence'] as Map<String, dynamic>?)?['lastSeenAt']) ??
        toDate((data['presence'] as Map<String, dynamic>?)?['lastActiveAt']);
    if (lastSeen == null) return _PeerPresence.offline;

    final diff = DateTime.now().difference(lastSeen);
    if (diff <= const Duration(minutes: 5)) return _PeerPresence.available;
    if (diff <= const Duration(hours: 12)) return _PeerPresence.away;
    return _PeerPresence.offline;
  }

  Future<void> _sendText() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await RequestChatService.sendMessage(
        conversationId: _conversationId,
        requestId: widget.requestId,
        clientEmail: widget.clientEmail,
        artistEmail: widget.artistEmail,
        clientName: widget.clientName,
        artistName: widget.artistName,
        senderEmail: _currentEmail,
        senderName: _currentName,
        text: text,
      );
      _messageCtrl.clear();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendQuickChoice(String choice) async {
    final text = choice.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await RequestChatService.sendMessage(
        conversationId: _conversationId,
        requestId: widget.requestId,
        clientEmail: widget.clientEmail,
        artistEmail: widget.artistEmail,
        clientName: widget.clientName,
        artistName: widget.artistName,
        senderEmail: _currentEmail,
        senderName: _currentName,
        text: text,
      );
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<String> _assistantChoices(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final choices = <String>[];
    for (final line in lines) {
      final match = RegExp(r'^\d+\.\s+(.+)$').firstMatch(line);
      if (match != null) {
        choices.add((match.group(1) ?? '').trim());
      }
    }
    return choices;
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
          'chat_attachments/$_conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentTypeForExt(ext)),
      );
      final url = await ref.getDownloadURL();
      await RequestChatService.sendMessageWithAttachment(
        conversationId: _conversationId,
        requestId: widget.requestId,
        clientEmail: widget.clientEmail,
        artistEmail: widget.artistEmail,
        clientName: widget.clientName,
        artistName: widget.artistName,
        senderEmail: _currentEmail,
        senderName: _currentName,
        text: _messageCtrl.text.trim(),
        attachmentUrl: url,
        attachmentType: 'image',
        attachmentName: file.name.trim(),
      );
      _messageCtrl.clear();
      _scrollToBottom();
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
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        leading: IconButton(
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: RequestChatService.watchMessages(_conversationId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
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
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderEmail = RequestChatService.normalizeEmail(
                      (data['senderEmail'] ?? '').toString(),
                    );
                    final isMine = senderEmail == _currentEmail;
                    final senderName = (data['senderName'] ?? '')
                        .toString()
                        .trim();
                    final text = (data['text'] ?? '').toString().trim();
                    final attachmentUrl = (data['attachmentUrl'] ?? '')
                        .toString()
                        .trim();
                    final attachmentType = (data['attachmentType'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    final hasAttachment = attachmentUrl.isNotEmpty;
                    final isAiAssistant = senderEmail == _aiAssistantEmail;
                    final quickChoices = isAiAssistant
                        ? _assistantChoices(text)
                        : const <String>[];
                    final showQuickChoices =
                        !isMine && quickChoices.isNotEmpty;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
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
                              GestureDetector(
                                onTap: () => _openImagePreview(attachmentUrl),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.zero,
                                  child: Image.network(
                                    attachmentUrl,
                                    fit: BoxFit.cover,
                                    height: 170,
                                    width: 220,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
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
                            if (showQuickChoices) ...[
                              const SizedBox(height: 10),
                              ...quickChoices.map(
                                (choice) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _sending
                                          ? null
                                          : () => _sendQuickChoice(choice),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.blackCat,
                                        foregroundColor: AppColors.snow,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: Text(
                                        choice,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Arial',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: AppColors.blackCat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PeerPresence {
  available('Available', Color(0xFF2E8B57)),
  away('Away', Color(0xFFFFA726)),
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

