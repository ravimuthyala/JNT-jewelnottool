import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import 'artist_accepted_request_sheet.dart';

Future<void> showArtistDesigningRequestSheet({
  required BuildContext context,
  required ClientRequestV2 request,
  required int shipDays,
  required VoidCallback onClose,
  required Future<void> Function(bool completed, List<String> artistPhotos)
  onMarkCompleted,
}) {
  // Uses the same full UI/sections as Accepted sheet, but in Designing mode.
  return showDesigningRequestSheet(
    context: context,
    request: request,
    shipDays: shipDays,
    onClose: onClose,
    onMarkCompleted: onMarkCompleted,
  );
}
