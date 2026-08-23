part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestDetailsTab on _CompletedRequestSheetState {
  List<Widget> _completedDetailsSectionItems() {
    return [
      Focus(
        key: const ValueKey('completedDetailsFocus'),
        focusNode: _detailsContentFocusNode,
        child: _descriptionAndCompanyBioSection(),
      ),
      const SizedBox(height: 12),
      if (_isBrandRequest(widget.request)) ...[
        _acceptedClientDetailsSection(widget.request),
        const SizedBox(height: 12),
      ],
      completedSoftBox(_measurementSection()),
    ];
  }
}
