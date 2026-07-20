// lib/pages/artist_calendar_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';

// âœ… reuse your existing model WITHOUT changing that file
import '../models/artist_request_legacy_models.dart'
    show ClientRequest, NailDimensions, RequestStatus;
import '../utlis/responsive_text.dart';
import 'artist_profile_page.dart';
import 'notifications_page.dart';
import '../widgets/artist_profile_avatar_icon.dart';
import '../widgets/jnt_standard_app_bar.dart';

class ArtistCalendarPage extends StatefulWidget {
  const ArtistCalendarPage({
    super.key,
    required this.requests,
    this.onOpenNotifications,
    this.onOpenProfile,
    this.onManageProfile,
    this.onOpenInbox,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenArtist,
    this.onOpenReviews,
    this.onOpenEarnings,
    this.onSignOut,
    this.showExtendedAvatarMenu = false,
    this.hideHistoryMenuItem = false,
    this.hideCalendarMenuItem = false,
    this.showBottomNav = false,
    this.bottomNavIndex = 3,
    this.onNavTap,
    this.enableSupabaseAutoload = true,
  });

  final List<ClientRequest> requests;
  final VoidCallback? onOpenNotifications;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onManageProfile;
  final VoidCallback? onOpenInbox;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onSignOut;
  final bool showExtendedAvatarMenu;
  final bool hideHistoryMenuItem;
  final bool hideCalendarMenuItem;
  final bool showBottomNav;
  final int bottomNavIndex;
  final ValueChanged<int>? onNavTap;
  final bool enableSupabaseAutoload;

  @override
  State<ArtistCalendarPage> createState() => _ArtistCalendarPageState();
}

