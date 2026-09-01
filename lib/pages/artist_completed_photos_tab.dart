part of 'artist_completed_request_sheet.dart';

extension _CompletedRequestPhotosTab on _CompletedRequestSheetState {
  List<Widget> _completedPhotosSectionItems() {
    final clientPhotos = widget.request.clientImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final artistPhotos = widget.request.artistImages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return [
      Focus(
        key: const ValueKey('completedPhotosClientFocus'),
        focusNode: clientPhotos.isEmpty ? _photosContentFocusNode : null,
        child: completedSoftBox(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The heading carries a merged label (folding in the
              // "no images" state when empty); the grid below is left OUT
              // of any ExcludeSemantics wrapper so each photo keeps its own
              // reachable, swipe-to, double-tap-to-open Semantics node --
              // wrapping the whole section (heading + grid) in one
              // ExcludeSemantics, as before, silently dropped every photo's
              // semantics along with it, making them unreachable.
              Semantics(
                header: true,
                label: clientPhotos.isEmpty
                    ? 'Uploaded photos, client. No images uploaded.'
                    : 'Uploaded photos, client',
                child: ExcludeSemantics(
                  child: completedSectionTitle('Uploaded Photos (Client)'),
                ),
              ),
              const SizedBox(height: 10),
              if (clientPhotos.isEmpty)
                ExcludeSemantics(
                  child: Row(
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
                  ),
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
      const SizedBox(height: 14),
      completedSoftBox(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              label: artistPhotos.isEmpty
                  ? 'Uploaded photos, artist. No artist photos uploaded.'
                  : 'Uploaded photos, artist',
              child: ExcludeSemantics(
                child: completedSectionTitle('Uploaded Photos (Artist)'),
              ),
            ),
            const SizedBox(height: 10),
            if (artistPhotos.isEmpty)
              ExcludeSemantics(
                child: Row(
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
                ),
              )
            else
              _photosGrid(artistPhotos, ownerLabel: 'Artist'),
          ],
        ),
      ),
    ];
  }
}
