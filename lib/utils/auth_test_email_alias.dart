// QA aliasing is disabled. Keep these helpers stable for call sites.
bool isMultiUseTestEmail(String email) => false;

String authEmailForCreate(String email) {
  return email.trim().toLowerCase();
}
