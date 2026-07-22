import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../models/client_profile_models.dart';
import '../services/address_validation_service.dart';
import '../services/edit_profile_supabase_save.dart';
import '../theme/app_colors.dart';
import '../widgets/autocomplete_dropdown_sizing.dart';

class EditShippingAddressPopup extends StatefulWidget {
  const EditShippingAddressPopup({super.key, required this.initial});

  final AddressInfo initial;

  @override
  State<EditShippingAddressPopup> createState() =>
      _EditShippingAddressPopupState();
}

class _EditShippingAddressPopupState extends State<EditShippingAddressPopup> {
  late final TextEditingController _street;
  late final TextEditingController _city;
  String? _stateValue;
  late final TextEditingController _zip;
  String? _countryValue;
  Timer? _streetAutocompleteDebounce;
  List<AddressSuggestion> _streetSuggestions = const [];
  bool _streetSuggestionsLoading = false;

  final FocusNode _streetFocusNode = FocusNode(debugLabel: 'streetField');
  final FocusNode _cityFocusNode = FocusNode(debugLabel: 'cityField');
  final FocusNode _zipFocusNode = FocusNode(debugLabel: 'zipField');
  final FocusNode _stateButtonFocusNode = FocusNode(
    debugLabel: 'statePickerButton',
  );
  final FocusNode _countryButtonFocusNode = FocusNode(
    debugLabel: 'countryPickerButton',
  );

  static const double _fieldGap = 2;
  static const double _fieldVerticalPadding = 10;
  static const double _fieldHeight = 56;

  @override
  void initState() {
    super.initState();
    _street = TextEditingController(text: widget.initial.street);
    _city = TextEditingController(text: widget.initial.city);
    _zip = TextEditingController(text: widget.initial.zip);
    _stateValue = _initStateValue(widget.initial.state);
    _countryValue = _initCountryValue(widget.initial.country);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      _streetFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _streetAutocompleteDebounce?.cancel();
    _street.dispose();
    _city.dispose();
    _zip.dispose();
    _streetFocusNode.dispose();
    _cityFocusNode.dispose();
    _zipFocusNode.dispose();
    _stateButtonFocusNode.dispose();
    _countryButtonFocusNode.dispose();
    super.dispose();
  }

  Future<void> _autofillAddressFromStreet() async {
    _streetAutocompleteDebounce?.cancel();
    final query = _street.text.trim();
    if (query.length < 3) {
      if (!mounted) return;
      setState(() {
        _streetSuggestionsLoading = false;
        _streetSuggestions = const [];
      });
      return;
    }

    setState(() => _streetSuggestionsLoading = true);
    _streetAutocompleteDebounce = Timer(
      const Duration(milliseconds: 350),
      () async {
        final results =
            await AddressValidationService.searchUsStreetSuggestions(query);
        if (!mounted) return;
        setState(() {
          _streetSuggestionsLoading = false;
          _streetSuggestions = results;
        });
      },
    );
  }

  void _applyStreetSuggestion(AddressSuggestion selected) {
    setState(() {
      _street.text = selected.street;
      _city.text = selected.city;
      _zip.text = selected.zip;
      _countryValue = 'United States';
      _stateValue =
          AddressValidationService.matchUsStateName(selected.state) ??
          selected.state;
      _streetSuggestions = const [];
    });
  }

  /// Google Places predictions (see [AddressSuggestion.placeId]) carry only
  /// display text, not structured fields — resolve the full address before
  /// applying it. Nominatim-backed suggestions (placeId null) apply
  /// unchanged, synchronously.
  Future<void> _selectStreetSuggestion(AddressSuggestion selected) async {
    if (selected.placeId != null) {
      final resolved = await AddressValidationService.resolvePlaceDetails(
        selected.placeId!,
      );
      if (resolved != null) {
        _applyStreetSuggestion(resolved);
        return;
      }
    }
    _applyStreetSuggestion(selected);
  }

