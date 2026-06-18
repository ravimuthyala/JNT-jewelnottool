import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';

class PersonalInfoEditResult {
  const PersonalInfoEditResult({
    required this.profile,
    this.selectedPhotoBytes,
  });

  final ClientProfileDraft profile;
  final Uint8List? selectedPhotoBytes;
}

class EditPersonalInfoPopup extends StatefulWidget {
  const EditPersonalInfoPopup({super.key, required this.profile});

  final ClientProfileDraft profile;

  static Future<String> uploadProfilePhoto(Uint8List bytes) {
    return EditProfileSupabaseSave.uploadProfilePhoto(bytes);
  }

  @override
  State<EditPersonalInfoPopup> createState() => _EditPersonalInfoPopupState();
}

class _EditPersonalInfoPopupState extends State<EditPersonalInfoPopup> {
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;

  final FocusNode _nameFocusNode = FocusNode(debugLabel: 'personalInfoName');
  final FocusNode _emailFocusNode = FocusNode(debugLabel: 'personalInfoEmail');
  final FocusNode _phoneFocusNode = FocusNode(debugLabel: 'personalInfoPhone');

  Uint8List? _selectedPhotoBytes;
  String _photoUrl = '';
  bool _saving = false;
  bool _pickingPhoto = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.profile.basic.name);
    emailCtrl = TextEditingController(text: widget.profile.basic.email);
    phoneCtrl = TextEditingController(text: widget.profile.basic.phone);
    _photoUrl = widget.profile.basic.profileImageUrl.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (!_shouldUseAccessibilityEnhancements(context)) return;
      _nameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  bool _shouldUseAccessibilityEnhancements(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.accessibleNavigation ??
        WidgetsBinding
            .instance.platformDispatcher.accessibilityFeatures.accessibleNavigation;
  }

  void _announce(String message) {
    if (!mounted) return;
    if (!_shouldUseAccessibilityEnhancements(context)) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _pickPhoto() async {
    if (_pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    _announce('Opening photo library');
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 960,
        maxHeight: 960,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final optimized = _optimizeProfilePhoto(bytes) ?? bytes;
      if (!mounted) return;
      setState(() => _selectedPhotoBytes = optimized);
      _announce('Profile photo selected');
    } catch (_) {
      if (!mounted) return;
      const message = 'Unable to pick profile photo.';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
      );
      _announce(message);
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Uint8List? _optimizeProfilePhoto(Uint8List source) {
    final decoded = img.decodeImage(source);
    if (decoded == null) return null;
    img.Image processed = decoded;
    final maxSide = processed.width > processed.height
        ? processed.width
        : processed.height;
    if (maxSide > 640) {
      final scale = 640 / maxSide;
      processed = img.copyResize(
        processed,
        width: (processed.width * scale).round(),
        height: (processed.height * scale).round(),
        interpolation: img.Interpolation.average,
      );
    }
    return Uint8List.fromList(img.encodeJpg(processed, quality: 62));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    _announce('Saving personal information');

    var resolvedPhotoUrl = _photoUrl.trim();
    if (_selectedPhotoBytes != null) {
      try {
        resolvedPhotoUrl =
            await EditProfileSupabaseSave.uploadProfilePhoto(_selectedPhotoBytes!);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to upload profile photo: $e')),
        );
        setState(() => _saving = false);
        return;
      }
    }

    final updated = widget.profile.copyWith(
      basic: widget.profile.basic.copyWith(
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        profileImageUrl: resolvedPhotoUrl,
      ),
    );

    try {
      await EditProfileSupabaseSave.savePersonalProfile(updated);
      if (resolvedPhotoUrl.trim().isNotEmpty) {
        await EditProfileSupabaseSave.saveProfilePhotoUrl(resolvedPhotoUrl);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save personal information: $e')),
      );
      setState(() => _saving = false);
      return;
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      PersonalInfoEditResult(
        profile: updated,
        selectedPhotoBytes: _selectedPhotoBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Personal Information',
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.blackCatBorderLight),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // top handle is decorative only
                  ExcludeSemantics(
                    child: Container(
                      height: 5,
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
                      Expanded(
                        child: Center(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Personal Information',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: AppColors.blackCat,
                                fontFamily: 'ArialBold',
                              ),
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Close personal information',
                        onTap: () => Navigator.pop(context),
                        child: ExcludeSemantics(
                          child: InkWell(
                            borderRadius: BorderRadius.zero,
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: AppColors.blackCat,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  _ProfileUploadPicker(
                    imageBytes: _selectedPhotoBytes,
                    imageProvider: _networkOrInlineProvider(_photoUrl),
                    loading: _pickingPhoto,
                    enabled: !_saving,
                    onTap: _pickPhoto,
                  ),
                  const SizedBox(height: 6),

                  _field('Name', nameCtrl, focusNode: _nameFocusNode),
                  const SizedBox(height: 6),
                  _field(
                    'Email',
                    emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    focusNode: _emailFocusNode,
                    semanticLabel: 'Email, email address, text field',
                  ),
                  const SizedBox(height: 6),
                  _field(
                    'Phone',
                    phoneCtrl,
                    keyboardType: TextInputType.phone,
                    focusNode: _phoneFocusNode,
                    semanticLabel: 'Phone, phone number, text field',
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(
                        _saving ? 'Saving...' : 'Save',
                        style: const TextStyle(
                          fontSize: 13,
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

  ImageProvider? _networkOrInlineProvider(String src) {
    final value = src.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma > 0 && comma < value.length - 1) {
        try {
          return MemoryImage(base64Decode(value.substring(comma + 1)));
        } catch (_) {
          return null;
        }
      }
      return null;
    }
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return NetworkImage(value);
    }
    return null;
  }

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboardType,
    FocusNode? focusNode,
    String? semanticLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.blackCat,
              fontFamily: 'ArialBold',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          container: true,
          textField: true,
          label: semanticLabel ?? '$label, text field',
          child: TextField(
            controller: c,
            focusNode: focusNode,
            keyboardType: keyboardType,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              fontFamily: 'Arial',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.snow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
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
}

class _ProfileUploadPicker extends StatelessWidget {
  const _ProfileUploadPicker({
    required this.onTap,
    required this.loading,
    required this.enabled,
    this.imageBytes,
    this.imageProvider,
  });

  final VoidCallback onTap;
  final bool loading;
  final bool enabled;
  final Uint8List? imageBytes;
  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBytes != null || imageProvider != null;
    final semanticLabel = hasImage
        ? 'Change profile photo'
        : 'Add profile photo';

    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? 'Loading profile photo' : semanticLabel,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: enabled ? onTap : null,
                child: Container(
                  height: 88,
                  width: 88,
                  decoration: BoxDecoration(
                    color: AppColors.snow,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: AppColors.blackCat.withValues(alpha: 0.35),
                      width: 1.4,
                    ),
                  ),
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          width: 88,
                          height: 88,
                        )
                      : imageProvider != null
                          ? Image(
                              image: imageProvider!,
                              fit: BoxFit.cover,
                              width: 88,
                              height: 88,
                            )
                          : Icon(
                              Icons.camera_alt_outlined,
                              size: 26,
                              color: AppColors.blackCat,
                            ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: GestureDetector(
                  onTap: enabled ? onTap : null,
                  child: Container(
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.blackCatBorderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blackCat.withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasImage
                          ? Icons.file_upload_outlined
                          : Icons.photo_camera_outlined,
                      color: AppColors.blackCat,
                      size: 16,
                    ),
                  ),
                ),
              ),
              if (loading)
                const Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
