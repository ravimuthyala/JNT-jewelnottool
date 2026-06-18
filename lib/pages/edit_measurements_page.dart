import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';
import '../widgets/nail_preferences_inline_editor.dart';

class EditMeasurementsPopup extends StatefulWidget {
  const EditMeasurementsPopup({super.key, required this.initial});

  final NailPreferences initial;

  @override
  State<EditMeasurementsPopup> createState() => _EditMeasurementsPopupState();
}

class _EditMeasurementsPopupState extends State<EditMeasurementsPopup> {
  late NailPreferences _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Future<void> _save() async {
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Measurements saved',
      Directionality.of(context),
    );
    try {
      await EditProfileSupabaseSave.saveNailPreferences(_draft);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save measurements: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context, _draft);
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'My Measurements',
      child: SafeArea(
        top: true,
        child: Container(
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Container(
            padding: EdgeInsets.only(bottom: bottom),
            decoration: const BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, topInset > 0 ? 8 : 10, 16, 18),
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
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
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Center(
                          child: ExcludeSemantics(
                            child: Text(
                              'My Measurements',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppColors.blackCat,
                                fontFamily: 'Arialbold',
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Semantics(
                            sortKey: const OrdinalSortKey(4),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                tooltip: 'Close my measurements',
                                padding: const EdgeInsets.all(10),
                                splashRadius: 22,
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 22,
                                  color: AppColors.blackCat,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    Semantics(
                      sortKey: const OrdinalSortKey(1),
                      explicitChildNodes: true,
                      child: NailPreferencesInlineEditor(
                        initial: _draft,
                        showMeasurementTips: false,
                        showDimensionImages: false,
                        useBlackModalStyle: false,
                        showOuterContainer: false,
                        onChanged: (updated) {
                          _draft = updated;
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    Semantics(
                      sortKey: const OrdinalSortKey(3),
                      child: SizedBox(
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
                              fontFamily: 'ArialBold',
                            ),
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
      ),
    );
  }
}
