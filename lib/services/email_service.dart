import 'package:cloud_firestore/cloud_firestore.dart';

class EmailService {
  static Future<void> sendVerifiedWelcomeEmail({
    required String userEmail,
    required String userName,
    required String accountType,
  }) async {
    final templateName = switch (accountType) {
      'client' => 'client_welcome_verified',
      'artist' => 'artist_welcome_verified',
      'client+artist' => 'creator_welcome_verified',
      'company' => 'brand_welcome_verified',
      _ => 'client_welcome_verified',
    };

    final encodedRole = Uri.encodeComponent(accountType);

    final appLink =
        'https://jnt-app-c3097.web.app/open-app?type=account-verified&role=$encodedRole';

    await FirebaseFirestore.instance.collection('mail').add({
      'to': userEmail,
      'template': {
        'name': templateName,
        'data': {
          'userName': userName,
          'appLink': appLink,
        },
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}