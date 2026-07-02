// ignore_for_file: invalid_use_of_protected_member

part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestShippingTab on _CompletedRequestSheetState {
  Future<void> _openCourierMenu(
    BuildContext context,
    GlobalKey fieldKey,
  ) async {
    final fieldContext = fieldKey.currentContext;
    if (fieldContext == null) return;
    final fieldBox = fieldContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (fieldBox == null || overlayBox == null) return;

    final topLeft = fieldBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomLeft = fieldBox.localToGlobal(
      Offset(0, fieldBox.size.height),
      ancestor: overlayBox,
    );

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.snow,
      surfaceTintColor: AppColors.snow,
      elevation: 8,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomLeft.dy + 4,
        overlayBox.size.width - topLeft.dx - fieldBox.size.width,
        overlayBox.size.height - bottomLeft.dy,
      ),
      items: _couriers
          .map(
            (c) => PopupMenuItem<String>(
              value: c,
              height: 44,
              child: Text(
                c,
                style: const TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );

    if (selected != null && mounted) {
      setState(() => _courier = selected);
    }
  }

  Widget _courierField(BuildContext context) {
    final fieldKey = GlobalKey();
    final displayText = (_courier ?? '').trim();
    final hasValue = displayText.isNotEmpty;

    return InkWell(
      key: fieldKey,
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
    );
  }

  Widget _completedShippingTab(BuildContext context, double bottomInset) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16 + math.max(0, bottomInset),
      ),
      children: [
        _topHeroCentered(context, widget.request, widget.onClose),
        const SizedBox(height: 12),
        _completedStatusBanner(),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 12),
        _completedTabsBar(),
        const SizedBox(height: 12),
        completedSoftBox(_shippingLabelSection()),
        const SizedBox(height: 12),
        completedSoftBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              completedSectionTitle('Shipping Details'),
              const SizedBox(height: 10),
              Text(
                'Shipped by',
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              _courierField(context),
              const SizedBox(height: 12),
              Text(
                'Tracking #',
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _trackingCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
                decoration: InputDecoration(
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
              Text(
                'Shipped Date',
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
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
                              : '${_shippedDate!.month}/${_shippedDate!.day}/${_shippedDate!.year}',
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
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 188,
                height: 52,
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
            ],
          ),
        ),
      ],
    );
  }
}
