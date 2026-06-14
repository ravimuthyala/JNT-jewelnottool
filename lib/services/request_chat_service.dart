import 'supabase_firebase_compat.dart';

class RequestChatService {
  RequestChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _aiAssistantEmail = 'ai.chatbot@jnt.com';

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static String conversationIdForRequest(String requestId) =>
      'request_${requestId.trim()}';

  static CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('Request_Chats');

  static CollectionReference<Map<String, dynamic>> messagesRef(
    String conversationId,
  ) => _rooms.doc(conversationId).collection('messages');

  static Future<void> ensureConversation({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String artistEmail,
    required String clientName,
    required String artistName,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final normalizedClient = normalizeEmail(clientEmail);
    final normalizedArtist = normalizeEmail(artistEmail);
    await _rooms.doc(conversationId).set({
      'requestId': requestId.trim(),
      'clientEmail': normalizedClient,
      'artistEmail': normalizedArtist,
      'clientName': clientName.trim(),
      'artistName': artistName.trim(),
      'participants': <String>[
        if (normalizedClient.isNotEmpty) normalizedClient,
        if (normalizedArtist.isNotEmpty) normalizedArtist,
      ],
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': nowMs,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': nowMs,
    }, SetOptions(merge: true));

    if (normalizedArtist == _aiAssistantEmail) {
      await _ensureAiAssistantWelcomeMessage(
        conversationId: conversationId,
        requestId: requestId,
        clientEmail: normalizedClient,
        clientName: clientName,
      );
    }
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(
    String conversationId,
  ) {
    return messagesRef(
      conversationId,
    ).orderBy('createdAtMs', descending: false).snapshots();
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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await ensureConversation(
      conversationId: conversationId,
      requestId: requestId,
      clientEmail: clientEmail,
      artistEmail: artistEmail,
      clientName: clientName,
      artistName: artistName,
    );
    await messagesRef(conversationId).add({
      'requestId': requestId.trim(),
      'text': trimmed,
      'senderEmail': normalizeEmail(senderEmail),
      'senderName': senderName.trim(),
      'attachmentUrl': attachmentUrl.trim(),
      'attachmentType': attachmentType.trim(),
      'attachmentName': attachmentName.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': nowMs,
    });
    await _rooms.doc(conversationId).set({
      'lastMessage': trimmed.isNotEmpty ? trimmed : attachmentType.trim(),
      'lastSenderEmail': normalizeEmail(senderEmail),
      'lastSenderName': senderName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': nowMs,
    }, SetOptions(merge: true));
  }

  static Future<void> _ensureAiAssistantWelcomeMessage({
    required String conversationId,
    required String requestId,
    required String clientEmail,
    required String clientName,
  }) async {
    final existing = await messagesRef(conversationId).limit(1).get();
    if (existing.docs.isNotEmpty) return;

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
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await messagesRef(conversationId).add({
      'requestId': requestId.trim(),
      'text': welcomeText,
      'senderEmail': _aiAssistantEmail,
      'senderName': 'JNT Assistant',
      'attachmentUrl': '',
      'attachmentType': '',
      'attachmentName': '',
      'isSystem': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtMs': nowMs,
    });
    await _rooms.doc(conversationId).set({
      'lastMessage': welcomeText,
      'lastSenderEmail': _aiAssistantEmail,
      'lastSenderName': 'JNT Assistant',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedAtMs': nowMs,
    }, SetOptions(merge: true));
  }
}
