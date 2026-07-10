import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../models/client_profile_models.dart';
import '../services/edit_profile_supabase_save.dart';
import '../utils/registration_input_utils.dart';
import '../widgets/jnt_modal_app_bar.dart';

class EditNailPreferencesPage extends StatefulWidget {
  const EditNailPreferencesPage({super.key, required this.initial});
  final NailPreferences initial;

  @override
  State<EditNailPreferencesPage> createState() =>
      _EditNailPreferencesPageState();
}

class _EditNailPreferencesPageState extends State<EditNailPreferencesPage> {
  // Dimensions controllers (10)
  late final TextEditingController lThumb;
  late final TextEditingController lIndex;
  late final TextEditingController lMiddle;
  late final TextEditingController lRing;
  late final TextEditingController lPinky;

  late final TextEditingController rThumb;
  late final TextEditingController rIndex;
  late final TextEditingController rMiddle;
  late final TextEditingController rRing;
  late final TextEditingController rPinky;

  final FocusNode _leftThumbFocusNode = FocusNode(
    debugLabel: 'leftThumbMeasurementField',
  );

  String selectedShape = '';
  NailLength selectedLength = NailLength.medium;

  bool _a11yNavigationActive(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.accessibleNavigation ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
  }

  @override
  void initState() {
    super.initState();

    final d = widget.initial.dimensions;

    lThumb = TextEditingController(text: _t(d.lThumb));
    lIndex = TextEditingController(text: _t(d.lIndex));
    lMiddle = TextEditingController(text: _t(d.lMiddle));
    lRing = TextEditingController(text: _t(d.lRing));
    lPinky = TextEditingController(text: _t(d.lPinky));

    rThumb = TextEditingController(text: _t(d.rThumb));
    rIndex = TextEditingController(text: _t(d.rIndex));
    rMiddle = TextEditingController(text: _t(d.rMiddle));
    rRing = TextEditingController(text: _t(d.rRing));
    rPinky = TextEditingController(text: _t(d.rPinky));

    selectedShape = widget.initial.shape;
    selectedLength = widget.initial.length;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (!_a11yNavigationActive(context)) return;

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      _leftThumbFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _leftThumbFocusNode.dispose();

    lThumb.dispose();
    lIndex.dispose();
    lMiddle.dispose();
    lRing.dispose();
    lPinky.dispose();

    rThumb.dispose();
    rIndex.dispose();
    rMiddle.dispose();
    rRing.dispose();
    rPinky.dispose();
    super.dispose();
  }

  String _t(double? v) {
    if (v == null) return '';
    if (!v.isFinite) return '';
    return v.toStringAsFixed(2);
  }

