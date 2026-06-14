import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum ClientArtistPreferredContactMethod { email, push, sms }

class ClientArtistCommunicationPreferences {
  const ClientArtistCommunicationPreferences({
    required this.emailNotifications,
    required this.smsNotifications,
    required this.pushNotifications,
    required this.accountActivity,
    required this.securityAlerts,
    required this.promotionsOffers,
    required this.reminders,
    required this.newsUpdates,
    required this.preferredContact,
    required this.marketingConsent,
  });

  final bool emailNotifications;
  final bool smsNotifications;
  final bool pushNotifications;
  final bool accountActivity;
  final bool securityAlerts;
  final bool promotionsOffers;
  final bool reminders;
  final bool newsUpdates;
  final ClientArtistPreferredContactMethod preferredContact;
  final bool marketingConsent;

  factory ClientArtistCommunicationPreferences.defaults() {
    return const ClientArtistCommunicationPreferences(
      emailNotifications: true,
      smsNotifications: false,
      pushNotifications: true,
      accountActivity: true,
      securityAlerts: true,
      promotionsOffers: false,
      reminders: true,
      newsUpdates: true,
      preferredContact: ClientArtistPreferredContactMethod.sms,
      marketingConsent: true,
    );
  }

  factory ClientArtistCommunicationPreferences.fromMap(
    Map<String, dynamic> map,
  ) {
    ClientArtistPreferredContactMethod parsePreferred(dynamic raw) {
      switch ((raw ?? '').toString().trim()) {
        case 'email':
          return ClientArtistPreferredContactMethod.email;
        case 'push':
          return ClientArtistPreferredContactMethod.push;
        case 'sms':
        default:
          return ClientArtistPreferredContactMethod.sms;
      }
    }

    bool asBool(dynamic raw, bool fallback) {
      if (raw is bool) return raw;
      if (raw is num) return raw != 0;
      final text = (raw ?? '').toString().trim().toLowerCase();
      if (text == 'true') return true;
      if (text == 'false') return false;
      return fallback;
    }

    final defaults = ClientArtistCommunicationPreferences.defaults();
    return ClientArtistCommunicationPreferences(
      emailNotifications: asBool(
        map['emailNotifications'],
        defaults.emailNotifications,
      ),
      smsNotifications: asBool(
        map['smsNotifications'],
        defaults.smsNotifications,
      ),
      pushNotifications: asBool(
        map['pushNotifications'],
        defaults.pushNotifications,
      ),
      accountActivity: asBool(map['accountActivity'], defaults.accountActivity),
      securityAlerts: asBool(map['securityAlerts'], defaults.securityAlerts),
      promotionsOffers: asBool(
        map['promotionsOffers'],
        defaults.promotionsOffers,
      ),
      reminders: asBool(map['reminders'], defaults.reminders),
      newsUpdates: asBool(map['newsUpdates'], defaults.newsUpdates),
      preferredContact: parsePreferred(map['preferredContact']),
      marketingConsent: asBool(
        map['marketingConsent'],
        defaults.marketingConsent,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emailNotifications': emailNotifications,
      'smsNotifications': smsNotifications,
      'pushNotifications': pushNotifications,
      'accountActivity': accountActivity,
      'securityAlerts': securityAlerts,
      'promotionsOffers': promotionsOffers,
      'reminders': reminders,
      'newsUpdates': newsUpdates,
      'preferredContact': preferredContact.name,
      'marketingConsent': marketingConsent,
    };
  }
}

class ClientArtistCommunicationPreferencePopup extends StatefulWidget {
  const ClientArtistCommunicationPreferencePopup({
    super.key,
    required this.initialValue,
  });

  final ClientArtistCommunicationPreferences initialValue;

