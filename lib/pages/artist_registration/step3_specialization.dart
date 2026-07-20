import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/direct_request_year_calendar.dart';
import '_widgets/reg_helpers.dart';
import 'registration_draft.dart';

class Step3Specialization extends StatefulWidget {
  const Step3Specialization({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  State<Step3Specialization> createState() => Step3SpecializationState();
}

class Step3SpecializationState extends State<Step3Specialization> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _manualStateCtrl;
  late Set<String> _services;
  late bool _rush;
  late bool _directRequestsEnabled;
  late bool _nfcRequestEnabled;
  late int _directRequestYear;
  late Set<DateTime> _blockedDates;
  String _country = 'United States';
  String? _state;
  String _timeZone = 'America/New_York';
  bool _showCalendar = false;
  int _calendarNonce = 0;

  bool get _isUS => _country == 'United States';

  static const List<String> _serviceOptions = [
    'Intricate Nail Art',
    'Gel / Acrylic',
    '3D Nail Art',
    'Airbrush/Stamping',
    'Encapsulation',
    'Dip Powder',
    'Sculptured',
    'PolyGel',
    'Chrome & Metallic',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _minPriceCtrl = TextEditingController(text: d.minPrice);
    _maxPriceCtrl = TextEditingController(text: d.maxPrice);
    _cityCtrl = TextEditingController(text: d.city);
    _manualStateCtrl = TextEditingController(text: d.manualState);
    _services = Set<String>.from(d.services);
    _rush = d.rush;
    _directRequestsEnabled = d.directRequestsEnabled;
    _nfcRequestEnabled = d.nfcRequestEnabled;
    _directRequestYear = d.directRequestYear;
    _blockedDates = Set<DateTime>.from(d.blockedDates);
    _country = d.country.isEmpty ? 'United States' : d.country;
    _state = d.state;
    _timeZone = d.timeZone.isEmpty ? 'America/New_York' : d.timeZone;
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _cityCtrl.dispose();
    _manualStateCtrl.dispose();
    super.dispose();
  }

  void autofill() {
    setState(() {
      _services
        ..clear()
        ..addAll({
          'Intricate Nail Art',
          'Gel / Acrylic',
          'Chrome & Metallic',
          '3D Nail Art',
        });
      _minPriceCtrl.text = '50';
      _maxPriceCtrl.text = '350';
      _rush = true;
      _directRequestsEnabled = true;
      _nfcRequestEnabled = true;
      _cityCtrl.text = 'Los Angeles';
      _country = 'United States';
      _state = 'California';
      _manualStateCtrl.clear();
      _timeZone = 'America/Los_Angeles';
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    draft.services = Set<String>.from(_services);
    draft.minPrice = _minPriceCtrl.text.trim();
    draft.maxPrice = _maxPriceCtrl.text.trim();
    draft.rush = _rush;
    draft.directRequestsEnabled = _directRequestsEnabled;
    draft.nfcRequestEnabled = _nfcRequestEnabled;
    draft.directRequestYear = _directRequestYear;
    draft.blockedDates = Set<DateTime>.from(_blockedDates);
    draft.city = _cityCtrl.text.trim();
    draft.country = _country;
    draft.state = _state;
    draft.manualState = _manualStateCtrl.text.trim();
    draft.timeZone = _timeZone;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          regSectionCard(
            title: 'Specialization',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _serviceOptions.map((s) {
                    return regChip(s, _services.contains(s), () {
                      setState(() {
                        if (_services.contains(s)) {
                          _services.remove(s);
                        } else {
                          _services.add(s);
                        }
                      });
                    });
                  }).toList(),
                ),
                const SizedBox(height: kFieldGap),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        isRequired: true,
                        child: TextFormField(
                        controller: _minPriceCtrl,
                        style: const TextStyle(fontSize: kInputFs),
                        keyboardType: TextInputType.number,
                        decoration: regDec('Min Price (\$) *', '50'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        isRequired: true,
                        child: TextFormField(
                        controller: _maxPriceCtrl,
                        style: const TextStyle(fontSize: kInputFs),
                        keyboardType: TextInputType.number,
                        decoration: regDec('Max Price (\$) *', '200'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: kFieldGap),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rush availability',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.blackCat,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enable if you can take expedited requests.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.blackCat.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.88,
                      child: Switch(
                        value: _rush,
                        onChanged: (v) => setState(() => _rush = v),
                        activeThumbColor: const Color(0xFF1F1B24),
                        activeTrackColor: const Color(
                          0xFF1F1B24,
                        ).withValues(alpha: 0.45),
                        inactiveThumbColor: AppColors.blackCatLight,
                        inactiveTrackColor: AppColors.blackCatLight.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          regSectionCard(
            title: 'Location & Service Area',
            child: Column(
              children: [
                Semantics(
                  isRequired: true,
                  child: TextFormField(
                  controller: _cityCtrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('City *', 'City'),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (val.isEmpty) return 'City is required';
                    if (!RegExp(r"^[A-Za-z .'-]{2,}$").hasMatch(val)) {
                      return 'Enter a valid city';
                    }
                    return null;
                  },
                  ),
                ),
                const SizedBox(height: kFieldGap),
                RegTypeAheadField(
                  label: 'Country *',
                  hint: 'Select country',
                  options: kCountries,
                  selectedValue: _country,
                  onChanged: (v) => setState(() {
                    _country = v ?? 'United States';
                    if (!_isUS) _state = null;
                  }),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Country is required' : null,
                ),
                const SizedBox(height: kFieldGap),
                if (_isUS) ...[
                  RegTypeAheadField(
                    label: 'State *',
                    hint: 'Select state',
                    options: kUsStates,
                    selectedValue: _state,
                    onChanged: (v) => setState(() => _state = v),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'State is required' : null,
                  ),
                ] else ...[
                  Semantics(
                    isRequired: true,
                    child: TextFormField(
                    controller: _manualStateCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('State / Region', 'Enter region'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'State / Region is required'
                        : null,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _timeZone,
                  dropdownColor: AppColors.snow,
                  style: const TextStyle(
                    fontSize: kInputFs,
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: regDec('Time Zone *', 'America/New_York'),
                  items: kTimeZones
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: kInputFs,
                              color: AppColors.blackCat,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _timeZone = v ?? _timeZone),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          regSectionCard(
            title: 'Year Calendar Availability',
            subtitle: 'Direct requests and blocked dates.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _directRequestsEnabled,
                  activeThumbColor: AppColors.blackCat,
                  activeTrackColor: AppColors.blackCat.withValues(alpha: 0.45),
                  inactiveThumbColor: AppColors.blackCat.withValues(
                    alpha: 0.55,
                  ),
                  inactiveTrackColor: AppColors.blackCat.withValues(
                    alpha: 0.25,
                  ),
                  onChanged: (v) => setState(() => _directRequestsEnabled = v),
                  title: const Text(
                    'Enable direct requests',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Allow clients to request specific dates.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _nfcRequestEnabled,
                  activeThumbColor: AppColors.blackCat,
                  activeTrackColor: AppColors.blackCat.withValues(alpha: 0.45),
                  inactiveThumbColor: AppColors.blackCat.withValues(
                    alpha: 0.55,
                  ),
                  inactiveTrackColor: AppColors.blackCat.withValues(
                    alpha: 0.25,
                  ),
                  onChanged: (v) => setState(() => _nfcRequestEnabled = v),
                  title: const Text(
                    'Accepts NFC',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Allow clients to send NFC upgrade requests.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.blackCat.withValues(alpha: 0.55),
                    ),
                  ),
                ),
                const SizedBox(height: kTightGap),
                Semantics(
                  button: true,
                  label: _showCalendar ? 'Hide year calendar' : 'Show year calendar',
                  child: ExcludeSemantics(
                  child: InkWell(
                  onTap: () => setState(() {
                    _showCalendar = !_showCalendar;
                    if (_showCalendar) {
                      _calendarNonce = DateTime.now().millisecondsSinceEpoch;
                    }
                  }),
                  child: Row(
                    children: [
                      Icon(
                        _showCalendar ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.blackCat.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showCalendar
                            ? 'Hide year calendar'
                            : 'Show year calendar',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  ),
                  ),
                ),
                if (_showCalendar) ...[
                  const SizedBox(height: kTightGap),
                  DirectRequestYearCalendar(
                    key: ValueKey(_calendarNonce),
                    initialDirectRequestsOn: _directRequestsEnabled,
                    initialYear: _directRequestYear,
                    initialMonth: DateTime.now().month,
                    initialBlockedDays: _blockedDates,
                    showDirectRequestsFooter: false,
                    onChanged: (directRequestsOn, year, blockedDays) {
                      setState(() {
                        _directRequestsEnabled = directRequestsOn;
                        _directRequestYear = year;
                        _blockedDates
                          ..clear()
                          ..addAll(blockedDays);
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
