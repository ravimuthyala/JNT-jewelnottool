import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ✅ Import ClientProfileDraft (and whatever it needs)
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';

class EditPersonalInfoPage extends StatefulWidget {
  const EditPersonalInfoPage({super.key, required this.profile});

  final ClientProfileDraft profile;

  @override
  State<EditPersonalInfoPage> createState() => _EditPersonalInfoPageState();
}

class _EditPersonalInfoPageState extends State<EditPersonalInfoPage> {
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.profile.basic.name);
    emailCtrl = TextEditingController(text: widget.profile.basic.email);
    phoneCtrl = TextEditingController(text: widget.profile.basic.phone);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.profile.copyWith(
      basic: widget.profile.basic.copyWith(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
      ),
    );

    try {
      await EditProfileSupabaseSave.savePersonalProfile(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save personal info: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Image.asset(
          'assets/images/jnt_logo_black.png',
          height: 50,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          _field('Name', nameCtrl),
          const SizedBox(height: 6),
          _field('Email', emailCtrl, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 6),
          _field('Phone', phoneCtrl, keyboardType: TextInputType.phone),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blackCat,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: _save,
              child: const Text(
                'Save',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            color: AppColors.blackCat.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: keyboardType,
          // ✅ ADD THIS
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.snow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: AppColors.alabaster),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: AppColors.alabaster),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: const BorderSide(color: AppColors.alabaster),
            ),
          ),
        ),
      ],
    );
  }
}

