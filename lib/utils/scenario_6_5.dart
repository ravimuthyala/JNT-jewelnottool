String scenario65ClientOrderStatusForViewer({
  required String viewerEmail,
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  final viewer = viewerEmail.trim().toLowerCase();
  final selected = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final accepted = acceptedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final declined = declinedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

  if (!selected.contains(viewer)) return 'hidden';
  if (declined.contains(viewer)) return 'declined';
  if (accepted.contains(viewer)) return 'pending';
  return 'pending';
}

List<String> scenario65ArtistVisibleClientEmails({
  required List<String> selectedGroupClientEmails,
  required List<String> acceptedGroupClientEmails,
  required List<String> declinedGroupClientEmails,
}) {
  final selected = selectedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final accepted = acceptedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
  final declined = declinedGroupClientEmails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();

  return selected
      .where((email) => accepted.contains(email) && !declined.contains(email))
      .toList(growable: false);
}
