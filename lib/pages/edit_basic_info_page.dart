import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';

class EditBasicInfoPage extends StatefulWidget {
  const EditBasicInfoPage({super.key, required this.initial});
  final BasicInfo initial;

  @override
  State<EditBasicInfoPage> createState() => _EditBasicInfoPageState();
}

class _EditBasicInfoPageState extends State<EditBasicInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _email = TextEditingController(text: widget.initial.email);
    _phone = TextEditingController(text: widget.initial.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _req(String? v, String name) =>
      (v == null || v.trim().isEmpty) ? '$name is required' : null;

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
        borderSide: const BorderSide(color: AppColors.alabaster),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: AppColors.alabaster, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
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
                        'Edit Basic Info',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.black.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                TextFormField(
                  controller: _name,
                  style: const TextStyle(fontSize: 12),
                  decoration: _dec('Name'),
                  validator: (v) => _req(v, 'Name'),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _email,
                  style: const TextStyle(fontSize: 12),
                  decoration: _dec('Email'),
                  validator: (v) => _req(v, 'Email'),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _phone,
                  style: const TextStyle(fontSize: 12),
                  decoration: _dec('Phone'),
                  validator: (v) => _req(v, 'Phone'),
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

                      final updated = BasicInfo(
                        name: _name.text.trim(),
                        email: _email.text.trim(),
                        phone: _phone.text.trim(),
                      );

                      try {
                        await EditProfileSupabaseSave.saveBasicInfo(updated);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to save basic info: $e'),
                          ),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
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