  @override
  State<ClientArtistCommunicationPreferencePopup> createState() =>
      _ClientArtistCommunicationPreferencePopupState();
}

class _ClientArtistCommunicationPreferencePopupState
    extends State<ClientArtistCommunicationPreferencePopup> {
  static const double _sectionTitleFs = 14.5;

  late bool _emailNotifications;
  bool _smsNotifications = false;
  late bool _pushNotifications;
  bool _accountActivity = true;
  bool _securityAlerts = true;
  bool _promotionsOffers = false;
  bool _reminders = true;
  bool _newsUpdates = true;
  ClientArtistPreferredContactMethod _preferredContact =
      ClientArtistPreferredContactMethod.sms;
  bool _marketingConsent = true;

  final FocusNode _emailNotificationsFocusNode = FocusNode(
    debugLabel: 'emailNotificationsSwitch',
  );

  @override
  void initState() {
    super.initState();
    _emailNotifications = widget.initialValue.emailNotifications;
    _smsNotifications = widget.initialValue.smsNotifications;
    _pushNotifications = widget.initialValue.pushNotifications;
    _accountActivity = widget.initialValue.accountActivity;
    _securityAlerts = widget.initialValue.securityAlerts;
    _promotionsOffers = widget.initialValue.promotionsOffers;
    _reminders = widget.initialValue.reminders;
    _newsUpdates = widget.initialValue.newsUpdates;
    _preferredContact = widget.initialValue.preferredContact;
    _marketingConsent = widget.initialValue.marketingConsent;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_isAccessibilityNavigationEnabled(context)) return;

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted || !_isAccessibilityNavigationEnabled(context)) return;

