import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

Future<void> showRequestChatModal({
  required BuildContext context,
  required String requestId,
  required String clientEmail,
  required String artistEmail,
  required String clientName,
  required String artistName,
  // Distinguishes a separate thread (e.g. AI support) for the same request
  // without corrupting requestId, which must stay a valid uuid — it's
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
  static const String _aiAssistantEmail = 'ai.chatbot@jnt.com';
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

    if (_normalizeEmail(widget.artistEmail) == _aiAssistantEmail) {
      await _ensureAiWelcomeMessage();
    }
  }

  static const String _aiWelcomeText =
      'Hi! I\'m your JNT Assistant.\n'
      'I can help you with order status, payment updates, delivery updates, '
      'reviews, tips, and support questions.\n'
      'Please choose one:\n\n'
      '1. Check my order status\n'
      '2. Payment help\n'
      '3. Shipping or delivery update\n'
      '4. Leave a review\n'
      '5. Add a tip\n'
      '6. Contact support';

  Future<void> _ensureAiWelcomeMessage() async {
    final existing = await _supabase
        .from('request_chat_messages')
        .select('id')
        .eq('conversation_id', _conversationId)
        .limit(1);
    if (existing.isNotEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    await _supabase.from('request_chat_messages').insert({
      'conversation_id': _conversationId,
      'request_id': widget.requestId,
      'client_email': _normalizeEmail(widget.clientEmail),
      'artist_email': _aiAssistantEmail,
      'client_name': widget.clientName.trim(),
      'artist_name': 'JNT Assistant',
      'sender_email': _aiAssistantEmail,
      'sender_name': 'JNT Assistant',
      'text': _aiWelcomeText,
      'attachment_url': '',
      'attachment_type': '',
      'attachment_name': '',
      'is_system': true,
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    await _supabase
        .from('request_chats')
        .update({
          'last_message': _aiWelcomeText,
          'last_message_at': nowIso,
          'last_sender_email': _aiAssistantEmail,
          'last_sender_name': 'JNT Assistant',
          'updated_at': nowIso,
        })
        .eq('id', _conversationId);
  }

  // Real online/offline status via Supabase Realtime Presence, scoped to
  // this conversation. The previous implementation read is_online/
  // last_seen_at/presence columns that don't exist anywhere in the schema,
  // so it always reported "Offline" regardless of the peer's actual state.
  void _initPresenceChannel() {
    // The AI assistant isn't a real logged-in session, so it can never
    // "track" itself on a presence channel — always show it as available
    // rather than a misleading (and permanently stuck) "Offline".
    if (_peerEmail == _aiAssistantEmail) {
      setState(() => _peerPresence = _PeerPresence.available);
      return;
    }

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

  Future<void> _sendQuickChoice(String choice) async {
    final text = choice.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _sendMessage(text: text);
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

    // Client-side auto-reply. Mirrors the server-side "ai-chat-assistant"
    // Edge Function (supabase/functions/ai-chat-assistant) so the assistant
    // still replies immediately in this app even before/without that
    // function's Postgres-webhook trigger being deployed to a given project.
    if (_normalizeEmail(widget.artistEmail) == _aiAssistantEmail &&
        _currentEmail != _aiAssistantEmail) {
      try {
        await _sendAiAssistantReply(userText: text.trim());
      } catch (_) {
        // The user's own message already sent successfully; a failed
        // auto-reply shouldn't surface as a send error.
      }
    }
  }

  Future<void> _sendAiAssistantReply({required String userText}) async {
    final replyText = await _buildAiReply(userText);
    final nowIso = DateTime.now().toIso8601String();

    await _supabase.from('request_chat_messages').insert({
      'conversation_id': _conversationId,
      'request_id': widget.requestId,
      'client_email': _normalizeEmail(widget.clientEmail),
      'artist_email': _aiAssistantEmail,
      'client_name': widget.clientName.trim(),
      'artist_name': 'JNT Assistant',
      'sender_email': _aiAssistantEmail,
      'sender_name': 'JNT Assistant',
      'text': replyText,
      'attachment_url': '',
      'attachment_type': '',
      'attachment_name': '',
      'created_at': nowIso,
      'updated_at': nowIso,
    });

    await _supabase
        .from('request_chats')
        .update({
          'last_message': replyText,
          'last_message_at': nowIso,
          'last_sender_email': _aiAssistantEmail,
          'last_sender_name': 'JNT Assistant',
          'updated_at': nowIso,
        })
        .eq('id', _conversationId);
  }

  Future<String> _buildAiReply(String userText) async {
    final intent = _detectAiIntent(userText);
    switch (intent) {
      case _AiIntent.orderStatus:
        return _replyOrderStatus();
      case _AiIntent.payment:
        return _replyPayment();
      case _AiIntent.shipping:
        return _replyShipping();
      case _AiIntent.review:
        return _replyReview();
      case _AiIntent.tip:
        return _replyTip();
      case _AiIntent.support:
        return _replySupport(userText);
      case _AiIntent.unknown:
        return _aiWelcomeText;
    }
  }

  _AiIntent _detectAiIntent(String raw) {
    final text = raw.trim().toLowerCase();

    switch (text) {
      case '1':
        return _AiIntent.orderStatus;
      case '2':
        return _AiIntent.payment;
      case '3':
        return _AiIntent.shipping;
      case '4':
        return _AiIntent.review;
      case '5':
        return _AiIntent.tip;
      case '6':
        return _AiIntent.support;
    }

    if (text == 'check my order status') return _AiIntent.orderStatus;
    if (text == 'payment help') return _AiIntent.payment;
    if (text == 'shipping or delivery update') return _AiIntent.shipping;
    if (text == 'leave a review') return _AiIntent.review;
    if (text == 'add a tip') return _AiIntent.tip;
    if (text == 'contact support') return _AiIntent.support;

    if (RegExp(r'\bstatus\b|\btrack(ing)?\b.*order|order.*where').hasMatch(text)) {
      return _AiIntent.orderStatus;
    }
    if (RegExp(r'\bpay(ment)?\b|\bcharge\b|\brefund\b|\binvoice\b').hasMatch(text)) {
      return _AiIntent.payment;
    }
    if (RegExp(r'\bship(ping|ped)?\b|\bdeliver(y|ed)?\b|\btrack(ing)?\b').hasMatch(text)) {
      return _AiIntent.shipping;
    }
    if (RegExp(r'\breview\b|\brate\b|\brating\b').hasMatch(text)) {
      return _AiIntent.review;
    }
    if (RegExp(r'\btip\b|\bgratuity\b').hasMatch(text)) {
      return _AiIntent.tip;
    }
    if (RegExp(r'\bsupport\b|\bhelp\b|\bhuman\b|\bagent\b|\bcontact\b').hasMatch(text)) {
      return _AiIntent.support;
    }
    return _AiIntent.unknown;
  }

  static const String _requestColumns =
      'status, client_status, artist_status, order_number, '
      'accepted_by_artist_name, payment_status, payment_amount, currency, '
      'paid_at, shipping_status, tracking_number, shipped_at, delivered_at, '
      'cancelled_at, cancel_reason';

  Future<Map<String, dynamic>?> _fetchRequestRow() async {
    final requestId = widget.requestId.trim();
    if (requestId.isEmpty) return null;

    try {
      final clientRow = await _supabase
          .from('client_custom_requests')
          .select(_requestColumns)
          .eq('id', requestId)
          .maybeSingle();
      if (clientRow != null) return clientRow;
    } catch (_) {}

    try {
      final companyRow = await _supabase
          .from('company_custom_requests')
          .select(_requestColumns)
          .eq('id', requestId)
          .maybeSingle();
      return companyRow;
    } catch (_) {
      return null;
    }
  }

  String _humanize(String value) {
    final withSpaces = value.trim().replaceAll(RegExp(r'[_-]+'), ' ');
    if (withSpaces.isEmpty) return withSpaces;
    return withSpaces
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _formatDate(Object? value) {
    final parsed = DateTime.tryParse((value ?? '').toString());
    if (parsed == null) return '';
    return '${parsed.month}/${parsed.day}/${parsed.year}';
  }

  Future<String> _replyOrderStatus() async {
    final row = await _fetchRequestRow();
    if (row == null) {
      return "I couldn't find that order. Could you confirm the order number?";
    }

    final cancelledAt = row['cancelled_at'];
    if (cancelledAt != null) {
      final reason = (row['cancel_reason'] ?? '').toString().trim();
      return 'Order ${row['order_number'] ?? ''} was cancelled'
          '${reason.isNotEmpty ? ' (reason: $reason)' : ''}. '
          'You can resubmit a new request any time from your orders page.';
    }

    final status = (row['status'] ?? 'pending').toString();
    final artist = (row['accepted_by_artist_name'] ?? '').toString().trim();
    final artistLine = artist.isNotEmpty
        ? 'Your artist, $artist, is assigned.'
        : 'An artist has not been assigned yet.';
    return 'Order ${row['order_number'] ?? ''} status: ${_humanize(status)}. $artistLine';
  }

  Future<String> _replyPayment() async {
    final row = await _fetchRequestRow();
    if (row == null) {
      return "I couldn't find payment details for that order. Could you confirm the order number?";
    }

    final status = (row['payment_status'] ?? '').toString().trim();
    if (status.isEmpty || status.toLowerCase() == 'pending') {
      return 'No payment has been made yet for this order. You can complete payment from the order details page.';
    }

    final amount = row['payment_amount'];
    final currency = (row['currency'] ?? 'USD').toString();
    final paidAt = _formatDate(row['paid_at']);
    final amountLine = amount != null ? ' of $currency $amount' : '';
    final dateLine = paidAt.isNotEmpty ? ' on $paidAt' : '';
    return 'Payment status: ${_humanize(status)}$amountLine$dateLine.';
  }

  Future<String> _replyShipping() async {
    final row = await _fetchRequestRow();
    if (row == null) {
      return "I couldn't find shipping details for that order. Could you confirm the order number?";
    }

    final deliveredAt = row['delivered_at'];
    if (deliveredAt != null) {
      return 'Your order was delivered on ${_formatDate(deliveredAt)}.';
    }

    final shippedAt = row['shipped_at'];
    final tracking = (row['tracking_number'] ?? '').toString().trim();
    if (shippedAt != null || tracking.isNotEmpty) {
      final trackingLine = tracking.isNotEmpty ? ' Tracking number: $tracking.' : '';
      final shippedLine = shippedAt != null ? ' Shipped on ${_formatDate(shippedAt)}.' : '';
      return 'Your order is on its way.$shippedLine$trackingLine';
    }

    return 'Your order has not shipped yet. We will update tracking as soon as it ships.';
  }

  Future<String> _replyReview() async {
    final requestId = widget.requestId.trim();
    if (requestId.isEmpty) {
      return "I couldn't find that order to check for a review.";
    }

    try {
      final data = await _supabase
          .from('reviews')
          .select('rating')
          .eq('order_id', requestId)
          .maybeSingle();
      if (data != null) {
        return 'You already left a ${data['rating']}-star review for this order. Thank you!';
      }
    } catch (_) {}

    final artist = widget.artistName.trim();
    return "You haven't left a review yet${artist.isNotEmpty && artist != 'JNT AI Assistant' ? ' for $artist' : ''}. "
        'Once your order is delivered, you can leave a review from the order details page.';
  }

  Future<String> _replyTip() async {
    final requestId = widget.requestId.trim();
    if (requestId.isEmpty) {
      return "I couldn't find that order to check tip status.";
    }

    try {
      final data = await _supabase
          .from('tips')
          .select('status, tip_amount')
          .eq('order_id', requestId)
          .maybeSingle();
      if (data != null) {
        return 'You already added a tip of \$${data['tip_amount']} (${_humanize((data['status'] ?? '').toString())}).';
      }
    } catch (_) {}

    return "You haven't added a tip for this order yet. You can add one from the order details page after delivery.";
  }

  Future<String> _replySupport(String userText) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      await _supabase.from('admin_notifications').insert({
        'type': 'ai_chat_support_request',
        'source': 'request_chat_messages',
        'request_id': widget.requestId.trim(),
        'title': 'Support requested via AI Assistant',
        'message':
            '${widget.clientName.trim().isNotEmpty ? widget.clientName.trim() : widget.clientEmail} '
            'asked for support: "${userText.length > 300 ? userText.substring(0, 300) : userText}"',
        'date_label': nowIso,
        'event_at': nowIso,
        'payload': {
          'conversationId': _conversationId,
          'clientEmail': _normalizeEmail(widget.clientEmail),
        },
        'created_at': nowIso,
        'updated_at': nowIso,
      });
    } catch (_) {}

    return "I've let our support team know you need help — someone will follow up here shortly. "
        'In the meantime, tell me more about the issue and I can try to help right away.';
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
                    final isAiAssistant = senderEmail == _aiAssistantEmail;
                    final quickChoices = isAiAssistant
                        ? _assistantChoices(text)
                        : const <String>[];
                    final showQuickChoices = !isMine && quickChoices.isNotEmpty;
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

enum _AiIntent {
  orderStatus,
  payment,
  shipping,
  review,
  tip,
  support,
  unknown,
}

String _conversationIdForRequest(String requestId) {
  final clean = requestId.trim();
  return clean.isEmpty ? 'request_unknown' : 'request_$clean';
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
