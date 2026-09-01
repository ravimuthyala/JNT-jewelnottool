// ignore_for_file: invalid_use_of_protected_member

part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestShippingTab on _CompletedRequestSheetState {
  // Done should close the keyboard but leave VoiceOver/TalkBack right where
  // it was on the field. Every unfocus-based approach tried here -- bare
  // FocusManager.instance.primaryFocus?.unfocus(), a disposable-node blur,
  // even a disposable-node blur with delayed re-focus reasserts -- shares
  // the same flaw: blurring the field's own FocusNode at all drops that
  // field's semantics `isFocused` flag for at least one frame, and once
  // that happens iOS resolves VoiceOver's post-dismiss focus on its own
  // (observed landing on the Shipping Label section -- the first
  // accessible element on screen) before our reassert callback gets a
  // chance to run, regardless of delay length. There's no reliable window
  // to win that race.
  //
  // 'TextInput.hide' resigns the *native* first responder on iOS (that's
  // how the OS keyboard actually goes away), which is enough on its own to
  // trigger iOS's own native VoiceOver focus resolution -- landing on the
  // Shipping Label heading, the first accessible element in this tab --
  // independently of anything Flutter-side. No amount of Dart-side delay
  // tuning before *pushing* a reassert reliably outlasts that (confirmed:
  // flutter/flutter#36910 and #137235 are open/duplicated engine-level
  // reports of exactly this "requestFocus()/sendSemanticsEvent loses to
  // iOS's own post-keyboard VoiceOver resolution" class of bug -- every
  // timing variant tried here, up to and including waiting for the keyboard
  // inset to actually reach zero, still lost that race on a real device).
  //
  // So don't push -- catch. Arm _pendingTrackingFieldRefocusKey; whichever
  // plausible landing spot's onDidGainAccessibilityFocus fires (see
  // _handleTrackingRefocusTrapFocused) redirects to the real target,
  // re-firing on every hit since iOS can bounce through more than one wrong
  // spot before settling. Only the tracking field itself actually gaining
  // focus (_handleTrackingFieldSelfFocused) disarms it, confirming a
  // redirect stuck rather than assuming the first one did.
  //
  // The transient landing(s) -- even though redirected away from almost
  // immediately -- are still enough for Flutter to scroll them into view,
  // and the keyboard closing resizes the ListView's viewport on top of
  // that; together they produce a visible scroll/jump for something that
  // never actually needed to move. Hold the scroll offset for the duration
  // of the sequence so none of that is visible, then release it.
  void _keepFieldFocusAfterSubmit(GlobalKey fieldSemanticsKey) {
    _pendingTrackingFieldRefocusKey = fieldSemanticsKey;
    if (_listController.hasClients) {
      _heldShippingScrollOffset = _listController.offset;
      _listController.addListener(_holdShippingScrollOffset);
    }
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    // Restore only the screen-reader cursor after the native keyboard-dismiss
    // animation. Do not call FocusNode.requestFocus here: doing that can make
    // iOS and Android reopen the software keyboard immediately after Done.
    // The TextField keeps its existing Flutter focus because onEditingComplete
    // overrides TextField's default unfocus behavior.
    void restoreTrackingFocus() {
      if (!mounted) return;
      fieldSemanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => restoreTrackingFocus());
    Future<void>.delayed(
      const Duration(milliseconds: 250),
      restoreTrackingFocus,
    );
    Future<void>.delayed(
      const Duration(milliseconds: 650),
      restoreTrackingFocus,
    );
    // Safety: release the trap and the scroll hold after a couple of
    // seconds in case neither is ever triggered (e.g. VoiceOver wasn't
    // running), so a much later, unrelated swipe or scroll doesn't get
    // hijacked. Longer than a single-bounce window since a multi-hop
    // sequence needs time for each catch-and-redirect round trip.
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      _listController.removeListener(_holdShippingScrollOffset);
      _heldShippingScrollOffset = null;
      if (_pendingTrackingFieldRefocusKey == fieldSemanticsKey) {
        _pendingTrackingFieldRefocusKey = null;
      }
    });
  }

  Future<void> _openCourierMenu(
    BuildContext context,
    FocusNode focusNode,
    GlobalKey fieldKey,
  ) => _openCourierMenuFor(
    context,
    focusNode,
    fieldKey,
    _courier,
    (value) => setState(() => _courier = value),
  );

  Future<void> _openCourierMenuFor(
    BuildContext context,
    FocusNode focusNode,
    GlobalKey fieldKey,
    String? currentValue,
    ValueChanged<String> onSelected,
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
            firstItemKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
              const FocusSemanticEvent(),
            );
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
                      selected: currentValue == _couriers[i],
                      label: '${_couriers[i]} courier',
                      value: currentValue == _couriers[i]
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
                    if (i < _couriers.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      onSelected(selected);
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      fieldKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
        const FocusSemanticEvent(),
      );
    });
  }

  Widget _courierField(BuildContext context) {
    final fieldKey = _courierSemanticsKey;
    final displayText = (_courier ?? '').trim();
    final hasValue = displayText.isNotEmpty;

    return Focus(
      focusNode: _courierFocusNode,
      child: Semantics(
        key: fieldKey,
        button: true,
        label: 'Courier',
        value: hasValue ? displayText : 'Not selected',
        hint: 'Double tap to open the courier list',
        onTap: () => _openCourierMenu(context, _courierFocusNode, fieldKey),
        onDidGainAccessibilityFocus: _handleTrackingRefocusTrapFocused,
        child: ExcludeSemantics(
          child: InkWell(
            borderRadius: BorderRadius.zero,
            onTap: () => _openCourierMenu(context, _courierFocusNode, fieldKey),
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
      ),
    );
  }

  Widget _recipientCourierField(
    BuildContext context,
    _ShipmentRecipient recipient,
  ) {
    final focusNode = _courierFocusNodeFor(recipient.key);
    final fieldKey = _courierSemanticsKeyFor(recipient.key);
    final enabled = recipient.hasAddress;
    final displayText = (_recipientCouriers[recipient.key] ?? '').trim();
    final hasValue = displayText.isNotEmpty;
    final opacity = enabled ? 1.0 : 0.45;

    return Focus(
      focusNode: focusNode,
      child: Semantics(
        key: fieldKey,
        button: true,
        enabled: enabled,
        label: '${recipient.name} courier',
        value: hasValue ? displayText : 'Not selected',
        hint: enabled
            ? 'Double tap to open the courier list'
            : 'Add a shipping address for this recipient first',
        onTap: enabled
            ? () => _openCourierMenuFor(
                context,
                focusNode,
                fieldKey,
                _recipientCouriers[recipient.key],
                (value) =>
                    setState(() => _recipientCouriers[recipient.key] = value),
              )
            : null,
        onDidGainAccessibilityFocus: _handleTrackingRefocusTrapFocused,
        child: ExcludeSemantics(
          child: Opacity(
            opacity: opacity,
            child: InkWell(
              borderRadius: BorderRadius.zero,
              onTap: enabled
                  ? () => _openCourierMenuFor(
                      context,
                      focusNode,
                      fieldKey,
                      _recipientCouriers[recipient.key],
                      (value) => setState(
                        () => _recipientCouriers[recipient.key] = value,
                      ),
                    )
                  : null,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: AppColors.blackCat.withValues(alpha: 0.72),
                      size: 20,
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

  Widget _fieldSectionLabel(String text) => ExcludeSemantics(
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.blackCat,
        fontWeight: FontWeight.w400,
        fontSize: 14,
      ),
    ),
  );

  Widget _shippedDateField(String shippedDateValue) {
    return Focus(
      focusNode: _shippedDateFocusNode,
      child: Semantics(
        key: _shippedDateSemanticsKey,
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
    );
  }

  Widget _markShippedButton(Future<void> Function() onSubmit) {
    return Center(
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
                disabledBackgroundColor: AppColors.blackCat.withValues(
                  alpha: 0.18,
                ),
                foregroundColor: AppColors.snow,
                disabledForegroundColor: AppColors.snow.withValues(alpha: 0.78),
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
                        await onSubmit();
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
    );
  }

  Widget _recipientShipmentCard(_ShipmentRecipient recipient) {
    return Container(
      key: ValueKey('recipientShipmentCard-${recipient.key}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: AppColors.blackCat.withValues(alpha: 0.04),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    recipient.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blackCat,
                    ),
                  ),
                ),
                Text(
                  recipient.tag,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              recipient.hasAddress
                  ? recipient.addressLabel
                  : 'No shipping address on file',
              style: TextStyle(
                fontSize: 11,
                fontWeight: recipient.hasAddress
                    ? FontWeight.w400
                    : FontWeight.w700,
                color: recipient.hasAddress
                    ? AppColors.blackCat.withValues(alpha: 0.60)
                    : const Color(0xFFA64B3C),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Courier',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                _recipientCourierField(context, recipient),
                const SizedBox(height: 8),
                Text(
                  'Tracking #',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: recipient.hasAddress ? 1.0 : 0.45,
                  child: Semantics(
                    key: _trackingSemanticsKeyFor(recipient.key),
                    textField: true,
                    enabled: recipient.hasAddress,
                    label: '${recipient.name} tracking number',
                    hint: recipient.hasAddress
                        ? null
                        : 'Add a shipping address for this recipient first',
                    onDidGainAccessibilityFocus:
                        _handleTrackingFieldSelfFocused,
                    child: TextField(
                      controller: _trackingCtrlFor(recipient.key),
                      focusNode: _trackingFocusNodeFor(recipient.key),
                      enabled: recipient.hasAddress,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      // Without a custom onEditingComplete, TextField runs
                      // its own default unfocus() for TextInputAction.done
                      // BEFORE onSubmitted even fires -- that unfocus is
                      // what kicks off iOS's native VoiceOver focus
                      // resolution (landing on Shipping Label) ahead of
                      // any reassert we could ever fire from onSubmitted.
                      // Overriding onEditingComplete suppresses that
                      // default, so _keepFieldFocusAfterSubmit is the only
                      // thing that runs the close/reassert sequence.
                      onEditingComplete: () => _keepFieldFocusAfterSubmit(
                        _trackingSemanticsKeyFor(recipient.key),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 12.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter tracking number',
                        hintStyle: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12.5,
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
                          horizontal: 10,
                          vertical: 13,
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
    );
  }

  Widget _respectiveClientShippingSection(String shippedDateValue) {
    final recipients = _shipmentRecipients;
    final missingAddress = recipients.where((r) => !r.hasAddress).toList();

    return completedSoftBox(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            color: AppColors.balletSlippers,
            child: Text(
              'CLIENT REQUESTED: SHIP TO EACH GROUP MEMBER INDIVIDUALLY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: AppColors.blackCat,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            label: 'Shipping Details, ${recipients.length} recipients',
            child: ExcludeSemantics(
              child: completedSectionTitle(
                'Shipping Details — ${recipients.length} recipients',
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final recipient in recipients) _recipientShipmentCard(recipient),
          _fieldSectionLabel('Shipped Date (shared)'),
          const SizedBox(height: 8),
          _shippedDateField(shippedDateValue),
          const SizedBox(height: 20),
          _markShippedButton(() async {
            final entries = [
              for (final recipient in recipients)
                ShipmentRecipientEntry(
                  clientId: recipient.key == 'self' ? '' : recipient.key,
                  clientName: recipient.name,
                  clientEmail: recipient.email,
                  courier: (_recipientCouriers[recipient.key] ?? '').trim(),
                  tracking: _trackingCtrlFor(recipient.key).text.trim(),
                ),
            ];
            await widget.onMarkShipped(
              mode: GroupShippingMode.toRespectiveClient,
              shippedDate: _shippedDate!,
              recipients: entries,
            );
          }),
          if (missingAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Missing address for ${missingAddress.map((r) => r.name).join(', ')} — resolve before shipping.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFFA64B3C)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _completedShippingSectionItems() {
    final shippedDateValue = _shippedDate == null
        ? 'Not selected'
        : '${_shippedDate!.month}/${_shippedDate!.day}/${_shippedDate!.year}';
    final isRespective = _isRespectiveShippingMode;

    return [
      Focus(
        key: const ValueKey('completedShippingFocus'),
        focusNode: _shippingContentFocusNode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: isRespective
              ? [
                  completedSoftBox(_shippingLabelSection()),
                  const SizedBox(height: 12),
                  _respectiveClientShippingSection(shippedDateValue),
                ]
              : [
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
                        _fieldSectionLabel('Shipped by'),
                        const SizedBox(height: 8),
                        _courierField(context),
                        const SizedBox(height: 12),
                        _fieldSectionLabel('Tracking #'),
                        const SizedBox(height: 8),
                        Semantics(
                          key: _trackingSemanticsKey,
                          textField: true,
                          label: 'Tracking number',
                          onDidGainAccessibilityFocus:
                              _handleTrackingFieldSelfFocused,
                          child: TextField(
                            controller: _trackingCtrl,
                            focusNode: _trackingFocusNode,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => setState(() {}),
                            onEditingComplete: () => _keepFieldFocusAfterSubmit(
                              _trackingSemanticsKey,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Tracking number',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.never,
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
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.zero,
                                borderSide: BorderSide(
                                  color: AppColors.blackCat,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fieldSectionLabel('Shipped Date'),
                        const SizedBox(height: 8),
                        _shippedDateField(shippedDateValue),
                        const SizedBox(height: 20),
                        _markShippedButton(() async {
                          await widget.onMarkShipped(
                            mode: GroupShippingMode.toMyself,
                            courier: _courier!.trim(),
                            tracking: _trackingCtrl.text.trim(),
                            shippedDate: _shippedDate!,
                          );
                        }),
                      ],
                    ),
                  ),
                ],
        ),
      ),
    ];
  }
}
