part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestPhotosTab on _CompletedRequestSheetState {
  Widget _completedPhotosTab(BuildContext context, double bottomInset) {
    final clientPhotos = widget.request.clientImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final artistPhotos = widget.request.artistImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + math.max(0.0, bottomInset),
      ),
      children: [
        Focus(
          focusNode: clientPhotos.isEmpty ? _photosContentFocusNode : null,
          child: Semantics(
            container: true,
            label: clientPhotos.isEmpty
                ? 'Uploaded photos, client. No images uploaded.'
                : 'Uploaded photos, client',
            child: ExcludeSemantics(
              child: completedSoftBox(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    completedSectionTitle('Uploaded Photos (Client)'),
                    const SizedBox(height: 10),
                    if (clientPhotos.isEmpty)
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
                      _photosGrid(
                        clientPhotos,
                        ownerLabel: 'Client',
                        firstItemFocusNode: _photosContentFocusNode,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          container: true,
          label: artistPhotos.isEmpty
              ? 'Uploaded photos, artist. No artist photos uploaded.'
              : 'Uploaded photos, artist',
          child: ExcludeSemantics(
            child: completedSoftBox(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  completedSectionTitle('Uploaded Photos (Artist)'),
                  const SizedBox(height: 10),
                  if (artistPhotos.isEmpty)
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
                    _photosGrid(
                      artistPhotos,
                      ownerLabel: 'Artist',
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
