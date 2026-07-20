import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestChatService {
  RequestChatService._();

  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _aiAssistantEmail = 'ai.chatbot@jnt.com';

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String conversationIdForRequest(String requestId) =>
      'request_${requestId.trim()}';

  static Future<void> ensureConversation({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String artistEmail,
    required String clientName,
    required String artistName,
  }) async {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final nowMs = now.millisecondsSinceEpoch;
    final normalizedClient = normalizeEmail(clientEmail);
    final normalizedArtist = normalizeEmail(artistEmail);

    final roomPayload = <String, dynamic>{
      'id': conversationId,
      'conversation_id': conversationId,
      'request_id': requestId.trim(),
      'client_email': normalizedClient,
      'artist_email': normalizedArtist,
      'client_name': clientName.trim(),
      'artist_name': artistName.trim(),
      'participants': <String>[
        if (normalizedClient.isNotEmpty) normalizedClient,
        if (normalizedArtist.isNotEmpty) normalizedArtist,
      ],
      'updated_at': nowIso,
      'updated_at_ms': nowMs,
      'created_at': nowIso,
      'created_at_ms': nowMs,
    };

    try {
      await _supabase
          .from('request_chats')
          .upsert(roomPayload, onConflict: 'id');

      if (normalizedArtist == _aiAssistantEmail) {
        await _ensureAiAssistantWelcomeMessage(
          conversationId: conversationId,
          requestId: requestId,
          clientEmail: normalizedClient,
          clientName: clientName,
        );
      }
    } catch (e, st) {
      debugPrint('RequestChatService.ensureConversation failed: $e');
      debugPrint(st.toString());
    }
  }

  static Stream<List<Map<String, dynamic>>> watchMessages(
    String conversationId,
  ) {
    Future<List<Map<String, dynamic>>> load() async {
      final rows = await _supabase
          .from('request_chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at_ms', ascending: true)
          .order('created_at', ascending: true);

      return rows
          .whereType<Map>()
          .map((row) => _messageRowToCompat(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    }

    late StreamController<List<Map<String, dynamic>>> controller;
    Timer? timer;

    Future<void> emit() async {
      if (controller.isClosed) return;
      try {
        controller.add(await load());
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        unawaited(emit());
        timer = Timer.periodic(const Duration(seconds: 3), (_) {
          unawaited(emit());
        });
      },
      onCancel: () {
        timer?.cancel();
      },
    );

    return controller.stream;
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String artistEmail,
    required String clientName,
    required String artistName,
    required String senderEmail,
    required String senderName,
    required String text,
  }) async {
    await _sendMessageCore(
      conversationId: conversationId,
      requestId: requestId,
      clientEmail: clientEmail,
      artistEmail: artistEmail,
      clientName: clientName,
      artistName: artistName,
      senderEmail: senderEmail,
      senderName: senderName,
      text: text,
    );
  }

  static Future<void> sendMessageWithAttachment({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String artistEmail,
    required String clientName,
    required String artistName,
    required String senderEmail,
    required String senderName,
    required String text,
    required String attachmentUrl,
    required String attachmentType,
    String attachmentName = '',
  }) async {
    await _sendMessageCore(
      conversationId: conversationId,
      requestId: requestId,
      clientEmail: clientEmail,
      artistEmail: artistEmail,
      clientName: clientName,
      artistName: artistName,
      senderEmail: senderEmail,
      senderName: senderName,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentName: attachmentName,
    );
  }

  static Future<void> _sendMessageCore({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String artistEmail,
    required String clientName,
    required String artistName,
    required String senderEmail,
    required String senderName,
    required String text,
    String attachmentUrl = '',
    String attachmentType = '',
    String attachmentName = '',
  }) async {
    final trimmed = text.trim();
    final hasAttachment = attachmentUrl.trim().isNotEmpty;
    if (trimmed.isEmpty && !hasAttachment) return;

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final nowMs = now.millisecondsSinceEpoch;

    await ensureConversation(
      conversationId: conversationId,
      requestId: requestId,
      clientEmail: clientEmail,
      artistEmail: artistEmail,
      clientName: clientName,
      artistName: artistName,
    );

    try {
      await _supabase.from('request_chat_messages').insert({
        'conversation_id': conversationId,
        'request_id': requestId.trim(),
        'client_email': normalizeEmail(clientEmail),
        'artist_email': normalizeEmail(artistEmail),
        'client_name': clientName.trim(),
        'artist_name': artistName.trim(),
        'text': trimmed,
        'sender_email': normalizeEmail(senderEmail),
        'sender_name': senderName.trim(),
        'attachment_url': attachmentUrl.trim(),
        'attachment_type': attachmentType.trim(),
        'attachment_name': attachmentName.trim(),
        'created_at': nowIso,
        'created_at_ms': nowMs,
        'updated_at': nowIso,
      });

      await _supabase.from('request_chats').upsert({
        'id': conversationId,
        'conversation_id': conversationId,
        'request_id': requestId.trim(),
        'client_email': normalizeEmail(clientEmail),
        'artist_email': normalizeEmail(artistEmail),
        'client_name': clientName.trim(),
        'artist_name': artistName.trim(),
        'participants': <String>[
          if (normalizeEmail(clientEmail).isNotEmpty) normalizeEmail(clientEmail),
          if (normalizeEmail(artistEmail).isNotEmpty) normalizeEmail(artistEmail),
        ],
        'last_message': trimmed.isNotEmpty ? trimmed : attachmentType.trim(),
        'last_sender_email': normalizeEmail(senderEmail),
        'last_sender_name': senderName.trim(),
        'updated_at': nowIso,
        'updated_at_ms': nowMs,
      }, onConflict: 'id');
    } catch (e, st) {
      debugPrint('RequestChatService._sendMessageCore failed: $e');
      debugPrint(st.toString());
    }
  }

  static Future<void> _ensureAiAssistantWelcomeMessage({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String clientName,
  }) async {
    final existing = await _supabase
        .from('request_chat_messages')
        .select('id')
        .eq('conversation_id', conversationId)
        .limit(1);

    if (existing.isNotEmpty) return;

    final greetingName = clientName.trim().isEmpty ? 'there' : clientName.trim();
    final welcomeText =
        'Hi $greetingName, welcome to JNT. I’m your JNT Assistant.\n'
        'I can help you with order status, payment updates, delivery updates, reviews, tips, and support questions.\n'
        'Please choose one:\n\n'
        '1. Check my order status\n'
        '2. Payment help\n'
        '3. Shipping or delivery update\n'
        '4. Leave a review\n'
        '5. Add a tip\n'
        '6. Contact support';

    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final nowMs = now.millisecondsSinceEpoch;

    await _supabase.from('request_chat_messages').insert({
      'conversation_id': conversationId,
      'request_id': requestId.trim(),
      'client_email': normalizeEmail(clientEmail),
      'artist_email': _aiAssistantEmail,
      'client_name': clientName.trim(),
      'artist_name': 'JNT Assistant',
      'text': welcomeText,
      'sender_email': _aiAssistantEmail,
      'sender_name': 'JNT Assistant',
      'attachment_url': '',
      'attachment_type': '',
      'attachment_name': '',
      'is_system': true,
      'created_at': nowIso,
      'created_at_ms': nowMs,
      'updated_at': nowIso,
    });

    await _supabase.from('request_chats').upsert({
      'id': conversationId,
      'conversation_id': conversationId,
      'request_id': requestId.trim(),
      'client_email': normalizeEmail(clientEmail),
      'artist_email': _aiAssistantEmail,
      'client_name': clientName.trim(),
      'artist_name': 'JNT Assistant',
      'participants': <String>[
        if (normalizeEmail(clientEmail).isNotEmpty) normalizeEmail(clientEmail),
        _aiAssistantEmail,
      ],
      'last_message': welcomeText,
      'last_sender_email': _aiAssistantEmail,
      'last_sender_name': 'JNT Assistant',
      'updated_at': nowIso,
      'updated_at_ms': nowMs,
    }, onConflict: 'id');
  }

  static Map<String, dynamic> _messageRowToCompat(Map<String, dynamic> row) {
    final createdAt = row['created_at'];
    final createdAtMs = row['created_at_ms'] ??
        (createdAt is String
            ? DateTime.tryParse(createdAt)?.millisecondsSinceEpoch
            : null);

    return <String, dynamic>{
      ...row,
      'requestId': row['request_id'],
      'text': row['text'] ?? '',
      'senderEmail': row['sender_email'] ?? '',
      'senderName': row['sender_name'] ?? '',
      'attachmentUrl': row['attachment_url'] ?? '',
      'attachmentType': row['attachment_type'] ?? '',
      'attachmentName': row['attachment_name'] ?? '',
      'isSystem': row['is_system'] == true,
      'createdAt': row['created_at'],
      'createdAtMs': createdAtMs ?? 0,
      'updatedAt': row['updated_at'],
    };
  }
}
