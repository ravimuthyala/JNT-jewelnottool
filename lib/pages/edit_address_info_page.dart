import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'edit_shipping_address_page.dart' show usStates, countries;

class EditAddressInfoPage extends StatefulWidget {
  const EditAddressInfoPage({super.key, required this.initial});
  final AddressInfo initial;

  @override
  State<EditAddressInfoPage> createState() => _EditAddressInfoPageState();
}

class _EditAddressInfoPageState extends State<EditAddressInfoPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _street;
  late final TextEditingController _city;
  String? _stateValue;
  late final TextEditingController _zip;
  String? _countryValue;

  @override
  void initState() {
    super.initState();
    _street = TextEditingController(text: widget.initial.street);
    _city = TextEditingController(text: widget.initial.city);
    _stateValue = _initStateValue(widget.initial.state);
    _zip = TextEditingController(text: widget.initial.zip);
    _countryValue = _initCountryValue(widget.initial.country);
  }

  @override
  void dispose() {
    _street.dispose();
    _city.dispose();
    _zip.dispose();
    super.dispose();
  }

  String? _req(String? v, String name) =>
      (v == null || v.trim().isEmpty) ? '$name is required' : null;
  bool get _isUnitedStates =>
      (_countryValue ?? '').trim().toLowerCase() == 'united states';

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      filled: true,
      fillColor: AppColors.snow,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.blackCatBorderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(
          color: AppColors.blackCatLight,
          width: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Edit address',
      child: Material(
      color: AppColors.snow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Address',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Semantics(
                  isRequired: true,
                  child: TextFormField(
                    controller: _street,
                    style: const TextStyle(fontSize: 12),
                    decoration: _dec('Street'),
                    validator: (v) => _req(v, 'Street'),
                  ),
                ),
                const SizedBox(height: 8),

                Semantics(
                  isRequired: true,
                  child: TextFormField(
                    controller: _city,
                    style: const TextStyle(fontSize: 12),
                    decoration: _dec('City'),
                    validator: (v) => _req(v, 'City'),
                  ),
                ),
                const SizedBox(height: 8),

                SearchableDropdownField(
                  label: 'State',
                  value: _stateValue,
                  items: usStates,
                  hint: 'Select state',
                  fillColor: AppColors.snow,
                  borderColor: AppColors.blackCatBorderLight,
                  onChanged: (value) => setState(() => _stateValue = value),
                ),
                const SizedBox(height: 8),

                Semantics(
                  isRequired: _isUnitedStates,
                  child: TextFormField(
                    controller: _zip,
                    style: const TextStyle(fontSize: 12),
                    decoration: _dec('Zip'),
                    validator: (v) => _isUnitedStates ? _req(v, 'Zip') : null,
                  ),
                ),
                const SizedBox(height: 8),

                SearchableDropdownField(
                  label: 'Country',
                  value: _countryValue,
                  items: countries,
                  hint: 'Select country',
                  fillColor: AppColors.snow,
                  borderColor: AppColors.blackCatBorderLight,
                  onChanged: (value) => setState(() => _countryValue = value),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepPlum,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState?.validate() != true) return;
                      if ((_countryValue ?? '').trim().isEmpty ||
                          (_isUnitedStates &&
                              (_stateValue ?? '').trim().isEmpty)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select state and country.'),
                          ),
                        );
                        return;
                      }

                      final updated = AddressInfo(
                        street: _street.text.trim(),
                        city: _city.text.trim(),
                        state: (_stateValue ?? '').trim(),
                        zip: _zip.text.trim(),
                        country: (_countryValue ?? '').trim(),
                      );

                      try {
                        await EditProfileSupabaseSave.saveAddressInfo(updated);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Unable to save address: $e')),
                        );
                        return;
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context, updated);
                    },
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
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
