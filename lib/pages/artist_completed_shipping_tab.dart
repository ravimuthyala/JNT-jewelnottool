// ignore_for_file: invalid_use_of_protected_member

part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestShippingTab on _CompletedRequestSheetState {
  Future<void> _openCourierMenu(
    BuildContext context,
    GlobalKey fieldKey,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final firstItemKey = GlobalKey();
    var initialFocusRequested = false;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        if (!initialFocusRequested && _accessibleNavigation(sheetContext)) {
          initialFocusRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            firstItemKey.currentContext
                ?.findRenderObject()
                ?.sendSemanticsEvent(const FocusSemanticEvent());
          });
        }
        return Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: 'Select courier',
          child: Container(
            color: AppColors.snow,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    label: 'Select courier',
                    child: const ExcludeSemantics(
                      child: Text(
                        'Select courier',
                        style: TextStyle(
                          color: AppColors.blackCat,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _couriers.length; i++) ...[
                    Semantics(
                      key: i == 0 ? firstItemKey : null,
                      button: true,
                      selected: _courier == _couriers[i],
                      label: '${_couriers[i]} courier',
                      value: _courier == _couriers[i]
                          ? 'Currently selected'
                          : 'Not selected',
                      onTap: () => Navigator.pop(sheetContext, _couriers[i]),
                      child: ExcludeSemantics(
                        child: InkWell(
                          onTap: () =>
                              Navigator.pop(sheetContext, _couriers[i]),
                          child: SizedBox(
                            height: 52,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _couriers[i],
                                style: const TextStyle(
                                  color: AppColors.blackCat,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i < _couriers.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _courier = selected);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fieldKey.currentContext
          ?.findRenderObject()
          ?.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  Widget _courierField(BuildContext context) {
    final fieldKey = GlobalKey();
    final displayText = (_courier ?? '').trim();
    final hasValue = displayText.isNotEmpty;

    return Semantics(
      key: fieldKey,
      button: true,
      label: 'Courier',
      value: hasValue ? displayText : 'Not selected',
      hint: 'Double tap to open the courier list',
      onTap: () => _openCourierMenu(context, fieldKey),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () => _openCourierMenu(context, fieldKey),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.snow,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: AppColors.blackCat.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? displayText : 'Select courier',
                    style: TextStyle(
                      color: hasValue
                          ? AppColors.blackCat
                          : AppColors.blackCat.withValues(alpha: 0.60),
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.blackCat.withValues(alpha: 0.72),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _completedShippingTab(BuildContext context, double bottomInset) {
    final shippedDateValue = _shippedDate == null
        ? 'Not selected'
        : '${_shippedDate!.month}/${_shippedDate!.day}/${_shippedDate!.year}';

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16,
      ),
      child: Focus(
        focusNode: _shippingContentFocusNode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        completedSoftBox(_shippingLabelSection()),
        const SizedBox(height: 12),
        completedSoftBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: 'Shipping Details',
                child: ExcludeSemantics(
                  child: completedSectionTitle('Shipping Details'),
                ),
              ),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: Text(
                  'Shipped by',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _courierField(context),
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: Text(
                  'Tracking #',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _trackingCtrl,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  labelText: 'Tracking number',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  hintText: 'Enter tracking number',
                  hintStyle: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.snow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withValues(alpha: 0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.blackCat),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: Text(
                  'Shipped Date',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Shipped date',
                value: shippedDateValue,
                hint: _shippedDate == null
                    ? 'Double tap to select a date'
                    : 'Double tap to change the date',
                onTap: _pickShippedDate,
                child: ExcludeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.zero,
                    onTap: _pickShippedDate,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.snow,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppColors.blackCat.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _shippedDate == null
                                  ? 'Select shipped date'
                                  : shippedDateValue,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 13.5,
                                color: _shippedDate == null
                                    ? AppColors.blackCat.withValues(alpha: 0.45)
                                    : AppColors.blackCat.withValues(alpha: 0.90),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: AppColors.blackCat.withValues(alpha: 0.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: 188,
                  height: 52,
                  child: Semantics(
                    button: true,
                    enabled: _isValid && !_submitting,
                    label: _submitting ? 'Updating shipping status' : 'Mark as Shipped',
                    child: ExcludeSemantics(
                      child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      disabledBackgroundColor:
                          AppColors.blackCat.withValues(alpha: 0.18),
                      foregroundColor: AppColors.snow,
                      disabledForegroundColor:
                          AppColors.snow.withValues(alpha: 0.78),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                    ),
                    onPressed: (!_isValid || _submitting)
                        ? null
                        : () async {
                            setState(() => _submitting = true);
                            try {
                              await widget.onMarkShipped(
                                courier: _courier!.trim(),
                                tracking: _trackingCtrl.text.trim(),
                                shippedDate: _shippedDate!,
                              );
                              if (mounted) Navigator.pop(context);
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
                          },
                    child: Text(
                      _submitting ? 'Updating...' : 'Mark as Shipped',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        fontFamily: 'Arial',
                        color: AppColors.snow,
                      ),
                    ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
