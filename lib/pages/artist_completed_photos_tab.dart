part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestPhotosTab on _CompletedRequestSheetState {
  Widget _completedPhotosTab(BuildContext context, double bottomInset) {
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
        completedSoftBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              completedSectionTitle('Uploaded Photos (Client)'),
              const SizedBox(height: 10),
              if (widget.request.clientImages.isEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: AppColors.blackCat.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No images uploaded',
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                _photosGrid(widget.request.clientImages),
            ],
          ),
        ),
        const SizedBox(height: 14),
        completedSoftBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              completedSectionTitle('Uploaded Photos (Artist)'),
              const SizedBox(height: 10),
              if (widget.request.artistImages.isEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: AppColors.blackCat.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'No artist photos uploaded',
                      style: TextStyle(
                        color: AppColors.blackCat.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                _photosGrid(widget.request.artistImages),
            ],
          ),
        ),
      ],
    );
  }
}
