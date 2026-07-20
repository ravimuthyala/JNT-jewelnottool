import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CoinReference {
  const CoinReference({
    required this.countryCode,
    required this.countryName,
    required this.name,
    required this.diameterMm,
    required this.badgeLabel,
  });

  final String countryCode;
  final String countryName;
  final String name;
  final double diameterMm;
  final String badgeLabel;
}

const List<CoinReference> coinReferences = <CoinReference>[
  CoinReference(
    countryCode: 'US',
    countryName: 'United States',
    name: 'US Quarter (25\u00A2)',
    diameterMm: 24.26,
    badgeLabel: '25\u00A2',
  ),
  CoinReference(
    countryCode: 'US',
    countryName: 'United States',
    name: 'US Dime (10\u00A2)',
    diameterMm: 17.91,
    badgeLabel: '10\u00A2',
  ),
  CoinReference(
    countryCode: 'US',
    countryName: 'United States',
    name: 'US Nickel (5\u00A2)',
    diameterMm: 21.21,
    badgeLabel: '5\u00A2',
  ),
  CoinReference(
    countryCode: 'US',
    countryName: 'United States',
    name: 'US Penny (1\u00A2)',
    diameterMm: 19.05,
    badgeLabel: '1\u00A2',
  ),
  CoinReference(
    countryCode: 'CA',
    countryName: 'Canada',
    name: 'Canadian Quarter',
    diameterMm: 23.88,
    badgeLabel: '25\u00A2',
  ),
  CoinReference(
    countryCode: 'CA',
    countryName: 'Canada',
    name: 'Canadian Dime (10\u00A2)',
    diameterMm: 18.03,
    badgeLabel: '10\u00A2',
  ),
  CoinReference(
    countryCode: 'CA',
    countryName: 'Canada',
    name: 'Canadian Nickel (5\u00A2)',
    diameterMm: 21.21,
    badgeLabel: '5\u00A2',
  ),
  CoinReference(
    countryCode: 'CA',
    countryName: 'Canada',
    name: 'Canadian Penny (1\u00A2)',
    diameterMm: 19.05,
    badgeLabel: '1\u00A2',
  ),
  CoinReference(
    countryCode: 'MX',
    countryName: 'Mexico',
    name: 'Mexican 10 Peso',
    diameterMm: 28.00,
    badgeLabel: '10',
  ),
  CoinReference(
    countryCode: 'CR',
    countryName: 'Costa Rica',
    name: '500 Colones (\u20A1500)',
    diameterMm: 28.00,
    badgeLabel: '\u20A1500',
  ),
  CoinReference(
    countryCode: 'CR',
    countryName: 'Costa Rica',
    name: '100 Colones (\u20A1100)',
    diameterMm: 29.50,
    badgeLabel: '\u20A1100',
  ),
  CoinReference(
    countryCode: 'CR',
    countryName: 'Costa Rica',
    name: '50 Colones (\u20A150)',
    diameterMm: 24.50,
    badgeLabel: '\u20A150',
  ),
  CoinReference(
    countryCode: 'CR',
    countryName: 'Costa Rica',
    name: '25 Colones (\u20A125)',
    diameterMm: 22.50,
    badgeLabel: '\u20A125',
  ),
  CoinReference(
    countryCode: 'BR',
    countryName: 'Brazil',
    name: 'Brazilian 1 Real',
    diameterMm: 27.00,
    badgeLabel: 'R\$1',
  ),
  CoinReference(
    countryCode: 'AR',
    countryName: 'Argentina',
    name: 'Argentine Peso',
    diameterMm: 25.00,
    badgeLabel: '\$1',
  ),
  CoinReference(
    countryCode: 'CL',
    countryName: 'Chile',
    name: 'Chilean 100 Peso',
    diameterMm: 25.50,
    badgeLabel: '100',
  ),
  CoinReference(
    countryCode: 'EU',
    countryName: 'Eurozone',
    name: '1 Euro',
    diameterMm: 23.25,
    badgeLabel: '\u20AC1',
  ),
  CoinReference(
    countryCode: 'EU',
    countryName: 'Eurozone',
    name: '2 Euro',
    diameterMm: 25.75,
    badgeLabel: '\u20AC2',
  ),
  CoinReference(
    countryCode: 'EU',
    countryName: 'Eurozone',
    name: '50 Euro Cent',
    diameterMm: 24.25,
    badgeLabel: '50c',
  ),
  CoinReference(
    countryCode: 'EU',
    countryName: 'Eurozone',
    name: '20 Euro Cent',
    diameterMm: 22.25,
    badgeLabel: '20c',
  ),
  CoinReference(
    countryCode: 'EU',
    countryName: 'Eurozone',
    name: 'Dutch coin',
    diameterMm: 21.40,
    badgeLabel: 'NL',
  ),
  CoinReference(
    countryCode: 'DK',
    countryName: 'Denmark',
    name: 'Danish 5 Krone',
    diameterMm: 28.50,
    badgeLabel: '5kr',
  ),
  CoinReference(
    countryCode: 'DK',
    countryName: 'Denmark',
    name: 'Danish 20 Krone',
    diameterMm: 27.00,
    badgeLabel: '20kr',
  ),
  CoinReference(
    countryCode: 'GB',
    countryName: 'United Kingdom',
    name: '1 Pound',
    diameterMm: 23.43,
    badgeLabel: '\u00A31',
  ),
  CoinReference(
    countryCode: 'GB',
    countryName: 'United Kingdom',
    name: '2 Pound',
    diameterMm: 28.40,
    badgeLabel: '\u00A32',
  ),
  CoinReference(
    countryCode: 'GB',
    countryName: 'United Kingdom',
    name: '50 Pence',
    diameterMm: 27.30,
    badgeLabel: '50p',
  ),
  CoinReference(
    countryCode: 'IL',
    countryName: 'Israel',
    name: 'Israeli 5 Shekel',
    diameterMm: 26.00,
    badgeLabel: '\u20AA5',
  ),
  CoinReference(
    countryCode: 'SA',
    countryName: 'Saudi Arabia',
    name: 'Quarter Riyal (25 Dirhams)',
    diameterMm: 20.00,
    badgeLabel: '1/4',
  ),
  CoinReference(
    countryCode: 'ZA',
    countryName: 'South Africa',
    name: 'South African 5 Rand',
    diameterMm: 26.00,
    badgeLabel: 'R5',
  ),
  CoinReference(
    countryCode: 'CN',
    countryName: 'China',
    name: 'Chinese 1 Yuan',
    diameterMm: 25.00,
    badgeLabel: '\u00A51',
  ),
  CoinReference(
    countryCode: 'IN',
    countryName: 'India',
    name: 'Indian 10 Rupee',
    diameterMm: 27.00,
    badgeLabel: '\u20B910',
  ),
  CoinReference(
    countryCode: 'SG',
    countryName: 'Singapore',
    name: 'Singapore 1 Dollar',
    diameterMm: 24.65,
    badgeLabel: 'S\$1',
  ),
  CoinReference(
    countryCode: 'SG',
    countryName: 'Singapore',
    name: 'Singapore 50 Cent',
    diameterMm: 23.60,
    badgeLabel: '50c',
  ),
  CoinReference(
    countryCode: 'AU',
    countryName: 'Australia',
    name: 'Australian Dollar',
    diameterMm: 25.00,
    badgeLabel: 'A\$1',
  ),
  CoinReference(
    countryCode: 'AU',
    countryName: 'Australia',
    name: 'Australian 2 Dollar',
    diameterMm: 20.50,
    badgeLabel: 'A\$2',
  ),
  CoinReference(
    countryCode: 'NZ',
    countryName: 'New Zealand',
    name: 'New Zealand Dollar',
    diameterMm: 23.00,
    badgeLabel: 'NZ\$1',
  ),
];

