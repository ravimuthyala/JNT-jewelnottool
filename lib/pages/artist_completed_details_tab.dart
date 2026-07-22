part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestDetailsTab on _CompletedRequestSheetState {
  Widget _completedDetailsTab(BuildContext context, double bottomInset) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
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
        _descriptionAndCompanyBioSection(),
        const SizedBox(height: 12),
        if (_isBrandRequest(widget.request)) ...[
          _acceptedClientDetailsSection(widget.request),
          const SizedBox(height: 12),
        ],
        completedSoftBox(_measurementSection()),
        const SizedBox(height: 12),
      ],
    );
  }
}