  double? _parse(String v) {
    final cleaned = v.trim().replaceAll(
      RegExp(r'\s*mm$', caseSensitive: false),
      '',
    );
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite) return null;
    return parsed;
  }

  InputDecoration _miniDec() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.snow,
    hintText: '0.0',
    hintStyle: TextStyle(
      fontSize: 12,
      color: AppColors.blackCat.withValues(alpha: 0.35),
      fontWeight: FontWeight.w400,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(
        color: AppColors.blackCat.withValues(alpha: 0.35),
        width: 1.8,
      ),
    ),
  );

  TextStyle _subhead() => TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 15.5,
    color: AppColors.blackCat.withValues(alpha: 0.85),
  );

  Future<void> _save() async {
    final dims = NailDimensions(
      lThumb: _parse(lThumb.text),
      lIndex: _parse(lIndex.text),
      lMiddle: _parse(lMiddle.text),
      lRing: _parse(lRing.text),
      lPinky: _parse(lPinky.text),
      rThumb: _parse(rThumb.text),
      rIndex: _parse(rIndex.text),
      rMiddle: _parse(rMiddle.text),
      rRing: _parse(rRing.text),
      rPinky: _parse(rPinky.text),
    );

    if (!dims.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 10 nail measurements.')),
      );
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Please enter all 10 nail measurements.',
        Directionality.of(context),
      );
      if (_a11yNavigationActive(context)) {
        _leftThumbFocusNode.requestFocus();
      }
      return;
    }

    if (selectedShape.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a nail shape.')),
      );
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Please select a nail shape.',
        Directionality.of(context),
      );
      return;
    }

    if (selectedLength == NailLength.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a nail length.')),
      );
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Please select a nail length.',
        Directionality.of(context),
      );
      return;
    }

    final updated = NailPreferences(
      dimensions: dims,
      shape: selectedShape,
      length: selectedLength,
    );

    try {
      await EditProfileSupabaseSave.saveNailPreferences(updated);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save nail preferences: $e')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'My Measurements',
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: JntModalAppBar(
          onClose: () => Navigator.pop(context),
          closeTooltip: 'Close measurements',
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            _Card(
              title: 'Nail Dimension, in millimeters, required',
              subtitle: null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),

                  Center(
                    child: Semantics(
                      header: true,
                      child: Text('Left Hand', style: _subhead()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FingerRow(
                    handLabel: 'Left',
                    items: [
                      _FingerItemData('Thumb', lThumb, _leftThumbFocusNode),
                      _FingerItemData('Index', lIndex, null),
                      _FingerItemData('Middle', lMiddle, null),
                      _FingerItemData('Ring', lRing, null),
                      _FingerItemData('Pinky', lPinky, null),
                    ],
                    inputDecoration: _miniDec,
                  ),

                  const SizedBox(height: 18),

                  Center(
                    child: Semantics(
                      header: true,
                      child: Text('Right Hand', style: _subhead()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FingerRow(
                    handLabel: 'Right',
                    items: [
                      _FingerItemData('Thumb', rThumb, null),
                      _FingerItemData('Index', rIndex, null),
                      _FingerItemData('Middle', rMiddle, null),
                      _FingerItemData('Ring', rRing, null),
                      _FingerItemData('Pinky', rPinky, null),
                    ],
                    inputDecoration: _miniDec,
                  ),

                  const SizedBox(height: 18),
                  _tipsBox(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            _Card(
              title: 'Choose Your Nail Shape, required',
              subtitle: 'Scroll and select one shape',
              child: SizedBox(
                height: 124,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: nailShapes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final s = nailShapes[i];
                    final selected = s == selectedShape;
                    return _ShapeCard(
                      label: s,
                      selected: selected,
                      onTap: () => setState(() => selectedShape = s),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            _Card(
              title: 'Choose Your Nail Length, required',
              subtitle: 'Pick the length you prefer',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _LengthCard(
                          title: 'Extra Short',
                          subtitle: 'Minimal extension',
                          selected: selectedLength == NailLength.xlLong,
                          onTap: () => setState(
                            () => selectedLength = NailLength.xlLong,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LengthCard(
                          title: 'Short',
                          subtitle: 'Just past fingertip',
                          selected: selectedLength == NailLength.short,
                          onTap: () =>
                              setState(() => selectedLength = NailLength.short),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _LengthCard(
                          title: 'Medium',
                          subtitle: 'Classic length',
                          selected: selectedLength == NailLength.medium,
                          onTap: () => setState(
                            () => selectedLength = NailLength.medium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LengthCard(
                          title: 'Long',
                          subtitle: 'Extended length',
                          selected: selectedLength == NailLength.long,
                          onTap: () =>
                              setState(() => selectedLength = NailLength.long),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _LengthCard(
                          title: 'Extra Long',
                          subtitle: 'Statement length',
                          selected: selectedLength == NailLength.extraLong,
                          onTap: () => setState(
                            () => selectedLength = NailLength.extraLong,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 54,
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
          ],
        ),
      ),
    );
  }

  Widget _tipsBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.alabaster),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: SvgPicture.asset(
                  'assets/icons/tips.svg',
                  height: 18,
                  width: 18,
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                header: true,
                child: Text(
                  'Measurement Tips',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Measure the widest part of your nail bed',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
          ),
          Text(
            '• Round to the nearest 0.5mm (optional)',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
          ),
          Text(
            '• Left and right hands can be different',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
          ),
          Text(
            '• Each finger is unique — measure all 10',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.70)),
          ),
        ],
      ),
    );
  }
}

/// -------------------------------- UI pieces --------------------------------

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.55),
                height: 1.2,
              ),
            ),
          ],
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _FingerItemData {
  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  const _FingerItemData(this.label, this.controller, this.focusNode);
}

class _FingerRow extends StatelessWidget {
  const _FingerRow({
    required this.handLabel,
    required this.items,
    required this.inputDecoration,
  });

  final String handLabel;
  final List<_FingerItemData> items;
  final InputDecoration Function() inputDecoration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((f) {
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _FingerInput(
              semanticLabel: '$handLabel ${f.label} measurement',
              visualLabel: f.label,
              controller: f.controller,
              focusNode: f.focusNode,
              inputDecoration: inputDecoration,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FingerInput extends StatefulWidget {
  const _FingerInput({
    required this.semanticLabel,
    required this.visualLabel,
    required this.controller,
    required this.inputDecoration,
    this.focusNode,
  });

  final String semanticLabel;
  final String visualLabel;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final InputDecoration Function() inputDecoration;

  @override
  State<_FingerInput> createState() => _FingerInputState();
}

class _FingerInputState extends State<_FingerInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _FingerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text.trim();
    final semanticValue = value.isEmpty ? 'empty' : '$value millimeters';

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          ExcludeSemantics(
            child: Text(
              widget.visualLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 8),

          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.asset(
                'assets/images/nail_finger.png',
                height: 54,
                width: 54,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) {
                  return Container(
                    height: 54,
                    width: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 8),

          Semantics(
            textField: true,
            label: widget.semanticLabel,
            value: semanticValue,
            child: ExcludeSemantics(
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                decoration: widget.inputDecoration(),
                inputFormatters: <TextInputFormatter>[
                  NailDimensionTextInputFormatter(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(
              'mm',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.blackCat.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShapeCard extends StatelessWidget {
  const _ShapeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.blackCat.withValues(alpha: 0.10)
        : AppColors.snow;
    final border = selected
        ? AppColors.blackCat
        : AppColors.blackCat.withValues(alpha: 0.10);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label shape',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            width: 110,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: border, width: selected ? 1.6 : 1),
            ),
            child: Column(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: AppColors.blackCat.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: selected
                          ? AppColors.deepPlum
                          : AppColors.blackCat.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.front_hand_outlined,
                    color: selected
                        ? AppColors.blackCat
                        : AppColors.blackCat.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    color: AppColors.blackCat.withValues(alpha: 0.85),
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

class _LengthCard extends StatelessWidget {
  const _LengthCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.blackCat.withValues(alpha: 0.10)
        : AppColors.snow;
    final border = selected
        ? AppColors.blackCat
        : AppColors.blackCat.withValues(alpha: 0.10);

    return Semantics(
      button: true,
      selected: selected,
      label: '$title length. $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Container(
            height: 78,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: border, width: selected ? 1.6 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.blackCat.withValues(alpha: 0.60),
                    height: 1.15,
                    fontSize: 12.5,
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