class CoinSelectorPage extends StatefulWidget {
  const CoinSelectorPage({
    super.key,
    required this.items,
    required this.progressText,
    required this.title,
    this.initialSelection,
  });

  final List<CoinReference> items;
  final String progressText;
  final String title;
  final String? initialSelection;

  @override
  State<CoinSelectorPage> createState() => _CoinSelectorPageState();
}

class _CoinSelectorPageState extends State<CoinSelectorPage> {
  late String _selectedCountryCode;
  bool _isCountryMenuOpen = false;

  List<_CountryGroup> get _countries {
    final Map<String, List<CoinReference>> byCountry =
        <String, List<CoinReference>>{};
    final Map<String, String> namesByCode = <String, String>{};
    for (final CoinReference item in widget.items) {
      byCountry
          .putIfAbsent(item.countryCode, () => <CoinReference>[])
          .add(item);
      namesByCode[item.countryCode] = item.countryName;
    }

    return byCountry.entries
        .map(
          (MapEntry<String, List<CoinReference>> entry) => _CountryGroup(
            code: entry.key,
            name: namesByCode[entry.key] ?? entry.key,
            items: entry.value,
          ),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final CoinReference? matchedItem = widget.items
        .cast<CoinReference?>()
        .firstWhere(
          (CoinReference? item) => item?.name == widget.initialSelection,
          orElse: () => null,
        );
    _selectedCountryCode =
        matchedItem?.countryCode ?? widget.items.first.countryCode;
  }

  @override
  Widget build(BuildContext context) {
    final List<_CountryGroup> countries = _countries;
    final _CountryGroup selectedCountry = countries.firstWhere(
      (_CountryGroup country) => country.code == _selectedCountryCode,
      orElse: () => countries.first,
    );

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: widget.title,
      child: Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.snow,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text(
                widget.progressText,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Choose the coin you are using for accurate measurement.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.blackCatLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Select Country',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _CountryDropdown(
                countries: countries,
                value: _selectedCountryCode,
                isOpen: _isCountryMenuOpen,
                onToggle: () {
                  setState(() => _isCountryMenuOpen = !_isCountryMenuOpen);
                },
                onChanged: (String? next) {
                  if (next == null || next == _selectedCountryCode) return;
                  setState(() {
                    _selectedCountryCode = next;
                    _isCountryMenuOpen = false;
                  });
                },
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: <Widget>[
                    _CountrySection(country: selectedCountry),
                    const SizedBox(height: 18),
                    const _MeasurementInfoCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _CountryGroup {
  const _CountryGroup({
    required this.code,
    required this.name,
    required this.items,
  });

  final String code;
  final String name;
  final List<CoinReference> items;
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({
    required this.countries,
    required this.value,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
  });

  final List<_CountryGroup> countries;
  final String value;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final _CountryGroup selectedCountry = countries.firstWhere(
      (_CountryGroup country) => country.code == value,
      orElse: () => countries.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: 'Select Country',
          value: selectedCountry.name,
          hint: 'Dropdown. Double tap to open.',
          child: ExcludeSemantics(
          child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: isOpen
                    ? AppColors.balletSlippers
                    : AppColors.blackCat.withValues(alpha: 0.22),
                width: isOpen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                _CountryFlag(code: selectedCountry.code),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    selectedCountry.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 28,
                  color: AppColors.blackCat,
                ),
              ],
            ),
          ),
          ),
          ),
        ),
        if (isOpen) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 292),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.14),
              ),
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: countries.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: AppColors.blackCat.withValues(alpha: 0.08),
              ),
              itemBuilder: (BuildContext context, int index) {
                final _CountryGroup country = countries[index];
                final bool isSelected = country.code == value;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: country.name,
                  child: ExcludeSemantics(
                  child: InkWell(
                  onTap: () => onChanged(country.code),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: <Widget>[
                        _CountryFlag(code: country.code),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            country.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.blackCat.withValues(alpha: 0.75),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CountrySection extends StatelessWidget {
  const _CountrySection({required this.country});

  final _CountryGroup country;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: <Widget>[
                _CountryFlag(code: country.code),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    country.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Text(
                  '${country.items.length} coins',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          for (final CoinReference item in country.items) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: _CoinCard(item: item),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  const _CoinCard({required this.item});

  final CoinReference item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${item.name}, ${item.diameterMm.toStringAsFixed(2)} millimeter diameter',
      child: ExcludeSemantics(
      child: InkWell(
      onTap: () => Navigator.pop(context, item.name),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: <Widget>[
            _CoinAvatar(label: item.badgeLabel),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.diameterMm.toStringAsFixed(2)}mm diameter',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.blackCat.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.blackCat.withValues(alpha: 0.85),
              size: 28,
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}

class _MeasurementInfoCard extends StatelessWidget {
  const _MeasurementInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.alabaster.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.balletSlippers.withValues(alpha: 0.6),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.blackCat,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Using the right coin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'For best results, use a coin that is flat, undamaged, and clearly visible in the photo.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCatLight,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryFlag extends StatelessWidget {
  const _CountryFlag({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    if (code == 'EU') {
      return _FallbackFlag(label: 'EU');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        'https://flagcdn.com/w80/${code.toLowerCase()}.png',
        width: 32,
        height: 24,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) {
              return _FallbackFlag(label: code);
            },
      ),
    );
  }
}

class _FallbackFlag extends StatelessWidget {
  const _FallbackFlag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.alabaster,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.blackCat,
        ),
      ),
    );
  }
}

class _CoinAvatar extends StatelessWidget {
  const _CoinAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF8F4EE),
            Color(0xFFE4D9CC),
            Color(0xFFCCC0B3),
          ],
        ),
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.15)),
      ),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white.withValues(alpha: 0.55)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.blackCat,
          ),
        ),
      ),
    );
  }
}