      _emailNotificationsFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _emailNotificationsFocusNode.dispose();
    super.dispose();
  }

  bool _isAccessibilityNavigationEnabled(BuildContext context) {
    final mqValue = MediaQuery.maybeOf(context)?.accessibleNavigation;
    final platformValue = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.accessibleNavigation;
    return mqValue ?? platformValue;
  }

  void _close() {
    Navigator.pop(context);
  }

  void _save() {
    Navigator.pop(context, _currentPreferences);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Communication Preferences',
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.only(bottom: bottom),
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            height: 4,
                            width: 44,
                            decoration: BoxDecoration(
                              color: AppColors.blackCat,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const SizedBox(width: 48),
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  'Communication Preferences',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.blackCat,
                                    fontFamily: 'Arialbold',
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close communication preferences',
                              icon: Icon(
                                Icons.close_rounded,
                                size: 22,
                                color: AppColors.blackCat.withOpacity(0.75),
                              ),
                              onPressed: _close,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        _sectionCard(
                          title: 'Communication Channels',
                          child: Column(
                            children: [
                              _channelTile(
                                icon: Icons.mail_outline_rounded,
                                title: 'Email Notifications',
                                value: _emailNotifications,
                                focusNode: _emailNotificationsFocusNode,
                                onChanged: (value) =>
                                    setState(() => _emailNotifications = value),
                              ),
                              _divider(),
                              _channelTile(
                                icon: Icons.sms_outlined,
                                title: 'SMS Notifications',
                                value: _smsNotifications,
                                onChanged: (value) =>
                                    setState(() => _smsNotifications = value),
                              ),
                              _divider(),
                              _channelTile(
                                icon: Icons.notifications_none_rounded,
                                title: 'Push Notifications',
                                value: _pushNotifications,
                                onChanged: (value) =>
                                    setState(() => _pushNotifications = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Notification Types',
                          child: Column(
                            children: [
                              _checkboxTile(
                                icon: Icons.person_outline_rounded,
                                title: 'Account Activity',
                                value: _accountActivity,
                                onChanged: (value) =>
                                    setState(() => _accountActivity = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.shield_outlined,
                                title: 'Security Alerts',
                                value: _securityAlerts,
                                onChanged: (value) =>
                                    setState(() => _securityAlerts = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.local_offer_outlined,
                                title: 'Promotions & Offers',
                                value: _promotionsOffers,
                                onChanged: (value) =>
                                    setState(() => _promotionsOffers = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.calendar_today_outlined,
                                title: 'Reminders',
                                value: _reminders,
                                onChanged: (value) =>
                                    setState(() => _reminders = value),
                              ),
                              _divider(),
                              _checkboxTile(
                                icon: Icons.campaign_outlined,
                                title: 'News & Updates',
                                value: _newsUpdates,
                                onChanged: (value) =>
                                    setState(() => _newsUpdates = value),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'Preferred Contact Method',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _radioOption(
                                      label: 'Email',
                                      value: ClientArtistPreferredContactMethod.email,
                                    ),
                                  ),
                                  Expanded(
                                    child: _radioOption(
                                      label: 'Push',
                                      value: ClientArtistPreferredContactMethod.push,
                                    ),
                                  ),
                                  Expanded(
                                    child: _radioOption(
                                      label: 'SMS',
                                      value: ClientArtistPreferredContactMethod.sms,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _divider(),
                              const SizedBox(height: 10),
                              _marketingConsentTile(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.blackCat,
                                foregroundColor: AppColors.snow,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              onPressed: _save,
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
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
            ),
          ),
        ),
      ),
    );
  }

  ClientArtistCommunicationPreferences get _currentPreferences =>
      ClientArtistCommunicationPreferences(
        emailNotifications: _emailNotifications,
        smsNotifications: _smsNotifications,
        pushNotifications: _pushNotifications,
        accountActivity: _accountActivity,
        securityAlerts: _securityAlerts,
        promotionsOffers: _promotionsOffers,
        reminders: _reminders,
        newsUpdates: _newsUpdates,
        preferredContact: _preferredContact,
        marketingConsent: _marketingConsent,
      );

  Widget _sectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: _sectionTitleFs,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const ExcludeSemantics(
          child: Divider(height: 1, color: AppColors.blackCatBorderLight),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _channelTile({
    required IconData icon,
    required String title,
    required bool value,
    FocusNode? focusNode,
    required ValueChanged<bool> onChanged,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: title,
        toggled: value,
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 22, color: AppColors.blackCat),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blackCat,
                    fontFamily: 'Arialbold',
                  ),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                focusNode: focusNode,
                value: value,
                activeThumbColor: AppColors.blackCat,
                inactiveThumbColor: AppColors.blackCatLight,
                inactiveTrackColor: AppColors.blackCatLight.withOpacity(0.35),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkboxTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: title,
        checked: value,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.zero,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 22, color: AppColors.blackCat),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.blackCat,
                      fontFamily: 'Arialbold',
                    ),
                  ),
                ),
              ),
              Checkbox(
                value: value,
                activeColor: AppColors.blackCat,
                onChanged: (next) => onChanged(next ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radioOption({
    required String label,
    required ClientArtistPreferredContactMethod value,
  }) {
    return MergeSemantics(
      child: Semantics(
        label: '$label contact method',
        checked: _preferredContact == value,
        inMutuallyExclusiveGroup: true,
        child: InkWell(
          onTap: () => setState(() => _preferredContact = value),
          borderRadius: BorderRadius.zero,
          child: Row(
            children: [
              Radio<ClientArtistPreferredContactMethod>(
                value: value,
                groupValue: _preferredContact,
                activeColor: AppColors.blackCat,
                onChanged: (next) {
                  if (next != null) {
                    setState(() => _preferredContact = next);
                  }
                },
              ),
              Flexible(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.blackCat,
                      fontFamily: 'Arialbold',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _marketingConsentTile() {
    return MergeSemantics(
      child: Semantics(
        label: 'I agree to receive marketing communications.',
        checked: _marketingConsent,
        child: InkWell(
          onTap: () => setState(() => _marketingConsent = !_marketingConsent),
          borderRadius: BorderRadius.zero,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _marketingConsent,
                activeColor: AppColors.blackCat,
                onChanged: (value) =>
                    setState(() => _marketingConsent = value ?? false),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: ExcludeSemantics(
                    child: Text(
                      'I agree to receive marketing communications.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.blackCat,
                        fontFamily: 'Arialbold',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => ExcludeSemantics(
        child: Divider(height: 18, color: AppColors.blackCat.withOpacity(0.35)),
      );
}