class _ArtistCalendarPageState extends State<ArtistCalendarPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  DateTime _focusedMonth = _startOfMonth(DateTime.now());
  DateTime _selectedDay = _dateOnly(DateTime.now());
  List<ClientRequest> _supabaseRequests = const <ClientRequest>[];
  StreamSubscription<List<Map<String, dynamic>>>? _calendarSub;
  bool _loadingSupabaseRequests = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (widget.enableSupabaseAutoload) {
      unawaited(_loadCalendarRequestsFromSupabase());
      _listenCalendarRequestsFromSupabase();
    }
  }

  @override
  void dispose() {
    _calendarSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  List<ClientRequest> get _calendarRequests {
    if (_supabaseRequests.isEmpty) return widget.requests;
    if (widget.requests.isEmpty) return _supabaseRequests;

    final byId = <String, ClientRequest>{};
    for (final request in widget.requests) {
      byId[request.id] = request;
    }
    for (final request in _supabaseRequests) {
      byId[request.id] = request;
    }
    return byId.values.toList(growable: false);
  }

  Future<void> _loadCalendarRequestsFromSupabase() async {
    if (_loadingSupabaseRequests) return;
    _loadingSupabaseRequests = true;
    try {
      final rows = await _fetchCalendarRequestRowsFromSupabase();
      final mapped = rows
          .map(_requestFromSupabaseRow)
          .whereType<ClientRequest>()
          .toList(growable: false);

      if (!mounted) return;
      setState(() => _supabaseRequests = mapped);
    } catch (e) {
      debugPrint('ARTIST CALENDAR LOAD FAILED: $e');
    } finally {
      _loadingSupabaseRequests = false;
    }
  }

  void _listenCalendarRequestsFromSupabase() {
    final user = Supabase.instance.client.auth.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return;

    try {
      _calendarSub = Supabase.instance.client
          .from('client_custom_requests')
          .stream(primaryKey: ['id'])
          .order('updated_at', ascending: false)
          .listen((rows) {
            final mapped = rows
                .whereType<Map>()
                .map(
                  (row) =>
                      _requestFromSupabaseRow(Map<String, dynamic>.from(row)),
                )
                .whereType<ClientRequest>()
                .toList(growable: false);

            if (!mounted) return;
            setState(() => _supabaseRequests = mapped);
          });
    } catch (e) {
      debugPrint('ARTIST CALENDAR STREAM FAILED: $e');
    }
  }

  Future<List<Map<String, dynamic>>>
  _fetchCalendarRequestRowsFromSupabase() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now();
    final minDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 30));
    final maxDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 120));

    try {
      final rows = await supabase
          .from('client_custom_requests')
          .select()
          .order('created_at', ascending: false)
          .limit(250);

      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) {
            final data = _flattenCalendarRow(row);
            final neededBy = _dateFromAny(
              _firstNonEmptyCalendar([
                data['needBy'],
                data['neededBy'],
                data['dueDate'],
                data['createdAt'],
                data['created_at'],
              ]),
            );
            if (neededBy == null) return true;
            final d = _dateOnly(neededBy);
            return !d.isBefore(minDate) && !d.isAfter(maxDate);
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('ARTIST CALENDAR FETCH FAILED: $e');
      return const <Map<String, dynamic>>[];
    }
  }

  ClientRequest? _requestFromSupabaseRow(Map<String, dynamic> row) {
    try {
      final data = _flattenCalendarRow(row);
      final neededBy =
          _dateFromAny(
            _firstNonEmptyCalendar([
              data['needBy'],
              data['neededBy'],
              data['dueDate'],
              data['createdAt'],
              data['created_at'],
              data['updatedAt'],
              data['updated_at'],
            ]),
          ) ??
          DateTime.now();

      final dims = _asMapCalendar(
        _firstExistingCalendar([
          _asMapCalendar(data['nailPreferences'])['dimensions'],
          _asMapCalendar(data['nail_preferences'])['dimensions'],
          _asMapCalendar(data['requestDetails'])['dimensions'],
          data['dimensions'],
        ]),
      );

      final left = NailDimensions(
        thumb: _dimText(dims['lThumb']),
        index: _dimText(dims['lIndex']),
        middle: _dimText(dims['lMiddle']),
        ring: _dimText(dims['lRing']),
        pinky: _dimText(dims['lPinky']),
      );

      final right = NailDimensions(
        thumb: _dimText(dims['rThumb']),
        index: _dimText(dims['rIndex']),
        middle: _dimText(dims['rMiddle']),
        ring: _dimText(dims['rRing']),
        pinky: _dimText(dims['rPinky']),
      );

      return ClientRequest(
        id: _firstNonEmptyCalendar([
          row['id'],
          data['id'],
          data['orderNumber'],
          data['order_number'],
        ]),
        clientName: _firstNonEmptyCalendar([
          data['clientName'],
          data['client_name'],
          data['brandName'],
          data['companyName'],
          'Client',
        ]),
        title: _firstNonEmptyCalendar([
          data['title'],
          data['campaignName'],
          data['requestTitle'],
          data['orderNumber'],
          data['order_number'],
          'Custom Nail Request',
        ]),
        subtitle: _firstNonEmptyCalendar([
          data['subtitle'],
          data['descriptionPreview'],
          data['description'],
          data['status'],
        ]),
        neededBy: neededBy,
        budgetMin: _asIntCalendar(data['budgetMin']),
        budgetMax: _asIntCalendar(data['budgetMax']),
        nailShape: _firstNonEmptyCalendar([
          _asMapCalendar(data['nailPreferences'])['shape'],
          _asMapCalendar(data['nail_preferences'])['shape'],
          data['nailShape'],
        ]),
        nailLength: _firstNonEmptyCalendar([
          _asMapCalendar(data['nailPreferences'])['length'],
          _asMapCalendar(data['nail_preferences'])['length'],
          data['nailLength'],
        ]),
        bio: _firstNonEmptyCalendar([
          data['bio'],
          data['description'],
          _asMapCalendar(data['requestDetails'])['description'],
        ]),
        leftHand: left,
        rightHand: right,
        images: _stringListCalendar(
          _firstExistingCalendar([
            data['inspiration_photos'],
            data['inspirationPhotos'],
            data['clientImages'],
            data['photos'],
          ]),
        ),
        status: _statusFromCalendar(
          data['artistStatus'] ?? data['artist_status'] ?? data['status'],
        ),
        isDirectRequest: _asBoolCalendar(data['isDirectRequest']),
        estimatedShipDays: _asIntCalendar(data['estimatedShipDays']) == 0
            ? 3
            : _asIntCalendar(data['estimatedShipDays']),
      );
    } catch (e) {
      debugPrint('ARTIST CALENDAR MAP ROW FAILED: $e');
      return null;
    }
  }

  Map<String, dynamic> _flattenCalendarRow(Map<String, dynamic> row) {
    final data = <String, dynamic>{...row};

    void merge(Object? raw) {
      final map = _asMapCalendar(raw);
      if (map.isNotEmpty) data.addAll(map);
    }

    merge(row['summary']);
    merge(row['details']);

    final details = _asMapCalendar(row['details']);
    final requestDetails = _asMapCalendar(details['requestDetails']);
    final budget = _asMapCalendar(details['budget']);

    if (requestDetails.isNotEmpty) {
      data['requestDetails'] ??= requestDetails;
      data['description'] ??= requestDetails['description'];
      data['descriptionPreview'] ??= requestDetails['description'];
      data['needBy'] ??= requestDetails['needBy'];
      data['neededBy'] ??= requestDetails['neededBy'];
    }

    if (budget.isNotEmpty) {
      data['budgetMin'] ??= budget['min'];
      data['budgetMax'] ??= budget['max'];
    }

    data['clientName'] ??= row['client_name'];
    data['orderNumber'] ??= row['order_number'];
    data['artistStatus'] ??= row['artist_status'];
    data['inspirationPhotos'] ??= row['inspiration_photos'];
    data['photoCount'] ??= row['photo_count'];
    data['createdAt'] ??= row['created_at'];
    data['updatedAt'] ??= row['updated_at'];

    return data;
  }

  RequestStatus _statusFromCalendar(Object? raw) {
    final value = (raw ?? '').toString().trim().toLowerCase();
    switch (value) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'completed':
        return RequestStatus.completed;
      case 'shipped':
        return RequestStatus.shipped;
      case 'delivered':
        return RequestStatus.delivered;
      case 'cancelled':
      case 'canceled':
        return RequestStatus.cancelled;
      case 'declined':
        return RequestStatus.declined;
      case 'expired':
        return RequestStatus.expired;
      case 'new':
      case 'new_request':
      case 'pending':
      case 'submitted':
      case 'review':
      case 'in_review':
      case 'in review':
        return RequestStatus.newRequest;
      default:
        return RequestStatus.accepted;
    }
  }

  Map<String, dynamic> _asMapCalendar(Object? raw) {
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
    if (raw is Map)
      return raw.map((key, value) => MapEntry(key.toString(), value));
    return const <String, dynamic>{};
  }

  List<String> _stringListCalendar(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) {
            if (item is Map) {
              return _firstNonEmptyCalendar([
                item['imageUrl'],
                item['downloadUrl'],
                item['photoUrl'],
                item['url'],
                item['path'],
                item['storagePath'],
                item['fullPath'],
              ]);
            }
            return (item ?? '').toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? const <String>[] : <String>[value];
  }

  String _firstNonEmptyCalendar(List<Object?> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }

  Object? _firstExistingCalendar(List<Object?> values) {
    for (final value in values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      return value;
    }
    return null;
  }

  int _asIntCalendar(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse((raw ?? '').toString().trim()) ?? 0;
  }

  bool _asBoolCalendar(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    final value = (raw ?? '').toString().trim().toLowerCase();
    return value == 'true' || value == 'yes' || value == '1';
  }

  DateTime? _dateFromAny(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is num) {
      final millis = raw.toInt();
      if (millis > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  String _dimText(Object? raw) {
    if (raw is num) {
      final number = raw.toDouble();
      final value = number == number.roundToDouble()
          ? number.toInt().toString()
          : number.toString();
      return '$value mm';
    }
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty || text == 'null') return '-';
    return text.toLowerCase().contains('mm') ? text : '$text mm';
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = _monthLabel(_focusedMonth);

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: JntStandardAppBar(
        onNotifications: _openNotifications,
        trailing: _avatarMenu(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                _tabPill(),
                const SizedBox(height: 12),
                if (_tabCtrl.index == 0) ...[
                  Row(
                    children: [
                      _iconChip(
                        icon: Icons.chevron_left_rounded,
                        semanticLabel: 'Previous month',
                        onTap: () => setState(() {
                          _focusedMonth = _startOfMonth(
                            DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month - 1,
                              1,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.snow,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: AppColors.blackCat.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: AppColors.blackCat,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  monthLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                              ),
                              Semantics(
                                button: true,
                                child: GestureDetector(
                                onTap: () => setState(() {
                                  final now = _dateOnly(DateTime.now());
                                  _selectedDay = now;
                                  _focusedMonth = _startOfMonth(now);
                                }),
                                child: Text(
                                  'Today',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.blackCat,
                                  ),
                                ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _iconChip(
                        icon: Icons.chevron_right_rounded,
                        semanticLabel: 'Next month',
                        onTap: () => setState(() {
                          _focusedMonth = _startOfMonth(
                            DateTime(
                              _focusedMonth.year,
                              _focusedMonth.month + 1,
                              1,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_monthlyView(), _scheduleView()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavigationBar(
              currentIndex: widget.bottomNavIndex,
              selectedItemColor: AppColors.blackCat,
              unselectedItemColor: AppColors.blackCat.withValues(alpha: 0.35),
              backgroundColor: AppColors.balletSlippers,
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                if (widget.onNavTap != null) {
                  widget.onNavTap!(i);
                  return;
                }
                if (i != widget.bottomNavIndex) {
                  Navigator.pop(context);
                }
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  label: 'Design',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inbox_outlined),
                  label: 'Requests',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null,
    );
  }

  void _openManageProfile() {
    if (widget.onManageProfile != null) {
      widget.onManageProfile!.call();
      return;
    }
    if (widget.onOpenProfile != null) {
      widget.onOpenProfile!.call();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const ArtistProfilePage(showBottomNav: true, bottomNavIndex: 2),
      ),
    );
  }

  void _openNotifications() {
    if (widget.onOpenNotifications != null) {
      widget.onOpenNotifications!.call();
      return;
    }
    NotificationsPage.showAsModal(context);
  }

  Future<void> _signOut() async {
    if (widget.onSignOut != null) {
      widget.onSignOut!.call();
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _openHistoryFromMenu() {
    widget.onOpenHistory?.call();
  }

  void _openCalendarFromMenu() {
    widget.onOpenCalendar?.call();
  }

  void _openArtistFromMenu() {
    widget.onOpenArtist?.call();
  }

  void _openReviewsFromMenu() {
    widget.onOpenReviews?.call();
  }

  Widget _avatarMenu() {
    return PopupMenuButton<_HeaderAvatarAction>(
      tooltip: '',
      position: PopupMenuPosition.under,
      elevation: 12,
      color: AppColors.snow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      onSelected: (v) {
        switch (v) {
          case _HeaderAvatarAction.profile:
            _openManageProfile();
            break;
          case _HeaderAvatarAction.earnings:
            widget.onOpenEarnings?.call();
            break;
          case _HeaderAvatarAction.history:
            _openHistoryFromMenu();
            break;
          case _HeaderAvatarAction.calendar:
            _openCalendarFromMenu();
            break;
          case _HeaderAvatarAction.artist:
            _openArtistFromMenu();
            break;
          case _HeaderAvatarAction.reviews:
            _openReviewsFromMenu();
            break;
          case _HeaderAvatarAction.signOut:
            _signOut();
            break;
        }
      },
      child: SizedBox(
        height: JntHeaderMetrics.avatarSize,
        width: JntHeaderMetrics.avatarSize,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: const ArtistProfileAvatarIcon(size: JntHeaderMetrics.avatarSize),
        ),
      ),
      itemBuilder: (_) {
        if (!widget.showExtendedAvatarMenu) {
          return [
            if (widget.onOpenReviews != null)
              const PopupMenuItem(
                value: _HeaderAvatarAction.reviews,
                child: _HeaderMenuRow(
                  icon: Icons.star_border,
                  label: 'Reviews',
                ),
              ),
            if (widget.onOpenReviews != null) const PopupMenuDivider(),
            const PopupMenuItem(
              value: _HeaderAvatarAction.signOut,
              child: _HeaderMenuRow(
                icon: Icons.logout_rounded,
                label: 'Logout',
              ),
            ),
          ];
        }
        return [
          const PopupMenuItem(
            value: _HeaderAvatarAction.profile,
            child: _HeaderMenuRow(icon: Icons.person_outline, label: 'Profile'),
          ),
          if (widget.onOpenEarnings != null)
            const PopupMenuItem(
              value: _HeaderAvatarAction.earnings,
              child: _HeaderMenuRow(
                icon: Icons.attach_money_outlined,
                label: 'Earnings',
              ),
            ),
          if (!widget.hideHistoryMenuItem)
            const PopupMenuItem(
              value: _HeaderAvatarAction.history,
              child: _HeaderMenuRow(icon: Icons.history, label: 'History'),
            ),
          if (!widget.hideCalendarMenuItem)
            const PopupMenuItem(
              value: _HeaderAvatarAction.calendar,
              child: _HeaderMenuRow(
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
              ),
            ),
          const PopupMenuItem(
            value: _HeaderAvatarAction.artist,
            child: _HeaderMenuRow(icon: Icons.brush_outlined, label: 'Artist'),
          ),
          if (widget.onOpenReviews != null)
            const PopupMenuItem(
              value: _HeaderAvatarAction.reviews,
              child: _HeaderMenuRow(icon: Icons.star_border, label: 'Reviews'),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _HeaderAvatarAction.signOut,
            child: _HeaderMenuRow(
              icon: Icons.logout_rounded,
              label: 'Logout',
              color: AppColors.blackCat,
            ),
          ),
        ];
      },
    );
  }

  Widget _tabPill() {
    return TabBar(
      controller: _tabCtrl,
      onTap: (_) => setState(() {}),
      labelPadding: EdgeInsets.zero,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.alabaster, width: 3),
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      labelColor: AppColors.blackCat,
      unselectedLabelColor: AppColors.blackCat,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 12 * fontScale(context),
      ),
      tabs: const [
        Tab(text: 'Monthly'),
        Tab(text: 'Schedule'),
      ],
    );
  }

  Widget _iconChip({
    required IconData icon,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatLight),
        ),
        child: Icon(icon, color: AppColors.blackCat),
      ),
      ),
    );
  }

  // âœ… UPDATED: monthly calendar now looks like a real calendar
  // - no big rounded boxes per day
  // - circular selection
  // - "today" ring
  // - muted out-of-month days
  // - small dots under day number
  Widget _monthlyView() {
    final days = _buildMonthGridDays(_focusedMonth);
    final selected = _selectedDay;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.blackCatLight),
            boxShadow: [
              BoxShadow(
                color: AppColors.snow,
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _weekdaysRow(),
              const SizedBox(height: 10),

              // Actual calendar-like grid
              LayoutBuilder(
                builder: (context, c) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: days.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 1.05,
                        ),
                    itemBuilder: (context, i) {
                      final d = days[i];
                      final isInMonth = d.month == _focusedMonth.month;
                      final isSelected = _isSameDate(d, selected);
                      final isToday = _isSameDate(d, _dateOnly(DateTime.now()));

                      final dueCount = _dueCountOn(d);
                      final dots = dueCount.clamp(0, 3);

                      return _calendarDayCell(
                        day: d,
                        isInMonth: isInMonth,
                        isSelected: isSelected,
                        isToday: isToday,
                        dotCount: dots,
                        onTap: () =>
                            setState(() => _selectedDay = _dateOnly(d)),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.blackCatLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedHeaderLabel(_selectedDay),
                style: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: AppColors.blackCat,
                ),
              ),
              const SizedBox(height: 10),
              ..._agendaForDate(_selectedDay).map(_agendaTile),
              if (_agendaForDate(_selectedDay).isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No due requests for this day',
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w400,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calendarDayCell({
    required DateTime day,
    required bool isInMonth,
    required bool isSelected,
    required bool isToday,
    required int dotCount,
    required VoidCallback onTap,
  }) {
    final dayTextColor = !isInMonth
        ? AppColors.blackCat.withValues(alpha: 0.30)
        : (isSelected ? Colors.white : AppColors.blackCat);

    final circleBg = isSelected ? AppColors.deepPlum : Colors.transparent;

    final todayRing = isToday && !isSelected
        ? Border.all(
            color: AppColors.blackCat.withValues(alpha: 0.45),
            width: 2,
          )
        : Border.all(color: Colors.transparent, width: 2);

    final label =
        '${day.month}/${day.day}/${day.year}'
        '${isToday ? ', today' : ''}'
        '${dotCount > 0 ? ', $dotCount ${dotCount == 1 ? 'appointment' : 'appointments'}' : ''}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellHeight = constraints.maxHeight;
          final cellWidth = constraints.maxWidth;
          final dotSize = (cellHeight * 0.09).clamp(3.0, 5.0);
          final spacing = (cellHeight * 0.05).clamp(2.0, 4.0);
          final availableForCircle = cellHeight - (spacing + dotSize + 4);
          final circleSize = availableForCircle.clamp(22.0, 34.0).toDouble();
          final textSize = (11.5 * fontScale(context)).clamp(10.0, 13.0);

          return SizedBox(
            width: cellWidth,
            height: cellHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  height: circleSize,
                  width: circleSize,
                  decoration: BoxDecoration(
                    color: circleBg,
                    shape: BoxShape.circle,
                    border: todayRing,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.blackCat.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: textSize,
                      color: dayTextColor,
                    ),
                  ),
                ),
                SizedBox(height: spacing),
                if (dotCount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(dotCount, (_) {
                      return Container(
                        width: dotSize,
                        height: dotSize,
                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.snow.withValues(alpha: 0.95)
                              : AppColors.blackCat.withValues(
                                  alpha: isInMonth ? 0.85 : 0.25,
                                ),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  )
                else
                  SizedBox(height: dotSize),
              ],
            ),
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _weekdaysRow() {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: labels
          .map(
            (t) => Expanded(
              child: Center(
                child: Text(
                  t,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12 * fontScale(context),
                    color: AppColors.blackCat,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _scheduleView() {
    final upcoming = _upcomingRequestsSorted();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.event_note_rounded,
                size: 20,
                color: AppColors.blackCat,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Upcoming due requests',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 12 * fontScale(context),
                    color: AppColors.blackCat,
                  ),
                ),
              ),
              Text(
                '${upcoming.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12 * fontScale(context),
                  color: AppColors.blackCat,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.blackCatBorderLight),
        const SizedBox(height: 10),
        ..._groupByDate(upcoming).entries.map((entry) {
          final date = entry.key;
          final list = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateSectionLabel(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 10),
                ...list.map(_agendaTile),
                const SizedBox(height: 2),
                const Divider(height: 1, color: AppColors.blackCatBorderLight),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _agendaTile(ClientRequest r) {
    final due = _dateOnly(r.neededBy);
    final remaining = r.neededBy.difference(DateTime.now());
    final daysLeft = due.difference(_dateOnly(DateTime.now())).inDays;

    final isOverdue = daysLeft < 0;
    final isUnder24Hours = !isOverdue && remaining <= const Duration(hours: 24);
    final isAmberWindow =
        !isOverdue &&
        remaining > const Duration(hours: 24) &&
        remaining <= const Duration(days: 3);
    final dueText = isOverdue
        ? 'Overdue'
        : (daysLeft == 0 ? 'Today' : '${daysLeft}d');
    final dueTextColor = isOverdue
        ? const Color(0xFFFF4D4D)
        : isUnder24Hours
        ? const Color(0xFFB3261E)
        : isAmberWindow
        ? const Color(0xFF8A5A00)
        : AppColors.deepPlum;

    return MergeSemantics(
      child: Semantics(
        button: true,
        onTap: () {
          setState(() {
            _selectedDay = due;
            _focusedMonth = _startOfMonth(due);
            _tabCtrl.index = 0;
          });
        },
        child: InkWell(
      borderRadius: BorderRadius.zero,
      onTap: () {
        setState(() {
          _selectedDay = due;
          _focusedMonth = _startOfMonth(due);
          _tabCtrl.index = 0;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatLight),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: AppColors.balletSlippers,
                border: Border.all(
                  color: AppColors.blackCat.withValues(alpha: 0.06),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                r.clientName.isEmpty ? 'C' : r.clientName[0].toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.clientName.isEmpty ? 'Client' : r.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Need by ${_shortDate(due)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.blackCat,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              dueText,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: dueTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  int _dueCountOn(DateTime day) {
    final d0 = _dateOnly(day);
    return _calendarRequests
        .where((r) => _isSameDate(_dateOnly(r.neededBy), d0))
        .length;
  }

  List<ClientRequest> _agendaForDate(DateTime day) {
    final d0 = _dateOnly(day);
    final list = _calendarRequests
        .where((r) => _isSameDate(_dateOnly(r.neededBy), d0))
        .toList();
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  List<ClientRequest> _upcomingRequestsSorted() {
    final now = _dateOnly(DateTime.now());
    final list = _calendarRequests.toList();

    list.sort((a, b) {
      final da = _dateOnly(a.neededBy);
      final db = _dateOnly(b.neededBy);
      final c = da.compareTo(db);
      if (c != 0) return c;
      return a.title.compareTo(b.title);
    });

    final minDate = now.subtract(const Duration(days: 30));
    final maxDate = now.add(const Duration(days: 90));
    return list.where((r) {
      final d = _dateOnly(r.neededBy);
      return !d.isBefore(minDate) && !d.isAfter(maxDate);
    }).toList();
  }

  Map<DateTime, List<ClientRequest>> _groupByDate(List<ClientRequest> items) {
    final map = <DateTime, List<ClientRequest>>{};
    for (final r in items) {
      final d = _dateOnly(r.neededBy);
      map.putIfAbsent(d, () => []);
      map[d]!.add(r);
    }
    return map;
  }

  List<DateTime> _buildMonthGridDays(DateTime focusedMonth) {
    final first = _startOfMonth(focusedMonth);
    final weekday = first.weekday; // Mon=1..Sun=7
    final leading = weekday % 7; // Sunday start
    final start = first.subtract(Duration(days: leading));
    return List.generate(42, (i) => _dateOnly(start.add(Duration(days: i))));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  String _selectedHeaderLabel(DateTime d) {
    final today = _dateOnly(DateTime.now());
    final delta = d.difference(today).inDays;
    final label = _dateSectionLabel(d);
    if (delta == 0) return '$label - Today';
    if (delta == 1) return '$label - Tomorrow';
    if (delta == -1) return '$label - Yesterday';
    return label;
  }

  String _dateSectionLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const wds = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = wds[d.weekday - 1];
    return '$wd, ${months[d.month - 1]} ${d.day}';
  }
}

enum _HeaderAvatarAction {
  profile,
  earnings,
  history,
  calendar,
  artist,
  reviews,
  signOut,
}

class _HeaderMenuRow extends StatelessWidget {
  const _HeaderMenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color ?? AppColors.blackCat.withValues(alpha: 0.70),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
