import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves a brand-sourced request's company bio, checking any snapshot
/// embedded on the request row/details first, then falling back to a live
/// lookup of the `company` table by uid, email, or name.
Future<String> fetchCompanyBio({
  required String sourceCollection,
  required String requestId,
  String requestOrderNumber = '',
}) async {
  if (sourceCollection != 'Company_Custom_Requests') return '';

  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return const <String, dynamic>{};
  }

  String firstNonEmpty(List<Object?> values) {
    for (final raw in values) {
      final text = (raw ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  final supabase = Supabase.instance.client;
  Map<String, dynamic> rootData = const <String, dynamic>{};
  Map<String, dynamic> detailsData = const <String, dynamic>{};

  try {
    final id = requestId.trim();
    Map<String, dynamic>? rootRow;
    if (id.isNotEmpty) {
      final row = await supabase
          .from('company_custom_requests')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) rootRow = Map<String, dynamic>.from(row);
    }
    if (rootRow == null && requestOrderNumber.trim().isNotEmpty) {
      final row = await supabase
          .from('company_custom_requests')
          .select()
          .or(
            'order_number.eq.${requestOrderNumber.trim()},request_number.eq.${requestOrderNumber.trim()}',
          )
          .maybeSingle();
      if (row != null) rootRow = Map<String, dynamic>.from(row);
    }
    rootData = rootRow ?? const <String, dynamic>{};

    if (id.isNotEmpty) {
      final detailRows = await supabase
          .from('company_custom_requests_details')
          .select()
          .eq('request_id', id);
      final merged = <String, dynamic>{};
      for (final raw in detailRows.whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        for (final key in const <String>['payload', 'data', 'details']) {
          final value = row[key];
          if (value is Map) {
            merged.addAll(value.map((k, v) => MapEntry(k.toString(), v)));
          }
        }
        merged.addAll(row);
      }
      detailsData = merged;
    }
  } catch (_) {}

  final payload = asMap(rootData['payload']);
  final rootDetails = asMap(rootData['details']);
  final detailsPayload = asMap(detailsData['payload']);

  bool isRealCompanyBio(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return false;
    final lower = candidate.toLowerCase();
    return lower != 'null' &&
        lower != '-' &&
        lower != 'no company bio available';
  }

  String bioFromSnapshot(Map<String, dynamic> source) {
    final snapshot = asMap(
      source['companyProfileSnapshot'] ?? source['company_profile_snapshot'],
    );
    final company = asMap(snapshot['company']);
    for (final raw in <Object?>[
      company['bio'],
      company['companyBio'],
      snapshot['bio'],
      snapshot['companyBio'],
      snapshot['panel_companyBio'],
    ]) {
      final text = (raw ?? '').toString().trim();
      if (isRealCompanyBio(text)) return text;
    }
    return '';
  }

  for (final source in <Map<String, dynamic>>[
    rootData,
    rootDetails,
    payload,
    detailsData,
    detailsPayload,
  ]) {
    final bio = bioFromSnapshot(source);
    if (bio.isNotEmpty) return bio;
  }

  String bioFromCompanyRow(Map<String, dynamic> row) {
    final company = asMap(row['company']);
    final profile = asMap(row['profile']);
    for (final raw in <Object?>[
      company['bio'],
      company['companyBio'],
      row['company_bio'],
      row['companyBio'],
      row['bio'],
      row['panel_company_bio'],
      profile['companyBio'],
      profile['bio'],
    ]) {
      final text = (raw ?? '').toString().trim();
      if (isRealCompanyBio(text)) return text;
    }
    return '';
  }

  final companyUid = firstNonEmpty(<Object?>[
    rootData['company_uid'],
    rootData['companyUid'],
    rootDetails['companyUid'],
    payload['companyUid'],
    detailsData['company_uid'],
    detailsPayload['companyUid'],
  ]);
  final companyEmail = firstNonEmpty(<Object?>[
    rootData['company_email'],
    rootData['companyEmail'],
    rootDetails['companyEmail'],
    payload['companyEmail'],
    detailsData['company_email'],
    detailsPayload['companyEmail'],
  ]).toLowerCase();
  final companyName = firstNonEmpty(<Object?>[
    rootData['company_name'],
    rootData['companyName'],
    rootData['brand_name'],
    rootData['brandName'],
    rootDetails['companyName'],
    payload['companyName'],
    detailsData['companyName'],
    detailsPayload['companyName'],
  ]);

  try {
    if (companyUid.isNotEmpty) {
      final row = await supabase
          .from('company')
          .select()
          .eq('id', companyUid)
          .maybeSingle();
      if (row != null) {
        final bio = bioFromCompanyRow(Map<String, dynamic>.from(row));
        if (bio.isNotEmpty) return bio;
      }
    }
    if (companyEmail.isNotEmpty) {
      final row = await supabase
          .from('company')
          .select()
          .ilike('email', companyEmail)
          .maybeSingle();
      if (row != null) {
        final bio = bioFromCompanyRow(Map<String, dynamic>.from(row));
        if (bio.isNotEmpty) return bio;
      }
    }
    if (companyName.isNotEmpty) {
      for (final column in const <String>[
        'company_name',
        'brand_name',
        'panel_company_name',
      ]) {
        final row = await supabase
            .from('company')
            .select()
            .ilike(column, companyName)
            .maybeSingle();
        if (row != null) {
          final bio = bioFromCompanyRow(Map<String, dynamic>.from(row));
          if (bio.isNotEmpty) return bio;
        }
      }
    }
  } catch (_) {}

  return '';
}