  Future<void> _save() async {
    final updated = AddressInfo(
      street: _street.text.trim(),
      city: _city.text.trim(),
      state: (_stateValue ?? '').trim(),
      zip: _zip.text.trim(),
      country: (_countryValue ?? '').trim(),
    );

    try {
      await EditProfileSupabaseSave.saveShippingAddress(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save shipping address: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Shipping Address',
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Container(
            padding: EdgeInsets.only(bottom: bottom),
            decoration: const BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      height: 4,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.blackCat,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const SizedBox(width: 48),
                      const Spacer(),
                      Semantics(
                        header: true,
                        child: Text(
                          'Shipping Address',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppColors.blackCat,
                            fontFamily: 'ArialBold',
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close shipping address',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 22,
                          color: AppColors.blackCat.withValues(alpha: 0.75),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field('Street', _street, focusNode: _streetFocusNode),
                      if (_streetSuggestionsLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (_streetSuggestions.isNotEmpty)
                        Builder(
                          builder: (context) {
                            final suggestionCount = _streetSuggestions.length;
                            final menuHeight =
                                AutocompleteDropdownSizing.menuHeight(
                                  itemCount: suggestionCount,
                                  itemExtent: 40,
                                );
                            return Container(
                              margin: const EdgeInsets.only(top: 8),
                              decoration: BoxDecoration(
                                color: AppColors.snow,
                                borderRadius: BorderRadius.zero,
                                border: Border.all(
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.20,
                                  ),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxHeight: menuHeight,
                              ),
                              child: ListView.separated(
                                shrinkWrap:
                                    AutocompleteDropdownSizing.shrinkWrap(
                                      suggestionCount,
                                    ),
                                physics:
                                    AutocompleteDropdownSizing.scrollPhysics(
                                      suggestionCount,
                                    ),
                                itemCount: suggestionCount,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) => ListTile(
                                  dense: true,
                                  title: Text(
                                    _streetSuggestions[i].displayLabel,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => _selectStreetSuggestion(
                                    _streetSuggestions[i],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: _fieldGap),
                      _field('City', _city, focusNode: _cityFocusNode),
                      const SizedBox(height: _fieldGap),
                      _dropdownField(
                        label: 'State',
                        value: _stateValue,
                        onPressed: _openStatePicker,
                        buttonFocusNode: _stateButtonFocusNode,
                        hint: 'Select state',
                      ),
                      const SizedBox(height: _fieldGap),
                      _field(
                        'Zip',
                        _zip,
                        keyboardType: TextInputType.number,
                        focusNode: _zipFocusNode,
                      ),
                      const SizedBox(height: _fieldGap),
                      _dropdownField(
                        label: 'Country',
                        value: _countryValue,
                        onPressed: _openCountryPicker,
                        buttonFocusNode: _countryButtonFocusNode,
                        hint: 'Select country',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.snow,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboardType,
    FocusNode? focusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.blackCat,
              fontFamily: 'ArialBold',
            ),
          ),
        ),
        const SizedBox(height: _fieldGap),
        Semantics(
          textField: true,
          label: label,
          child: TextField(
            controller: c,
            focusNode: focusNode,
            onChanged: label == 'Street'
                ? (_) => _autofillAddressFromStreet()
                : null,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Arial',
            ),
            keyboardType: keyboardType,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.snow,
              isDense: true,
              constraints: const BoxConstraints(minHeight: _fieldHeight),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: _fieldVerticalPadding,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: BorderSide(
                  color: AppColors.blackCat.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openStatePicker() => _openSelectionSheet(
    title: 'Select State',
    items: usStates,
    currentValue: _stateValue,
    searchHint: 'Search state',
    closeTooltip: 'Close state selection',
    announceLabel: 'State selected',
    buttonFocusNode: _stateButtonFocusNode,
    onSelected: (value) {
      setState(() => _stateValue = value);
    },
  );

  Future<void> _openCountryPicker() => _openSelectionSheet(
    title: 'Select Country',
    items: countries,
    currentValue: _countryValue,
    searchHint: 'Search country',
    closeTooltip: 'Close country selection',
    announceLabel: 'Country selected',
    buttonFocusNode: _countryButtonFocusNode,
    onSelected: (value) {
      setState(() => _countryValue = value);
    },
  );

  Future<void> _openSelectionSheet({
    required String title,
    required List<String> items,
    required String? currentValue,
    required String searchHint,
    required String closeTooltip,
    required String announceLabel,
    required FocusNode buttonFocusNode,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: AppColors.snow,
      builder: (_) => _SelectionSheet(
        title: title,
        items: items,
        currentValue: currentValue,
        searchHint: searchHint,
        closeTooltip: closeTooltip,
      ),
    );

    if (!mounted) return;

    if (selected != null) {
      onSelected(selected);
      SemanticsService.sendAnnouncement(
        View.of(context),
        '$announceLabel $selected',
        Directionality.of(context),
      );
    }

    FocusScope.of(context).requestFocus(buttonFocusNode);
  }

  Widget _dropdownField({
    required String label,
    required String hint,
    required VoidCallback onPressed,
    required FocusNode buttonFocusNode,
    String? value,
  }) {
    final cleanValue = (value ?? '').trim();
    final semanticValue = cleanValue.isEmpty ? 'not selected' : cleanValue;
    final visualValue = cleanValue.isEmpty ? hint : cleanValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.blackCat,
              fontFamily: 'ArialBold',
            ),
          ),
        ),
        const SizedBox(height: _fieldGap),
        Semantics(
          button: true,
          label: '$label, $semanticValue',
          onTap: onPressed,
          child: ExcludeSemantics(
            child: SizedBox(
              height: _fieldHeight,
              child: TextButton(
                focusNode: buttonFocusNode,
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  backgroundColor: AppColors.snow,
                  foregroundColor: AppColors.blackCat,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: _fieldVerticalPadding,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide(
                      color: AppColors.blackCat.withValues(alpha: 0.35),
                    ),
                  ),
                  minimumSize: const Size.fromHeight(_fieldHeight),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        visualValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.blackCat.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _initStateValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return usStates.contains(trimmed) ? trimmed : null;
  }

  String? _initCountryValue(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return countries.contains('United States') ? 'United States' : null;
    }
    return countries.contains(trimmed) ? trimmed : null;
  }
}

class _SelectionSheet extends StatefulWidget {
  const _SelectionSheet({
    required this.title,
    required this.items,
    required this.currentValue,
    required this.searchHint,
    required this.closeTooltip,
  });

  final String title;
  final List<String> items;
  final String? currentValue;
  final String searchHint;
  final String closeTooltip;

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredItems {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentValue = (widget.currentValue ?? '').trim();
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: widget.title,
      explicitChildNodes: true,
      child: Material(
        color: AppColors.snow,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.blackCat,
                                fontFamily: 'ArialBold',
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: widget.closeTooltip,
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.blackCat.withValues(alpha: 0.75),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Search',
                        hintText: widget.searchHint,
                        filled: true,
                        fillColor: AppColors.snow,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.35),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.35),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(
                            color: AppColors.blackCat.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _filteredItems.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: AppColors.blackCat.withValues(alpha: 0.08),
                        ),
                        itemBuilder: (context, index) {
                          final item = _filteredItems[index];
                          final isSelected = item == currentValue;
                          return Semantics(
                            button: true,
                            selected: isSelected,
                            label: isSelected ? '$item, selected' : item,
                            onTap: () => Navigator.pop(context, item),
                            child: ExcludeSemantics(
                              child: ListTile(
                                title: Text(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Arial',
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_rounded)
                                    : null,
                                onTap: () => Navigator.pop(context, item),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const List<String> usStates = [
  'Alabama',
  'Alaska',
  'Arizona',
  'Arkansas',
  'California',
  'Colorado',
  'Connecticut',
  'Delaware',
  'Florida',
  'Georgia',
  'Hawaii',
  'Idaho',
  'Illinois',
  'Indiana',
  'Iowa',
  'Kansas',
  'Kentucky',
  'Louisiana',
  'Maine',
  'Maryland',
  'Massachusetts',
  'Michigan',
  'Minnesota',
  'Mississippi',
  'Missouri',
  'Montana',
  'Nebraska',
  'Nevada',
  'New Hampshire',
  'New Jersey',
  'New Mexico',
  'New York',
  'North Carolina',
  'North Dakota',
  'Ohio',
  'Oklahoma',
  'Oregon',
  'Pennsylvania',
  'Rhode Island',
  'South Carolina',
  'South Dakota',
  'Tennessee',
  'Texas',
  'Utah',
  'Vermont',
  'Virginia',
  'Washington',
  'West Virginia',
  'Wisconsin',
  'Wyoming',
];

const List<String> countries = [
  'Afghanistan',
  'Albania',
  'Algeria',
  'Andorra',
  'Angola',
  'Antigua and Barbuda',
  'Argentina',
  'Armenia',
  'Australia',
  'Austria',
  'Azerbaijan',
  'Bahamas',
  'Bahrain',
  'Bangladesh',
  'Barbados',
  'Belarus',
  'Belgium',
  'Belize',
  'Benin',
  'Bhutan',
  'Bolivia',
  'Bosnia and Herzegovina',
  'Botswana',
  'Brazil',
  'Brunei',
  'Bulgaria',
  'Burkina Faso',
  'Burundi',
  'Cabo Verde',
  'Cambodia',
  'Cameroon',
  'Canada',
  'Central African Republic',
  'Chad',
  'Chile',
  'China',
  'Colombia',
  'Comoros',
  'Congo (Congo-Brazzaville)',
  'Costa Rica',
  'Croatia',
  'Cuba',
  'Cyprus',
  'Czechia (Czech Republic)',
  "Cote d'Ivoire",
  'Democratic Republic of the Congo',
  'Denmark',
  'Djibouti',
  'Dominica',
  'Dominican Republic',
  'Ecuador',
  'Egypt',
  'El Salvador',
  'Equatorial Guinea',
  'Eritrea',
  'Estonia',
  'Eswatini (fmr. "Swaziland")',
  'Ethiopia',
  'Fiji',
  'Finland',
  'France',
  'Gabon',
  'Gambia',
  'Georgia',
  'Germany',
  'Ghana',
  'Greece',
  'Grenada',
  'Guatemala',
  'Guinea',
  'Guinea-Bissau',
  'Guyana',
  'Haiti',
  'Holy See',
  'Honduras',
  'Hungary',
  'Iceland',
  'India',
  'Indonesia',
  'Iran',
  'Iraq',
  'Ireland',
  'Israel',
  'Italy',
  'Jamaica',
  'Japan',
  'Jordan',
  'Kazakhstan',
  'Kenya',
  'Kiribati',
  'Kuwait',
  'Kyrgyzstan',
  'Laos',
  'Latvia',
  'Lebanon',
  'Lesotho',
  'Liberia',
  'Libya',
  'Liechtenstein',
  'Lithuania',
  'Luxembourg',
  'Madagascar',
  'Malawi',
  'Malaysia',
  'Maldives',
  'Mali',
  'Malta',
  'Marshall Islands',
  'Mauritania',
  'Mauritius',
  'Mexico',
  'Micronesia',
  'Moldova',
  'Monaco',
  'Mongolia',
  'Montenegro',
  'Morocco',
  'Mozambique',
  'Myanmar (formerly Burma)',
  'Namibia',
  'Nauru',
  'Nepal',
  'Netherlands',
  'New Zealand',
  'Nicaragua',
  'Niger',
  'Nigeria',
  'North Korea',
  'North Macedonia',
  'Norway',
  'Oman',
  'Pakistan',
  'Palau',
  'Palestine State',
  'Panama',
  'Papua New Guinea',
  'Paraguay',
  'Peru',
  'Philippines',
  'Poland',
  'Portugal',
  'Qatar',
  'Romania',
  'Russia',
  'Rwanda',
  'Saint Kitts and Nevis',
  'Saint Lucia',
  'Saint Vincent and the Grenadines',
  'Samoa',
  'San Marino',
  'Sao Tome and Principe',
  'Saudi Arabia',
  'Senegal',
  'Serbia',
  'Seychelles',
  'Sierra Leone',
  'Singapore',
  'Slovakia',
  'Slovenia',
  'Solomon Islands',
  'Somalia',
  'South Africa',
  'South Korea',
  'South Sudan',
  'Spain',
  'Sri Lanka',
  'Sudan',
  'Suriname',
  'Sweden',
  'Switzerland',
  'Syria',
  'Tajikistan',
  'Tanzania',
  'Thailand',
  'Timor-Leste',
  'Togo',
  'Tonga',
  'Trinidad and Tobago',
  'Tunisia',
  'Turkey',
  'Turkmenistan',
  'Tuvalu',
  'Uganda',
  'Ukraine',
  'United Arab Emirates',
  'United Kingdom',
  'United States',
  'Uruguay',
  'Uzbekistan',
  'Vanuatu',
  'Venezuela',
  'Vietnam',
  'Yemen',
  'Zambia',
  'Zimbabwe',
];
