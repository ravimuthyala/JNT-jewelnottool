import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'registration_draft.dart';
import '_widgets/reg_helpers.dart';

class Step2Location extends StatefulWidget {
  const Step2Location({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  State<Step2Location> createState() => Step2LocationState();
}

class Step2LocationState extends State<Step2Location> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _cityCtrl;
  late final TextEditingController _manualStateCtrl;
  late final TextEditingController _addressLine1Ctrl;
  late final TextEditingController _addressLine2Ctrl;
  late final TextEditingController _addressCityCtrl;
  late final TextEditingController _zipCtrl;

  String _country = 'United States';
  String? _state;
  String _timeZone = 'America/New_York';

  bool get _isUS => _country == 'United States';

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _cityCtrl = TextEditingController(text: d.city);
    _manualStateCtrl = TextEditingController(text: d.manualState);
    _addressLine1Ctrl = TextEditingController(text: d.addressLine1);
    _addressLine2Ctrl = TextEditingController(text: d.addressLine2);
    _addressCityCtrl = TextEditingController(text: d.addressCity);
    _zipCtrl = TextEditingController(text: d.zip);
    _country = d.country.isEmpty ? 'United States' : d.country;
    _state = d.state;
    _timeZone = d.timeZone.isEmpty ? 'America/New_York' : d.timeZone;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _manualStateCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _addressCityCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  void autofill() {
    setState(() {
      _cityCtrl.text = 'Los Angeles';
      _country = 'United States';
      _state = 'California';
      _manualStateCtrl.text = '';
      _timeZone = 'America/Los_Angeles';
      _addressLine1Ctrl.text = '123 Sunset Blvd';
      _addressLine2Ctrl.text = 'Apt 4B';
      _addressCityCtrl.text = 'Los Angeles';
      _zipCtrl.text = '90028';
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    draft.city = _cityCtrl.text.trim();
    draft.country = _country;
    draft.state = _state;
    draft.manualState = _manualStateCtrl.text.trim();
    draft.timeZone = _timeZone;
    draft.addressLine1 = _addressLine1Ctrl.text.trim();
    draft.addressLine2 = _addressLine2Ctrl.text.trim();
    draft.addressCity = _addressCityCtrl.text.trim();
    draft.zip = _zipCtrl.text.trim();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          // ── Location & Service Area ────────────────────────────────────────
          regSectionCard(
            title: 'Location & Service Area',
            child: Column(
              children: [
                TextFormField(
                  controller: _cityCtrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('City *', 'City'),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (val.isEmpty) return 'City is required';
                    if (!RegExp(r"^[A-Za-z .'-]{2,}$").hasMatch(val)) return 'Enter a valid city';
                    return null;
                  },
                ),
                const SizedBox(height: 6),

                RegTypeAheadField(
                  label: 'Country *',
                  hint: 'Select country',
                  options: kCountries,
                  selectedValue: _country,
                  onChanged: (v) => setState(() {
                    _country = v ?? 'United States';
                    if (!_isUS) _state = null;
                  }),
                  validator: (v) => (v == null || v.isEmpty) ? 'Country is required' : null,
                ),
                const SizedBox(height: 6),

                if (_isUS) ...[
                  RegTypeAheadField(
                    label: 'State *',
                    hint: 'Select state',
                    options: kUsStates,
                    selectedValue: _state,
                    onChanged: (v) => setState(() => _state = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'State is required' : null,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _manualStateCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('State / Region', 'Enter region'),
                  ),
                ],
                const SizedBox(height: 6),

                DropdownButtonFormField<String>(
                  initialValue: _timeZone,
                  style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat, fontWeight: FontWeight.w400),
                  decoration: regDec('Time Zone *', 'America/New_York'),
                  items: kTimeZones
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _timeZone = v ?? _timeZone),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Address Information ────────────────────────────────────────────
          regSectionCard(
            title: 'Address Information',
            subtitle: 'Provide your shipping address (all fields required)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                regRequiredLabel('Street Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressLine1Ctrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('Street Address', 'Enter Street Address'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Street Address is required' : null,
                ),
                const SizedBox(height: 12),

                const Text('Apt / Suite (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blackCat)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressLine2Ctrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('Apt / Suite', 'Enter Apt / Suite (optional)'),
                ),
                const SizedBox(height: 12),

                regRequiredLabel('City'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressCityCtrl,
                  style: const TextStyle(fontSize: kInputFs),
                  decoration: regDec('City', 'Enter City'),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'City is required' : null,
                ),
                const SizedBox(height: 12),

                if (_isUS) regRequiredLabel('State') else const Text('State / Region', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blackCat)),
                const SizedBox(height: 6),
                if (_isUS)
                  RegTypeAheadField(
                    label: 'State',
                    hint: 'Select State',
                    options: kUsStates,
                    selectedValue: _state,
                    onChanged: (v) => setState(() => _state = v),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'State is required' : null,
                  )
                else
                  TextFormField(
                    controller: _manualStateCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('State / Region', 'Enter State / Region'),
                  ),
                const SizedBox(height: 12),

                if (_isUS) regRequiredLabel('Zip Code') else const Text('Zip Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blackCat)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _zipCtrl,
                  style: const TextStyle(fontSize: kInputFs),
                  keyboardType: TextInputType.text,
                  decoration: regDec('Zip Code', 'Enter Zip Code'),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (val.isEmpty) return _isUS ? 'Zip Code is required' : null;
                    if (!_isUS) return null;
                    if (!RegExp(r'^\d{5}(-\d{4})?$').hasMatch(val)) return 'Enter a valid ZIP code';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                regRequiredLabel('Country'),
                const SizedBox(height: 6),
                RegTypeAheadField(
                  label: 'Country',
                  hint: 'Select Country',
                  options: kCountries,
                  selectedValue: _country,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _country = v;
                      if (_country != 'United States') { _state = null; _zipCtrl.clear(); }
                    });
                  },
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Country is required' : null,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
