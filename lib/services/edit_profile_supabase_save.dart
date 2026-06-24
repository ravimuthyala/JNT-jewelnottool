import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client_profile_models.dart';

class EditProfileSupabaseSave {
  static SupabaseClient get _client => Supabase.instance.client;

  static String get _uid => (_client.auth.currentUser?.id ?? '').trim();

  static String get _email =>
      (_client.auth.currentUser?.email ?? '').trim().toLowerCase();

  static Future<void> saveBasicInfo(BasicInfo value) async {
    final payload = <String, dynamic>{
      'name': value.name.trim(),
      'displayName': value.name.trim(),
      'email': value.email.trim().toLowerCase(),
      'phone': value.phone.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await _updateProfileSection(
      tables: const <String>['client', 'client_artist'],
      section: 'basic',
      values: payload,
    );

    await _updateProfileJson(
      tables: const <String>['client', 'client_artist'],
      values: <String, dynamic>{
        'name': value.name.trim(),
        'displayName': value.name.trim(),
        'email': value.email.trim().toLowerCase(),
        'phone': value.phone.trim(),
      },
    );
  }

  static Future<void> savePersonalProfile(ClientProfileDraft value) async {
    await saveBasicInfo(value.basic);
  }

  static Future<void> saveAddressInfo(AddressInfo value) async {
    final payload = _addressMap(value);

    await _updateProfileSection(
      tables: const <String>['client', 'client_artist'],
      section: 'address',
      values: payload,
    );

    await _updateProfileJson(
      tables: const <String>['client', 'client_artist'],
      values: <String, dynamic>{
        'addressLine1': value.street.trim(),
        'street': value.street.trim(),
        'city': value.city.trim(),
        'addressCity': value.city.trim(),
        'state': value.state.trim(),
        'zip': value.zip.trim(),
        'country': value.country.trim(),
        'shippingAddress': payload,
      },
    );
  }

  static Future<void> saveShippingAddress(AddressInfo value) async {
    final payload = _addressMap(value);

    await _updateProfileJson(
      tables: const <String>['client', 'client_artist'],
      values: <String, dynamic>{
        'shippingAddress': payload,
        'shipping_address': payload,
      },
    );

    await _updateProfileSection(
      tables: const <String>['client', 'client_artist'],
      section: 'address',
      values: <String, dynamic>{
        'shippingAddress': payload,
        'shipping_address': payload,
      },
    );
  }

  static Future<void> saveNailPreferences(NailPreferences value) async {
    final payload = _nailPreferencesMap(value);

    await _updateProfileSection(
      tables: const <String>['client', 'client_artist'],
      section: 'nail_preferences',
      values: payload,
    );

    await _updateProfileJson(
      tables: const <String>['client', 'client_artist'],
      values: <String, dynamic>{
        'nailPreferences': payload,
        'nail_preferences': payload,
      },
    );
  }

  static Future<void> savePaymentInfo(PaymentInfo value) async {
    final payload = <String, dynamic>{
      'method': _enumName(value.method),
      'saveForFuture': value.saveForFuture,
      'cardNumber': value.cardNumber.trim(),
      'nameOnCard': value.nameOnCard.trim(),
      'expiryMMYY': value.expiryMMYY.trim(),
      'cvv': value.cvv.trim(),
      'zip': value.zip.trim(),
      'venmoHandle': value.venmoHandle.trim(),
      'paypalEmail': value.paypalEmail.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await _updateProfileSection(
      tables: const <String>['client', 'client_artist'],
      section: 'payment',
      values: payload,
    );

    await _updateProfileJson(
      tables: const <String>['client', 'client_artist'],
      values: <String, dynamic>{
        'payment': payload,
        'paymentInfo': payload,
      },
    );
  }

  static Future<void> saveCompanyBusinessInfo({
    required String companyName,
    required String contactName,
    required String contactEmail,
    required String contactPhone,
    required String companyEmail,
    required String companyPhone,
    required String companyUrl,
    required String businessType,
  }) async {
    final companyNameValue = companyName.trim();
    final contactNameValue = contactName.trim();
    final contactEmailValue = contactEmail.trim().toLowerCase();
    final contactPhoneValue = contactPhone.trim();
    final companyEmailValue = companyEmail.trim().toLowerCase();
    final companyPhoneValue = companyPhone.trim();
    final companyUrlValue = companyUrl.trim();
    final businessTypeValue = businessType.trim();

    final row = <String, dynamic>{
      'companyName': companyNameValue,
      'company_name': companyNameValue,
      'displayName': companyNameValue,
      'contactName': contactNameValue,
      'contact_name': contactNameValue,
      'contactEmail': contactEmailValue,
      'contact_email': contactEmailValue,
      'contactPhone': contactPhoneValue,
      'contact_phone': contactPhoneValue,
      'companyEmail': companyEmailValue,
      'company_email': companyEmailValue,
      'companyPhone': companyPhoneValue,
      'company_phone': companyPhoneValue,
      'companyUrl': companyUrlValue,
      'company_website': companyUrlValue,
      'companyWebsite': companyUrlValue,
      'businessType': businessTypeValue,
      'business_type': businessTypeValue,
      'panel_companyName': companyNameValue,
      'panel_company_name': companyNameValue,
      'panel_contactName': contactNameValue,
      'panel_contact_name': contactNameValue,
      'panel_contactEmail': contactEmailValue,
      'panel_contact_email': contactEmailValue,
      'panel_contactPhone': contactPhoneValue,
      'panel_contact_phone': contactPhoneValue,
      'panel_companyPhone': companyPhoneValue,
      'panel_company_phone': companyPhoneValue,
      'panel_companyWebsite': companyUrlValue,
      'panel_company_website': companyUrlValue,
      'panel_businessType': businessTypeValue,
      'panel_business_type': businessTypeValue,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await _client.from('company').upsert(<String, dynamic>{
      'id': _uid,
      'email': companyEmailValue,
      'account_type': 'company',
      'profile': row,
      'basic': <String, dynamic>{
        'companyName': companyNameValue,
        'company_name': companyNameValue,
        'displayName': companyNameValue,
        'contactName': contactNameValue,
        'contact_name': contactNameValue,
        'contactEmail': contactEmailValue,
        'contact_email': contactEmailValue,
        'contactPhone': contactPhoneValue,
        'contact_phone': contactPhoneValue,
        'companyEmail': companyEmailValue,
        'company_email': companyEmailValue,
        'companyPhone': companyPhoneValue,
        'company_phone': companyPhoneValue,
        'companyUrl': companyUrlValue,
        'company_website': companyUrlValue,
        'businessType': businessTypeValue,
        'business_type': businessTypeValue,
      },
      'company': <String, dynamic>{
        'name': companyNameValue,
        'contactName': contactNameValue,
        'contactEmail': contactEmailValue,
        'contactPhone': contactPhoneValue,
        'phone': companyPhoneValue,
        'companyPhone': companyPhoneValue,
        'website': companyUrlValue,
        'companyUrl': companyUrlValue,
        'businessType': businessTypeValue,
        'company_name': companyNameValue,
        'contact_name': contactNameValue,
        'contact_email': contactEmailValue,
        'contact_phone': contactPhoneValue,
        'company_phone': companyPhoneValue,
        'company_website': companyUrlValue,
        'business_type': businessTypeValue,
      },
      'addresses': <String, dynamic>{},
      'billing': <String, dynamic>{},
      ...row,
    });
  }

  static Future<String> uploadProfilePhoto(Uint8List bytes) async {
    final uid = _uid;
    if (uid.isEmpty) {
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    }

    final candidates = <({String bucket, String path})>[
      (
        bucket: 'profile-pictures',
        path: 'clients/$uid/profile/avatar.jpg',
      ),
      (
        bucket: 'profile-pictures',
        path: 'client_artists/$uid/profile/avatar.jpg',
      ),
    ];

    for (final target in candidates) {
      try {
        await _client.storage.from(target.bucket).uploadBinary(
              target.path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        final url =
            _client.storage.from(target.bucket).getPublicUrl(target.path).trim();
        if (url.isNotEmpty) return url;
      } catch (_) {
        // Try next candidate path.
      }
    }

    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  }

  static Future<void> saveProfilePhotoUrl(String url) async {
    final value = url.trim();
    if (value.isEmpty) return;

    final values = <String, dynamic>{
      'profileImageUrl': value,
      'profilePhotoUrl': value,
      'photoUrl': value,
      'avatarUrl': value,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    await _updateProfileJson(
      tables: const <String>['client', 'client_artist'],
      values: values,
    );

    await _updateProfileSection(
      tables: const <String>['client', 'client_artist'],
      section: 'basic',
      values: values,
    );
  }

  static Map<String, dynamic> _addressMap(AddressInfo value) {
    return <String, dynamic>{
      'street': value.street.trim(),
      'addressLine1': value.street.trim(),
      'city': value.city.trim(),
      'addressCity': value.city.trim(),
      'state': value.state.trim(),
      'zip': value.zip.trim(),
      'country': value.country.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _nailPreferencesMap(NailPreferences value) {
    return <String, dynamic>{
      'shape': value.shape.trim(),
      'length': _enumName(value.length),
      'dimensions': <String, dynamic>{
        'lThumb': value.dimensions.lThumb,
        'lIndex': value.dimensions.lIndex,
        'lMiddle': value.dimensions.lMiddle,
        'lRing': value.dimensions.lRing,
        'lPinky': value.dimensions.lPinky,
        'rThumb': value.dimensions.rThumb,
        'rIndex': value.dimensions.rIndex,
        'rMiddle': value.dimensions.rMiddle,
        'rRing': value.dimensions.rRing,
        'rPinky': value.dimensions.rPinky,
      },
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  static String _enumName(Object value) {
    final text = value.toString();
    final dot = text.lastIndexOf('.');
    return dot >= 0 ? text.substring(dot + 1) : text;
  }

  static Future<void> _updateProfileJson({
    required List<String> tables,
    required Map<String, dynamic> values,
  }) async {
    await _updateJsonColumn(
      tables: tables,
      column: 'profile',
      values: values,
    );
  }

  static Future<void> _updateProfileSection({
    required List<String> tables,
    required String section,
    required Map<String, dynamic> values,
  }) async {
    await _updateJsonColumn(
      tables: tables,
      column: section,
      values: values,
    );
  }

  static Future<void> _updateJsonColumn({
    required List<String> tables,
    required String column,
    required Map<String, dynamic> values,
  }) async {
    if (_uid.isEmpty && _email.isEmpty) return;

    final now = DateTime.now().toIso8601String();

    for (final table in tables) {
      await _updateOneTableJsonColumn(
        table: table,
        column: column,
        values: values,
        now: now,
      );
    }
  }

  static Future<void> _updateOneTableJsonColumn({
    required String table,
    required String column,
    required Map<String, dynamic> values,
    required String now,
  }) async {
    Map<String, dynamic>? existing;
    try {
      existing = await _selectExisting(table);
    } catch (_) {
      return;
    }

    if (existing == null) return;

    final existingJson = existing[column] is Map
        ? Map<String, dynamic>.from(existing[column] as Map)
        : <String, dynamic>{};

    final payload = <String, dynamic>{
      column: <String, dynamic>{
        ...existingJson,
        ...values,
      },
      'updated_at': now,
    };

    try {
      if (_uid.isNotEmpty) {
        await _client.from(table).update(payload).eq('id', _uid);
      } else if (_email.isNotEmpty) {
        await _client.from(table).update(payload).eq('email', _email);
      }
    } catch (_) {
      // Some tables may not have this JSON column or updated_at. Retry without updated_at.
      final fallbackPayload = <String, dynamic>{
        column: <String, dynamic>{
          ...existingJson,
          ...values,
        },
      };
      try {
        if (_uid.isNotEmpty) {
          await _client.from(table).update(fallbackPayload).eq('id', _uid);
        } else if (_email.isNotEmpty) {
          await _client.from(table).update(fallbackPayload).eq('email', _email);
        }
      } catch (_) {}
    }
  }

  static Future<Map<String, dynamic>?> _selectExisting(String table) async {
    if (_uid.isNotEmpty) {
      final byId = await _client.from(table).select().eq('id', _uid).maybeSingle();
      if (byId != null) return Map<String, dynamic>.from(byId);
    }

    if (_email.isNotEmpty) {
      final byEmail =
          await _client.from(table).select().eq('email', _email).maybeSingle();
      if (byEmail != null) return Map<String, dynamic>.from(byEmail);
    }

    return null;
  }
}
