import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddressValidationResult {
  const AddressValidationResult({required this.isValid, this.message});

  final bool isValid;
  final String? message;
}

class AddressSuggestion {
  const AddressSuggestion({
    required this.street,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
    required this.displayLabel,
  });

  final String street;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String displayLabel;
}

class AddressValidationService {
  static String? matchUsStateName(String value) {
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    if (_stateNameToAbbr.containsKey(normalized)) return _titleCase(normalized);
    final fromAbbr = _abbrToStateName[normalized];
    if (fromAbbr != null) return _titleCase(fromAbbr);
    if (normalized.startsWith('US-') && normalized.length == 5) {
      final maybeAbbr = normalized.substring(3);
      final fromIso = _abbrToStateName[maybeAbbr];
      if (fromIso != null) return _titleCase(fromIso);
    }
    return null;
  }

  static Future<List<AddressSuggestion>> searchUsStreetSuggestions(
    String query,
  ) async {
    if (kIsWeb) return const <AddressSuggestion>[];
    final trimmed = query.trim();
    if (trimmed.length < 3) return const <AddressSuggestion>[];

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final q = Uri.encodeQueryComponent('$trimmed, USA');
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=jsonv2'
        '&addressdetails=1'
        '&countrycodes=us'
        '&limit=8'
        '&q=$q',
      );
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'jnt-app-address-autofill/1.0',
      );
      final response = await request.close();
      if (response.statusCode != 200) return const <AddressSuggestion>[];

      final raw = await utf8.decoder.bind(response).join();
      final rows = jsonDecode(raw) as List<dynamic>;
      final suggestions = <AddressSuggestion>[];
      final seen = <String>{};

      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final address = (map['address'] as Map<String, dynamic>? ?? const {});

        final house = (address['house_number'] ?? '').toString().trim();
        final road = (address['road'] ?? '').toString().trim();
        final city =
            (address['city'] ??
                    address['town'] ??
                    address['village'] ??
                    address['municipality'] ??
                    address['hamlet'] ??
                    address['suburb'] ??
                    address['county'] ??
                    '')
                .toString()
                .trim();
        final stateRaw =
            (address['state'] ??
                    address['state_code'] ??
                    address['ISO3166-2-lvl4'] ??
                    '')
                .toString()
                .trim();
        final zip = (address['postcode'] ?? '').toString().trim();
        final country = (address['country'] ?? 'United States')
            .toString()
            .trim();
        final state = matchUsStateName(stateRaw) ?? stateRaw;

        final street = [house, road].where((v) => v.isNotEmpty).join(' ');
        final fallbackDisplay = (map['display_name'] ?? '').toString();
        final label = street.isNotEmpty
            ? '$street, $city, $state $zip'
            : fallbackDisplay;

        if (state.isEmpty) continue;
        final key =
            '${street.toLowerCase()}|${city.toLowerCase()}|${state.toLowerCase()}|$zip';
        if (seen.contains(key)) continue;
        seen.add(key);

        suggestions.add(
          AddressSuggestion(
            street: street.isEmpty ? trimmed : street,
            city: city,
            state: state,
            zip: zip,
            country: country.isEmpty ? 'United States' : country,
            displayLabel: label,
          ),
        );
      }

      return suggestions;
    } catch (_) {
      return const <AddressSuggestion>[];
    } finally {
      client.close(force: true);
    }
  }

  static Future<AddressValidationResult> validateUsAddress({
    required String street,
    required String city,
    required String state,
    required String zip,
  }) async {
    if (kIsWeb) {
      return const AddressValidationResult(isValid: true);
    }
    final streetValue = street.trim();
    final cityValue = city.trim();
    final stateValue = state.trim();
    final zipDigits = zip.replaceAll(RegExp(r'\D'), '');

    if (streetValue.isEmpty) {
      return const AddressValidationResult(
        isValid: false,
        message: 'Street address is required.',
      );
    }
    if (cityValue.isEmpty) {
      return const AddressValidationResult(
        isValid: false,
        message: 'City is required.',
      );
    }
    if (stateValue.isEmpty) {
      return const AddressValidationResult(
        isValid: false,
        message: 'State is required.',
      );
    }
    if (zipDigits.length < 5) {
      return const AddressValidationResult(
        isValid: false,
        message: 'ZIP code is invalid.',
      );
    }

    final zip5 = zipDigits.substring(0, 5);
    final expectedStateAbbr = _toStateAbbreviation(stateValue);
    final expectedCity = _normalizeCity(cityValue);

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(
        Uri.parse('https://api.zippopotam.us/us/$zip5'),
      );
      final response = await request.close();
      if (response.statusCode == 404) {
        return const AddressValidationResult(
          isValid: false,
          message: 'ZIP code was not found.',
        );
      }
      if (response.statusCode != 200) {
        return const AddressValidationResult(
          isValid: false,
          message: 'Unable to validate address right now. Try again.',
        );
      }

      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final places = (decoded['places'] as List<dynamic>? ?? const []);
      if (places.isEmpty) {
        return const AddressValidationResult(
          isValid: false,
          message: 'ZIP code was not found.',
        );
      }

      final cityMatches = <String>{};
      final stateMatches = <String>{};
      for (final place in places) {
        final row = place as Map<String, dynamic>;
        final placeName = (row['place name'] ?? '').toString();
        final stateAbbr = (row['state abbreviation'] ?? '').toString();
        if (_normalizeCity(placeName) == expectedCity) {
          cityMatches.add(placeName);
          stateMatches.add(stateAbbr);
        }
      }

      if (cityMatches.isEmpty) {
        return AddressValidationResult(
          isValid: false,
          message: 'City does not match ZIP code $zip5.',
        );
      }
      if (!stateMatches.contains(expectedStateAbbr)) {
        return AddressValidationResult(
          isValid: false,
          message: 'State does not match ZIP code $zip5.',
        );
      }

      return const AddressValidationResult(isValid: true);
    } on SocketException {
      return const AddressValidationResult(
        isValid: false,
        message: 'Network error validating address. Check connection.',
      );
    } on HttpException {
      return const AddressValidationResult(
        isValid: false,
        message: 'Unable to validate address right now. Try again.',
      );
    } on FormatException {
      return const AddressValidationResult(
        isValid: false,
        message: 'Unexpected response during address validation.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<AddressValidationResult> validateUsCityState({
    required String city,
    required String state,
  }) async {
    if (kIsWeb) {
      return const AddressValidationResult(isValid: true);
    }
    final cityValue = city.trim();
    final stateValue = state.trim();
    if (cityValue.isEmpty) {
      return const AddressValidationResult(
        isValid: false,
        message: 'City is required.',
      );
    }
    if (stateValue.isEmpty) {
      return const AddressValidationResult(
        isValid: false,
        message: 'State is required.',
      );
    }

    final expectedState = _toStateAbbreviation(stateValue);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final encodedQuery = Uri.encodeQueryComponent(
        '$cityValue, $stateValue, USA',
      );
      final request = await client.getUrl(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=$encodedQuery',
        ),
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'jnt-app-address-validation/1.0',
      );
      final response = await request.close();
      if (response.statusCode != 200) {
        return const AddressValidationResult(
          isValid: false,
          message: 'Unable to validate city/state right now. Try again.',
        );
      }

      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (decoded.isEmpty) {
        return const AddressValidationResult(
          isValid: false,
          message: 'City/state combination was not found.',
        );
      }

      final expectedCityNormalized = _normalizeCity(cityValue);
      for (final row in decoded) {
        final map = row as Map<String, dynamic>;
        final address = (map['address'] as Map<String, dynamic>? ?? const {});
        final countryCode = (address['country_code'] ?? '')
            .toString()
            .toUpperCase();
        if (countryCode != 'US') continue;

        final resultState = (address['state'] ?? '').toString();
        final resultStateAbbr = _toStateAbbreviation(resultState);
        if (resultStateAbbr != expectedState) continue;

        final resultCity =
            (address['city'] ??
                    address['town'] ??
                    address['village'] ??
                    address['municipality'] ??
                    '')
                .toString();
        if (_normalizeCity(resultCity) == expectedCityNormalized) {
          return const AddressValidationResult(isValid: true);
        }
      }

      return const AddressValidationResult(
        isValid: false,
        message: 'City does not match selected U.S. state.',
      );
    } on SocketException {
      return const AddressValidationResult(
        isValid: false,
        message: 'Network error validating city/state. Check connection.',
      );
    } on HttpException {
      return const AddressValidationResult(
        isValid: false,
        message: 'Unable to validate city/state right now. Try again.',
      );
    } on FormatException {
      return const AddressValidationResult(
        isValid: false,
        message: 'Unexpected response during city/state validation.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _normalizeCity(String city) =>
      city.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String _toStateAbbreviation(String value) {
    final normalized = value.trim().toUpperCase();
    if (_stateNameToAbbr.containsValue(normalized)) return normalized;
    return _stateNameToAbbr[normalized] ?? normalized;
  }

  static String _titleCase(String value) {
    return value
        .toLowerCase()
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .join(' ');
  }

  static const Map<String, String> _stateNameToAbbr = {
    'ALABAMA': 'AL',
    'ALASKA': 'AK',
    'ARIZONA': 'AZ',
    'ARKANSAS': 'AR',
    'CALIFORNIA': 'CA',
    'COLORADO': 'CO',
    'CONNECTICUT': 'CT',
    'DELAWARE': 'DE',
    'FLORIDA': 'FL',
    'GEORGIA': 'GA',
    'HAWAII': 'HI',
    'IDAHO': 'ID',
    'ILLINOIS': 'IL',
    'INDIANA': 'IN',
    'IOWA': 'IA',
    'KANSAS': 'KS',
    'KENTUCKY': 'KY',
    'LOUISIANA': 'LA',
    'MAINE': 'ME',
    'MARYLAND': 'MD',
    'MASSACHUSETTS': 'MA',
    'MICHIGAN': 'MI',
    'MINNESOTA': 'MN',
    'MISSISSIPPI': 'MS',
    'MISSOURI': 'MO',
    'MONTANA': 'MT',
    'NEBRASKA': 'NE',
    'NEVADA': 'NV',
    'NEW HAMPSHIRE': 'NH',
    'NEW JERSEY': 'NJ',
    'NEW MEXICO': 'NM',
    'NEW YORK': 'NY',
    'NORTH CAROLINA': 'NC',
    'NORTH DAKOTA': 'ND',
    'OHIO': 'OH',
    'OKLAHOMA': 'OK',
    'OREGON': 'OR',
    'PENNSYLVANIA': 'PA',
    'RHODE ISLAND': 'RI',
    'SOUTH CAROLINA': 'SC',
    'SOUTH DAKOTA': 'SD',
    'TENNESSEE': 'TN',
    'TEXAS': 'TX',
    'UTAH': 'UT',
    'VERMONT': 'VT',
    'VIRGINIA': 'VA',
    'WASHINGTON': 'WA',
    'WEST VIRGINIA': 'WV',
    'WISCONSIN': 'WI',
    'WYOMING': 'WY',
    'DISTRICT OF COLUMBIA': 'DC',
  };

  static final Map<String, String> _abbrToStateName = {
    for (final entry in _stateNameToAbbr.entries) entry.value: entry.key,
  };
}
