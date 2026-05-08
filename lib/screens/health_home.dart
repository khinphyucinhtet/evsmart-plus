import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_repository.dart';
import '../services/assist_directory.dart';
import 'ambulance_driver_messages.dart';
import 'ambulance_response_form_page.dart';
import 'ambulance_trip_progress.dart';
import 'menu.dart';
import 'message_conversation_page.dart';

class HealthHomePage extends StatefulWidget {
  const HealthHomePage({super.key});

  @override
  State<HealthHomePage> createState() => _HealthHomePageState();
}

class _HealthHomePageState extends State<HealthHomePage> {
  static const Color _brandGreen = Color(0xFF2E7D32);
  static const Color _darkGreen = Color(0xFF256D2C);
  static const Color _canvas = Color(0xFFF3F4F2);
  static const Color _cardBorder = Color(0xFFE6E8E1);
  static const Color _textPrimary = Color(0xFF273128);
  static const Color _textMuted = Color(0xFF6D746E);

  Map<String, dynamic> _profile = const <String, dynamic>{};
  String _currentLocationLabel = 'Fetching current location';
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  String? _activeAlertId;
  String _activeCaseStatus = 'Available';
  bool _isResponderAvailable = true;
  int _reportsSubmitted = 0;
  String _latestUpdate = 'Waiting for the next emergency alert.';
  bool _isRefreshing = false;
  final Set<String> _hiddenAlertIds = <String>{};
  final Set<String> _selectedAlertIds = <String>{};
  final Set<String> _shownHospitalDispatchPopupIds = <String>{};
  DateTime? _selectedLogDate;
  bool _selectionMode = false;
  bool _isHospitalDispatchPopupVisible = false;
  bool _isCaseTransitionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _captureCurrentLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final data = await AppRepository.getProfileByPath(
      AppRepository.ambulanceProfilesRef,
      uid,
    );

    if (!mounted || data == null) {
      return;
    }

    setState(() {
      _profile = data;
      if (_currentPosition == null) {
        _currentLocationLabel =
            data['current_location']?.toString() ?? _currentLocationLabel;
      }
    });
  }

  Future<void> _captureCurrentLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await _positionSubscription?.cancel();
        _positionSubscription = null;
        if (!mounted) {
          return;
        }
        setState(() {
          _currentPosition = null;
          _currentLocationLabel = 'Location permission is required';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      _ensureLocationTracking();
      await _syncCurrentLocation(position, uid: uid);
    } catch (_) {}
  }

  void _ensureLocationTracking() {
    if (_positionSubscription != null) {
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            unawaited(_syncCurrentLocation(position));
          },
        );
  }

  Future<void> _syncCurrentLocation(Position position, {String? uid}) async {
    final resolvedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (resolvedUid == null) {
      return;
    }

    final locationName = AppRepository.inferLocationName(
      position.latitude,
      position.longitude,
    );
    final previousPosition = _currentPosition;
    final movedFarEnough =
        previousPosition == null ||
        Geolocator.distanceBetween(
              previousPosition.latitude,
              previousPosition.longitude,
              position.latitude,
              position.longitude,
            ) >=
            50;
    final locationChanged = locationName != _currentLocationLabel;

    if (!movedFarEnough && !locationChanged) {
      return;
    }

    await AppRepository.upsertAmbulanceProfile(resolvedUid, {
      'current_location': locationName,
      'current_latitude': position.latitude,
      'current_longitude': position.longitude,
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _currentPosition = position;
      _currentLocationLabel = locationName;
      _profile = <String, dynamic>{
        ..._profile,
        'current_location': locationName,
        'current_latitude': position.latitude,
        'current_longitude': position.longitude,
      };
    });
  }

  Future<void> _updateAlert(String alertId, Map<String, dynamic> data) async {
    await AppRepository.updateAlert(alertId, data);
  }

  Future<void> _launchMap(Map<String, dynamic> alert) async {
    final destinationLat = (alert['latitude'] as num?)?.toDouble() ?? 0;
    final destinationLng = (alert['longitude'] as num?)?.toDouble() ?? 0;
    final originLat = _currentPosition?.latitude;
    final originLng = _currentPosition?.longitude;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=${originLat ?? ''},${originLng ?? ''}&destination=$destinationLat,$destinationLng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _waitForDialogTransition() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _callEvUser(Map<String, dynamic> alert) async {
    final phone = _phoneText(alert);
    if (phone.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No EV user phone number available.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openConversation(Map<String, dynamic> alert) async {
    final conversation = await AppRepository.ensureResponderConversationFromAlert(
      responderRole: 'hospital',
      alert: alert,
      initialMessage: _impactLevel(alert) >= 4
          ? 'Emergency team is on the way. Stay calm.'
          : 'Ambulance support is reviewing your alert. Please stay available in chat.',
    );

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageConversationPage(
          conversation: conversation,
          currentSenderRole: 'hospital',
          currentSenderName:
              conversation['responder_name']?.toString() ?? 'Ambulance Driver',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _brandGreen,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MenuPage()),
            );
          },
        ),
        title: const Text('EVSmart+', style: TextStyle(color: Colors.white)),
        actions: [
          StreamBuilder<int>(
            stream: AppRepository.streamUnreadBadgeCount('hospital'),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AmbulanceDriverMessagesPage(),
                    ),
                  );
                },
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.message_outlined, color: Colors.white),
                    if (unreadCount > 0)
                      Positioned(
                        right: -5,
                        top: -6,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: AppRepository.streamAlerts(),
        builder: (context, snapshot) {
          final alerts = _sortedAlerts(
            (snapshot.data ?? const <Map<String, dynamic>>[])
                .where(_isRealFeedAlert)
                .toList(growable: false),
          );
          final nearbyAlerts = _filterNearbyAlerts(alerts);
          final activeAlert = _resolveActiveAlert(nearbyAlerts);
          final visibleNearbyAlerts = _isResponderAvailable
              ? nearbyAlerts
              : const <Map<String, dynamic>>[];
          final visibleActiveAlert = _isResponderAvailable ? activeAlert : null;
          final feedAlerts = visibleNearbyAlerts
              .where((alert) {
                final alertId = _alertId(alert);
                return alertId != _activeAlertId &&
                    !_hiddenAlertIds.contains(alertId);
              })
              .toList(growable: false);
          final hospitalDispatchAlert = _isResponderAvailable
              ? _firstPendingHospitalDispatchAlert(visibleNearbyAlerts)
              : null;
          final accidentNotifications = feedAlerts
              .where((alert) => _impactLevel(alert) >= 3)
              .toList(growable: false);
          final logAlerts = _filteredLogAlerts(visibleNearbyAlerts);
          _maybeShowHospitalDispatchPopup(hospitalDispatchAlert);

          return RefreshIndicator(
            color: _brandGreen,
            onRefresh: _refreshDashboard,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                _buildLocationBanner(
                  nearbyAlerts: visibleNearbyAlerts,
                  allAlerts: alerts,
                  activeAlert: visibleActiveAlert,
                ),
                if (_isResponderAvailable) ...[
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: 'ACTIVE CASE',
                    icon: Icons.local_shipping_rounded,
                    child: visibleActiveAlert == null
                        ? _buildEmptyPanel(
                            title: 'No active case',
                            subtitle:
                                'Accept a Level 4 or Level 5 emergency and it will move here automatically.',
                          )
                        : _buildActiveCaseCard(visibleActiveAlert),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: 'NEARBY ACCIDENT NOTIFICATIONS',
                    icon: Icons.notification_important_rounded,
                    trailing: _buildRefreshButton(),
                    child: accidentNotifications.isEmpty
                        ? _buildEmptyPanel(
                            title: 'No severe accident nearby',
                            subtitle:
                                'Level 3 check-first cases and Level 4/5 emergency cases near your ambulance location will appear here first.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level 3 cases are for contact/check first. Level 4 and Level 5 cases are emergency aid cases and require the ambulance response form.',
                                style: TextStyle(
                                  color: _textMuted,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildFeedSelectionToolbar(accidentNotifications),
                              const SizedBox(height: 12),
                              ...accidentNotifications.map(_buildEmergencyCard),
                            ],
                          ),
                  ),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    title: 'AMBULANCE CASE LOG',
                    icon: Icons.fact_check_rounded,
                    child: logAlerts.isEmpty
                        ? _buildEmptyPanel(
                            title: 'No case history yet',
                            subtitle:
                                'Accepted, declined, and submitted accident cases will remain visible here for demo review.',
                          )
                        : _buildDashboardLogPanel(
                            allAlerts: visibleNearbyAlerts,
                            visibleLogs: logAlerts,
                          ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _captureCurrentLocation();
      await _loadProfile();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _latestUpdate =
              'Emergency feed refreshed at ${_formatClockTime(DateTime.now())}.';
        });
      }
    }
  }

  Future<void> _performDriverCaseAcceptance(
    Map<String, dynamic> alert, {
    Map<String, dynamic>? responseForm,
  }) async {
    final alertId = _alertId(alert);
    if (alertId.isEmpty) {
      return;
    }

    if (_currentPosition == null) {
      await _captureCurrentLocation();
    }

    final level = _impactLevel(alert);
    final driverName =
        _profile['driver_name']?.toString() ??
        _profile['hospital_name']?.toString() ??
        'Ambulance Driver';
    final responseSubmittedAt = DateTime.now().toIso8601String();
    final updateData = <String, dynamic>{
      'status': 'En Route',
      'assigned_role': 'hospital',
      'hospital_feed_status': responseForm == null
          ? 'Driver accepted and en route'
          : 'Ambulance response form submitted',
      'hospital_received': true,
      'accepted_at': DateTime.now().toIso8601String(),
      'driver_dispatch_requested': true,
      'driver_dispatch_status': 'accepted',
      'assigned_driver_uid': FirebaseAuth.instance.currentUser?.uid,
      'assigned_driver_name': driverName,
      'assigned_driver_location': _currentLocationLabel,
      'assigned_driver_latitude': _currentPosition?.latitude,
      'assigned_driver_longitude': _currentPosition?.longitude,
      'driver_accepted_at': DateTime.now().toIso8601String(),
      'hospital_name': _profile['hospital_name'],
      'accepted_by_uid': FirebaseAuth.instance.currentUser?.uid,
      'accepted_by_name': driverName,
    };

    if (responseForm != null) {
      updateData.addAll({
        'ambulance_response_submitted': true,
        'ambulance_response_submitted_at': responseSubmittedAt,
        'ambulance_eta_minutes': responseForm['eta_minutes'],
        'ambulance_unit': responseForm['ambulance_unit'],
        'ambulance_contact': responseForm['contact_number'],
        'ambulance_team_size': responseForm['team_size'],
        'ambulance_response_note': responseForm['notes'],
        'responder_note': responseForm['notes'],
        'responder_current_location': _currentLocationLabel,
      });
    }

    await _updateAlert(alertId, updateData);

    final ambulanceLocation = _currentLocationLabel.trim().isEmpty
        ? 'the nearest ambulance standby point'
        : _currentLocationLabel.trim();
    final autoMessage = responseForm == null
        ? level >= 4
              ? 'Emergency team is reviewing your alert. Stay calm.'
              : 'We are reviewing your alert and will update you in chat shortly.'
        : 'Help is on the way. ${responseForm['ambulance_unit']} accepted your case and is coming from $ambulanceLocation with ETA ${responseForm['eta_minutes']} min. Keep your phone nearby and stay visible if it is safe.';

    if (responseForm != null) {
      await AppRepository.pushDashboardNotification(
        audience: 'hospital',
        type: 'Ambulance Response',
        title: 'Ambulance going to accident',
        message:
            '$driverName accepted ${_severityHeadline(level)} at ${_locationText(alert)}. ETA ${responseForm['eta_minutes']} min, unit ${responseForm['ambulance_unit']}.',
        alertId: alertId,
        userId: alert['user_id']?.toString(),
        extraData: {
          'driver_name': driverName,
          'driver_location': _currentLocationLabel,
          'eta_minutes': responseForm['eta_minutes'],
          'ambulance_unit': responseForm['ambulance_unit'],
          'contact_number': responseForm['contact_number'],
          'team_size': responseForm['team_size'],
          'notes': responseForm['notes'],
        },
      );
    }

    await AppRepository.ensureResponderConversationFromAlert(
      responderRole: 'hospital',
      alert: {...alert, ...updateData},
      initialMessage: autoMessage,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _activeAlertId = alertId;
      _activeCaseStatus = 'En Route';
      _latestUpdate =
          '${_severityHeadline(level)} accepted and ambulance is en route.';
      _shownHospitalDispatchPopupIds.add(alertId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Response sent to hospital dashboard and moved to Active Case.',
        ),
      ),
    );
  }

  void _maybeShowHospitalDispatchPopup(Map<String, dynamic>? alert) {
    if (alert == null ||
        !_isResponderAvailable ||
        _isHospitalDispatchPopupVisible ||
        _isCaseTransitionInProgress) {
      return;
    }

    final alertId = _alertId(alert);
    if (alertId.isEmpty ||
        _shownHospitalDispatchPopupIds.contains(alertId) ||
        _hiddenAlertIds.contains(alertId)) {
      return;
    }

    _shownHospitalDispatchPopupIds.add(alertId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showHospitalDispatchPopup(alert);
    });
  }

  Future<void> _showHospitalDispatchPopup(Map<String, dynamic> alert) async {
    if (_isHospitalDispatchPopupVisible ||
        _isCaseTransitionInProgress ||
        !mounted) {
      return;
    }

    _isHospitalDispatchPopupVisible = true;
    final decision = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Emergency detected nearby',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hospital dashboard dispatched a nearby case to this ambulance driver app.',
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.person_rounded,
                value: _personName(alert),
                color: _textPrimary,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.location_on_rounded,
                value: _locationText(alert),
                color: _textPrimary,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.warning_amber_rounded,
                value:
                    'Impact Level ${_impactLevel(alert)} - ${AppRepository.severityExplanation(_impactLevel(alert))}',
                color: _textMuted,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                dialogContext,
                rootNavigator: true,
              ).pop('decline'),
              child: const Text('Not going'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop('going'),
              child: const Text('Going'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      _isHospitalDispatchPopupVisible = false;
      return;
    }

    await _waitForDialogTransition();
    _isHospitalDispatchPopupVisible = false;

    if (!mounted) {
      return;
    }

    if (decision == 'going') {
      await _acceptCase(alert);
    } else if (decision == 'decline') {
      await _declineCase(alert);
    }
  }

  Future<void> _acceptCase(Map<String, dynamic> alert) async {
    if (_isCaseTransitionInProgress) {
      return;
    }

    setState(() {
      _isCaseTransitionInProgress = true;
    });

    try {
      final responseForm = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => AmbulanceResponseFormPage(
            locationLabel: _locationText(alert),
            severityLabel: _severityHeadline(_impactLevel(alert)),
            severityDescription: AppRepository.severityExplanation(
              _impactLevel(alert),
            ),
            initialUnit:
                _profile['ambulance_unit']?.toString() ??
                _profile['vehicle_number']?.toString() ??
                'AMB-01',
            initialContact:
                _profile['contact_number']?.toString() ??
                _profile['phone']?.toString() ??
                '',
          ),
        ),
      );
      if (responseForm == null || !mounted) {
        return;
      }

      await _performDriverCaseAcceptance(alert, responseForm: responseForm);
      if (!mounted) {
        return;
      }

      final arrived = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AmbulanceTripProgressPage(
            destinationLabel: _locationText(alert),
            driverLabel: _personName(alert),
            severityLabel: _severityHeadline(_impactLevel(alert)),
            ambulanceUnit:
                responseForm['ambulance_unit']?.toString() ?? 'Ambulance Unit',
            etaMinutes: (responseForm['eta_minutes'] as int?) ?? 8,
          ),
        ),
      );

      if (!mounted || arrived != true) {
        return;
      }

      await _markArrived(alert);
    } finally {
      if (mounted) {
        setState(() {
          _isCaseTransitionInProgress = false;
        });
      }
    }
  }

  Future<void> _declineCase(Map<String, dynamic> alert) async {
    final alertId = _alertId(alert);
    if (alertId.isEmpty) {
      return;
    }

    final driverName =
        _profile['driver_name']?.toString() ??
        _profile['hospital_name']?.toString() ??
        'Ambulance Driver';

    await _updateAlert(alertId, {
      'driver_dispatch_requested': true,
      'driver_dispatch_status': 'declined',
      'driver_declined_at': DateTime.now().toIso8601String(),
      'declined_by_uid': FirebaseAuth.instance.currentUser?.uid,
      'declined_by_name': driverName,
      'declined_driver_location': _currentLocationLabel,
      'hospital_feed_status': 'Nearby ambulance declined',
    });

    await AppRepository.pushDashboardNotification(
      audience: 'hospital',
      type: 'Ambulance Response',
      title: 'Ambulance not going',
      message:
          '$driverName declined ${_severityHeadline(_impactLevel(alert))} at ${_locationText(alert)}.',
      alertId: alertId,
      userId: alert['user_id']?.toString(),
      extraData: {
        'driver_name': driverName,
        'driver_location': _currentLocationLabel,
        'decision': 'declined',
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _hiddenAlertIds.add(alertId);
      _latestUpdate =
          '${_severityHeadline(_impactLevel(alert))} declined and hospital dashboard notified.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hospital dashboard updated: not going.')),
    );
  }

  Future<void> _markArrived(Map<String, dynamic> alert) async {
    final driverName =
        _profile['driver_name']?.toString() ??
        _profile['hospital_name']?.toString() ??
        'Ambulance Driver';

    await _updateAlert(_alertId(alert), {
      'status': 'Arrived',
      'assigned_role': 'hospital',
      'hospital_feed_status': 'Arrived at scene',
      'driver_dispatch_status': 'arrived',
      'assigned_driver_location': _currentLocationLabel,
      'assigned_driver_latitude': _currentPosition?.latitude,
      'assigned_driver_longitude': _currentPosition?.longitude,
      'arrival_timestamp': DateTime.now().toIso8601String(),
    });

    await AppRepository.pushDashboardNotification(
      audience: 'hospital',
      type: 'Ambulance Arrival',
      title: 'Ambulance arrived at scene',
      message:
          '$driverName arrived at ${_locationText(alert)} and is ready to submit the patient scene report.',
      alertId: _alertId(alert),
      userId: alert['user_id']?.toString(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _activeCaseStatus = 'Arrived';
      _latestUpdate =
          'Ambulance arrived at ${_locationText(alert)} and report form is ready.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Active case marked as arrived.')),
    );
  }

  Future<void> _showReportForm(Map<String, dynamic> alert) async {
    final formKey = GlobalKey<FormState>();
    final notesController = TextEditingController();
    var patientCount = ((alert['number_of_people'] as num?)?.toInt() ?? 1)
        .clamp(1, 9);
    var condition = 'Alive';
    var severity = _impactLevel(alert);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _brandGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_outlined,
                      color: _brandGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Emergency Report',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send emergency handover data to the hospital dashboard for ${_locationText(alert)}.',
                          style: const TextStyle(
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Number of patients',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: _canvas,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: patientCount > 1
                                    ? () => setDialogState(
                                        () => patientCount -= 1,
                                      )
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Expanded(
                                child: Text(
                                  '$patientCount patient${patientCount == 1 ? '' : 's'}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: patientCount < 9
                                    ? () => setDialogState(
                                        () => patientCount += 1,
                                      )
                                    : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Condition',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in const [
                              'Alive',
                              'Critical',
                              'Deceased',
                            ])
                              ChoiceChip(
                                label: Text(item),
                                selected: condition == item,
                                selectedColor: _brandGreen.withValues(
                                  alpha: 0.16,
                                ),
                                onSelected: (_) {
                                  setDialogState(() {
                                    condition = item;
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<int>(
                          initialValue: severity,
                          decoration: InputDecoration(
                            labelText: 'Severity',
                            filled: true,
                            fillColor: _canvas,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: List.generate(5, (index) {
                            final level = index + 1;
                            return DropdownMenuItem<int>(
                              value: level,
                              child: Text('Level $level'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                severity = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: notesController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Notes',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: _canvas,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a short handover note.';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext, rootNavigator: true).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    Navigator.of(
                      dialogContext,
                      rootNavigator: true,
                    ).pop(<String, dynamic>{
                      'patients': patientCount,
                      'condition': condition,
                      'severity': severity,
                      'notes': notesController.text.trim(),
                    });
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      notesController.dispose();
      return;
    }

    await _waitForDialogTransition();
    final nearestHospital = _nearestHospitalForAlert(alert);
    final nearestHospitalName =
        nearestHospital?['name']?.toString() ?? 'Nearest hospital';
    final nearestHospitalAddress =
        nearestHospital?['address']?.toString() ?? _locationText(alert);

    await _updateAlert(_alertId(alert), {
      'status': 'Report submitted to hospital dashboard',
      'assigned_role': 'hospital',
      'hospital_feed_status': 'Report submitted',
      'hospital_received': true,
      'driver_dispatch_status': 'report_submitted',
      'assigned_driver_uid': FirebaseAuth.instance.currentUser?.uid,
      'assigned_driver_name':
          _profile['driver_name']?.toString() ??
          _profile['hospital_name']?.toString() ??
          'Ambulance Driver',
      'assigned_driver_location': _currentLocationLabel,
      'assigned_driver_latitude': _currentPosition?.latitude,
      'assigned_driver_longitude': _currentPosition?.longitude,
      'number_of_people': result['patients'],
      'patient_status': result['condition'],
      'impact_level': result['severity'],
      'responder_note': result['notes'],
      'report_submitted_at': DateTime.now().toIso8601String(),
      'nearest_hospital_name': nearestHospitalName,
      'nearest_hospital_address': nearestHospitalAddress,
      'nearest_hospital_phone': nearestHospital?['phone']?.toString(),
    });

    await AppRepository.pushDashboardNotification(
      audience: 'all',
      type: 'Responder Update',
      title: 'Hospital report submitted',
      message:
          '${result['patients']} patient(s) at ${_locationText(alert)}. Condition: ${result['condition']}. Sent to $nearestHospitalName dashboard.',
      alertId: _alertId(alert),
      extraData: {
        'nearest_hospital_name': nearestHospitalName,
        'nearest_hospital_address': nearestHospitalAddress,
      },
    );

    notesController.dispose();

    if (!mounted) {
      return;
    }

    setState(() {
      _reportsSubmitted += 1;
      _latestUpdate =
          'Report sent: ${result['patients']} patient(s), ${result['condition']}, Level ${result['severity']}.';
      _activeAlertId = null;
      _activeCaseStatus = 'Available';
    });

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Report sent',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'The emergency report was sent to $nearestHospitalName dashboard.\n\nAddress: $nearestHospitalAddress',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _hideAlertFromFeed(Map<String, dynamic> alert) {
    final alertId = _alertId(alert);
    if (alertId.isEmpty) {
      return;
    }

    setState(() {
      _hiddenAlertIds.add(alertId);
      _latestUpdate =
          '${_severityHeadline(_impactLevel(alert))} at ${_locationText(alert)} hidden from this feed.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_locationText(alert)} hidden from the feed.'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            if (!mounted) {
              return;
            }
            setState(() {
              _hiddenAlertIds.remove(alertId);
            });
          },
        ),
      ),
    );
  }

  Future<void> _deleteAlertFromFeed(Map<String, dynamic> alert) async {
    final alertId = _alertId(alert);
    if (alertId.isEmpty) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete alert?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '${_severityHeadline(_impactLevel(alert))} at ${_locationText(alert)} will be removed from Firebase alerts and notifications.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    await AppRepository.deleteAlert(alertId);
    await AppRepository.deleteNotificationsByAlertIds([alertId]);

    if (!mounted) {
      return;
    }

    setState(() {
      _hiddenAlertIds.remove(alertId);
      _selectedAlertIds.remove(alertId);
      if (_activeAlertId == alertId) {
        _activeAlertId = null;
        _activeCaseStatus = 'Available';
      }
      _latestUpdate =
          '${_severityHeadline(_impactLevel(alert))} at ${_locationText(alert)} deleted from the feed.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert deleted from the emergency feed.')),
    );
  }

  void _toggleAlertSelection(String alertId, bool selected) {
    if (alertId.isEmpty) {
      return;
    }

    setState(() {
      _selectionMode = true;
      if (selected) {
        _selectedAlertIds.add(alertId);
      } else {
        _selectedAlertIds.remove(alertId);
      }
    });
  }

  void _setSelectionForAlerts(
    List<Map<String, dynamic>> alerts,
    bool selected,
  ) {
    final ids = _alertIds(alerts);
    if (ids.isEmpty) {
      return;
    }

    setState(() {
      _selectionMode = true;
      if (selected) {
        _selectedAlertIds.addAll(ids);
      } else {
        _selectedAlertIds.removeAll(ids);
      }
    });
  }

  Future<void> _deleteSelectedAlerts() async {
    final ids = _selectedAlertIds
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete selected logs?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            '${ids.length} selected accident log${ids.length == 1 ? '' : 's'} will be removed from Firebase alerts and notifications.',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete selected'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await AppRepository.deleteAlerts(ids);
    await AppRepository.deleteNotificationsByAlertIds(ids);

    if (!mounted) {
      return;
    }

    setState(() {
      _hiddenAlertIds.removeAll(ids);
      _selectedAlertIds.removeAll(ids);
      if (_activeAlertId != null && ids.contains(_activeAlertId)) {
        _activeAlertId = null;
        _activeCaseStatus = 'Available';
      }
      _latestUpdate =
          '${ids.length} accident log${ids.length == 1 ? '' : 's'} deleted.';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${ids.length} accident log${ids.length == 1 ? '' : 's'} deleted.',
        ),
      ),
    );
  }

  Future<void> _pickLogDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedLogDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: _brandGreen),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedLogDate = picked;
    });
  }

  Widget _buildLocationBanner({
    required List<Map<String, dynamic>> nearbyAlerts,
    required List<Map<String, dynamic>> allAlerts,
    required Map<String, dynamic>? activeAlert,
  }) {
    final permissionGranted = _currentPosition != null;
    final statusLabel = _isResponderAvailable ? 'Available' : 'Not Available';
    final bannerLocationLabel = permissionGranted
        ? _currentLocationLabel
        : 'Current location unavailable';
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final liveAlertCount = nearbyAlerts.length + (activeAlert == null ? 0 : 1);
    final criticalCount =
        nearbyAlerts.where((alert) => _impactLevel(alert) >= 5).length +
        ((activeAlert != null && _impactLevel(activeAlert) >= 5) ? 1 : 0);
    final highCount =
        nearbyAlerts.where((alert) => _impactLevel(alert) == 4).length +
        ((activeAlert != null && _impactLevel(activeAlert) == 4) ? 1 : 0);
    final syncedReports = allAlerts.where((alert) {
      if (currentUid == null) {
        return false;
      }
      return alert['assigned_driver_uid']?.toString() == currentUid &&
          alert['driver_dispatch_status']?.toString().toLowerCase() ==
              'report_submitted';
    }).length;
    final displayedReports = syncedReports > _reportsSubmitted
        ? syncedReports
        : _reportsSubmitted;
    final overviewDistanceLabel = permissionGranted
        ? 'Within 5 km'
        : 'GPS required';
    final overviewSubtitle = permissionGranted
        ? 'Filtered by your GPS'
        : 'Enable location access';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF236A29), Color(0xFF3A8E43)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x223A8E43),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 2,
                            ),
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          child: const Icon(
                            Icons.medical_services_rounded,
                            color: Colors.white,
                            size: 29,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'AMBULANCE\nSTATUS',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatClockTime(DateTime.now()).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'GPS',
                          style: TextStyle(
                            color: Color(0xFFE7FFE7),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          permissionGranted
                              ? Icons.network_cell_rounded
                              : Icons.location_disabled_rounded,
                          size: 18,
                          color: const Color(0xFFE7FFE7),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _isResponderAvailable
                            ? const Color(0xFF8BEA53)
                            : const Color(0xFFBFC6C0),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isResponderAvailable
                                    ? const Color(0xFF8BEA53)
                                    : const Color(0xFFBFC6C0))
                                .withValues(alpha: 0.28),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statusLabel,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Transform.scale(
                      scale: 0.78,
                      child: Switch.adaptive(
                        value: _isResponderAvailable,
                        onChanged: _toggleResponderAvailability,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF8BEA53),
                        inactiveThumbColor: const Color(0xFFE2E5E2),
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.24,
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 22,
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              bannerLocationLabel,
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white.withValues(alpha: 0.16)),
          ),
          Row(
            children: [
              Expanded(
                child: _buildBannerMetric(
                  icon: Icons.notifications_active_rounded,
                  iconColor: Colors.white,
                  value: '$liveAlertCount',
                  label: 'Active Alerts',
                ),
              ),
              _buildMetricDivider(),
              Expanded(
                child: _buildBannerMetric(
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFFF6F61),
                  value: '$criticalCount',
                  label: 'Critical (L5)',
                ),
              ),
              _buildMetricDivider(),
              Expanded(
                child: _buildBannerMetric(
                  icon: Icons.error_rounded,
                  iconColor: const Color(0xFFFFB020),
                  value: '$highCount',
                  label: 'High (L4)',
                ),
              ),
              _buildMetricDivider(),
              Expanded(
                child: _buildBannerMetric(
                  icon: Icons.assignment_turned_in_rounded,
                  iconColor: const Color(0xFF9FC5FF),
                  value: '$displayedReports',
                  label: 'Reports',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _latestUpdate,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You will be notified immediately when a case is nearby.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.6,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gps_fixed_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'NEARBY OVERVIEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8BEA53),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildBannerOverviewValue(
                        value: '$liveAlertCount',
                        title: 'Accidents Nearby',
                        subtitle: 'Level 3 and above',
                      ),
                    ),
                    _buildMetricDivider(),
                    Expanded(
                      child: _buildBannerOverviewValue(
                        value: overviewDistanceLabel,
                        title: permissionGranted
                            ? _currentLocationLabel
                            : 'Location access',
                        subtitle: overviewSubtitle,
                        icon: Icons.location_on_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Last updated:\n${_formatClockTime(DateTime.now()).toUpperCase()}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.6,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _isRefreshing ? null : _refreshDashboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: _isRefreshing ? 0.06 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isRefreshing)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isRefreshing ? 'Refreshing...' : 'Refresh Now',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerMetric({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 12.4,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      width: 1,
      height: 82,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  Widget _buildBannerOverviewValue({
    required String value,
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon == null)
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFFACF078), size: 18),
                const SizedBox(width: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11.4,
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    Key? key,
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: title == 'EMERGENCY ALERTS'
                    ? const Color(0xFFE53935)
                    : _brandGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildFeedSelectionToolbar(List<Map<String, dynamic>> alerts) {
    final ids = _alertIds(alerts);
    final selectedVisibleCount = ids
        .where((id) => _selectedAlertIds.contains(id))
        .length;
    final allVisibleSelected =
        ids.isNotEmpty && selectedVisibleCount == ids.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildToolChip(
          label: _selectionMode ? 'Selection on' : 'Select logs',
          icon: Icons.checklist_rounded,
          onPressed: () {
            setState(() {
              _selectionMode = !_selectionMode;
              if (!_selectionMode) {
                _selectedAlertIds.clear();
              }
            });
          },
        ),
        _buildToolChip(
          label: allVisibleSelected ? 'Clear visible' : 'Select all',
          icon: allVisibleSelected
              ? Icons.remove_done_rounded
              : Icons.done_all_rounded,
          onPressed: ids.isEmpty
              ? null
              : () => _setSelectionForAlerts(alerts, !allVisibleSelected),
        ),
        _buildToolChip(
          label: 'Delete selected ($selectedVisibleCount)',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onPressed: _selectedAlertIds.isEmpty ? null : _deleteSelectedAlerts,
        ),
      ],
    );
  }

  Widget _buildToolChip({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) {
    final color = destructive ? const Color(0xFFE53935) : _darkGreen;

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildEmergencyCard(Map<String, dynamic> alert) {
    final level = _impactLevel(alert);
    final palette = _paletteFor(level);
    final highPriority = level >= 4;
    final hospitalRequest = _isHospitalDispatchPending(alert);
    final dispatchStatus =
        alert['driver_dispatch_status']?.toString().toLowerCase() ?? '';
    final isAccepted =
        dispatchStatus == 'accepted' || dispatchStatus == 'en_route';
    final isArrived = dispatchStatus == 'arrived';
    final isSubmitted = dispatchStatus == 'report_submitted';
    final foreground = _textPrimary;
    final metaColor = _textMuted;
    final headerBackground = level >= 5
        ? const Color(0xFFE53935)
        : palette.soft;
    final headerForeground = level >= 5 ? Colors.white : palette.primary;
    final impactMagnitude = _impactMagnitudeLabel(alert);
    final statusLabel = _statusLabel(alert);
    final alertId = _alertId(alert);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: headerBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (_selectionMode && alertId.isNotEmpty)
                    Checkbox(
                      value: _selectedAlertIds.contains(alertId),
                      onChanged: (value) {
                        _toggleAlertSelection(alertId, value ?? false);
                      },
                      activeColor: level >= 5 ? Colors.white : _darkGreen,
                      checkColor: level >= 5 ? _darkGreen : Colors.white,
                      side: BorderSide(
                        color: level >= 5 ? Colors.white : _darkGreen,
                        width: 1.4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 18,
                    color: headerForeground,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _severityHeadline(level),
                      style: TextStyle(
                        color: headerForeground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _relativeTime(alert['timestamp']),
                    style: TextStyle(
                      color: level >= 5 ? Colors.white : _textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: headerForeground,
                    ),
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    onSelected: (value) {
                      if (value == 'hide') {
                        _hideAlertFromFeed(alert);
                        return;
                      }
                      if (value == 'delete') {
                        _deleteAlertFromFeed(alert);
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem(
                          value: 'hide',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_off_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Hide from feed'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFE53935),
                              ),
                              SizedBox(width: 10),
                              Text('Delete alert'),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _headlineText(alert),
              style: TextStyle(
                color: foreground,
                fontSize: level >= 5 ? 22 : 15,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_rounded,
              value: _locationText(alert),
              color: foreground,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              icon: Icons.person_rounded,
              value: _personName(alert),
              color: foreground,
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              icon: _isAutomatic(alert)
                  ? Icons.sensors_rounded
                  : Icons.touch_app_rounded,
              value: _sourceLabel(alert),
              color: metaColor,
            ),
            if (impactMagnitude != null) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.speed_rounded,
                value: impactMagnitude,
                color: metaColor,
              ),
            ],
            if (statusLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.verified_rounded,
                value: statusLabel,
                color: metaColor,
              ),
            ],
            if (hospitalRequest) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                icon: Icons.local_hospital_rounded,
                value:
                    'Hospital dashboard is requesting a nearby ambulance driver for this case.',
                color: _darkGreen,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              isSubmitted
                  ? 'Patient report submitted. Hospital dashboard has the latest ambulance update.'
                  : isArrived
                  ? 'Ambulance arrived. Press Submit Report to send the patient and scene update.'
                  : isAccepted
                  ? 'Ambulance dispatch started. Use Map anytime and submit the report after arrival.'
                  : hospitalRequest
                  ? 'Hospital request: choose Going or Not going. Your decision will update the hospital dashboard.'
                  : highPriority
                  ? 'Priority response: choose Going to submit the ambulance form and start the dispatch flow.'
                  : 'Level 3 check-first: contact the EV user by chat or call before deciding next action.',
              style: TextStyle(
                color: metaColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionPill(
                  label: 'CHAT',
                  icon: Icons.chat_bubble_outline_rounded,
                  background: palette.soft,
                  foreground: palette.primary,
                  border: palette.border,
                  onTap: _isCaseTransitionInProgress
                      ? null
                      : () => _openConversation(alert),
                ),
                if (level <= 3)
                  _buildActionPill(
                    label: 'CALL USER',
                    icon: Icons.call_rounded,
                    background: const Color(0xFFF1F4F0),
                    foreground: const Color(0xFF375D42),
                    border: const Color(0xFFE3E7E0),
                    onTap: _isCaseTransitionInProgress
                        ? null
                        : () => _callEvUser(alert),
                  ),
                if (level >= 4 && isAccepted)
                  _buildActionPill(
                    label: 'ARRIVED',
                    icon: Icons.place_rounded,
                    background: _darkGreen,
                    foreground: Colors.white,
                    onTap: _isCaseTransitionInProgress
                        ? null
                        : () => _markArrived(alert),
                  )
                else if (level >= 4 && isArrived)
                  _buildActionPill(
                    label: 'SUBMIT REPORT',
                    icon: Icons.assignment_turned_in_outlined,
                    background: _darkGreen,
                    foreground: Colors.white,
                    onTap: _isCaseTransitionInProgress
                        ? null
                        : () => _showReportForm(alert),
                  )
                else if (level >= 4 && !isSubmitted) ...[
                  _buildActionPill(
                    label: 'GOING',
                    icon: Icons.check_circle_outline_rounded,
                    background: level >= 5 ? Colors.white : _darkGreen,
                    foreground: level >= 5 ? _darkGreen : Colors.white,
                    onTap: _isCaseTransitionInProgress
                        ? null
                        : () => _acceptCase(alert),
                  ),
                  _buildActionPill(
                    label: 'NOT GOING',
                    icon: Icons.cancel_outlined,
                    background: const Color(0xFFFFF4F2),
                    foreground: const Color(0xFFE53935),
                    border: const Color(0xFFFFC9C2),
                    onTap: _isCaseTransitionInProgress
                        ? null
                        : () => _declineCase(alert),
                  ),
                ],
                _buildActionPill(
                  label: 'MAP',
                  icon: Icons.near_me_rounded,
                  background: level >= 5
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFFF1F4F0),
                  foreground: const Color(0xFF375D42),
                  border: level >= 5 ? null : const Color(0xFFE3E7E0),
                  onTap: _isCaseTransitionInProgress
                      ? null
                      : () => _launchMap(alert),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCaseCard(Map<String, dynamic> alert) {
    final level = _impactLevel(alert);
    final canSubmit = _activeCaseStatus == 'Arrived';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS ${_activeCaseStatus == 'En Route' ? 'En Route...' : _activeCaseStatus}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ETA: ${_estimatedEta(level)}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            value: _locationText(alert),
            color: _textPrimary,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: Icons.person_rounded,
            value: _personName(alert),
            color: _textMuted,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            icon: _isAutomatic(alert)
                ? Icons.sensors_rounded
                : Icons.touch_app_rounded,
            value: _sourceLabel(alert),
            color: _textMuted,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionPill(
                label: 'Navigate',
                icon: Icons.navigation_rounded,
                background: _brandGreen,
                foreground: Colors.white,
                onTap: _isCaseTransitionInProgress
                    ? null
                    : () => _launchMap(alert),
              ),
              _buildActionPill(
                label: 'Mark Arrived',
                icon: Icons.place_rounded,
                background: Colors.white,
                foreground: const Color(0xFF374151),
                border: const Color(0xFFD6E1DA),
                onTap:
                    _activeCaseStatus == 'Arrived' ||
                        _isCaseTransitionInProgress
                    ? null
                    : () => _markArrived(alert),
              ),
              _buildActionPill(
                label: 'Open Chat',
                icon: Icons.chat_bubble_outline_rounded,
                background: Colors.white,
                foreground: _brandGreen,
                border: const Color(0xFFD6E1DA),
                onTap: _isCaseTransitionInProgress
                    ? null
                    : () => _openConversation(alert),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canSubmit && !_isCaseTransitionInProgress
                  ? () => _showReportForm(alert)
                  : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _brandGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD7E2D9),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'SUBMIT REPORT',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardLogPanel({
    required List<Map<String, dynamic>> allAlerts,
    required List<Map<String, dynamic>> visibleLogs,
  }) {
    final ids = _alertIds(visibleLogs);
    final selectedVisibleCount = ids
        .where((id) => _selectedAlertIds.contains(id))
        .length;
    final allVisibleSelected =
        ids.isNotEmpty && selectedVisibleCount == ids.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: _darkGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accident logs - ${_selectedLogDate == null ? 'All dates' : _dateLabel(_selectedLogDate!)}',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Choose log date',
                onPressed: _pickLogDate,
                icon: const Icon(
                  Icons.event_available_rounded,
                  color: _darkGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildToolChip(
                label: _selectedLogDate == null ? 'Pick date' : 'Clear date',
                icon: _selectedLogDate == null
                    ? Icons.calendar_today_rounded
                    : Icons.event_busy_rounded,
                onPressed: _selectedLogDate == null
                    ? _pickLogDate
                    : () {
                        setState(() {
                          _selectedLogDate = null;
                        });
                      },
              ),
              _buildToolChip(
                label: allVisibleSelected ? 'Clear visible' : 'Select all',
                icon: allVisibleSelected
                    ? Icons.remove_done_rounded
                    : Icons.done_all_rounded,
                onPressed: ids.isEmpty
                    ? null
                    : () => _setSelectionForAlerts(
                        visibleLogs,
                        !allVisibleSelected,
                      ),
              ),
              _buildToolChip(
                label: 'Delete selected ($selectedVisibleCount)',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onPressed: _selectedAlertIds.isEmpty
                    ? null
                    : _deleteSelectedAlerts,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allAlerts.isEmpty)
            _buildEmptyPanel(
              title: 'No accident logs',
              subtitle: 'Real EV driver alerts will appear here automatically.',
            )
          else if (visibleLogs.isEmpty)
            _buildEmptyPanel(
              title: 'No logs on this date',
              subtitle: 'Choose another date or clear the calendar filter.',
            )
          else
            Column(children: visibleLogs.map(_buildDashboardLogTile).toList()),
        ],
      ),
    );
  }

  Widget _buildDashboardLogTile(Map<String, dynamic> alert) {
    final alertId = _alertId(alert);
    final level = _impactLevel(alert);
    final palette = _paletteFor(level);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _selectedAlertIds.contains(alertId),
            onChanged: alertId.isEmpty
                ? null
                : (value) => _toggleAlertSelection(alertId, value ?? false),
            activeColor: _darkGreen,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _severityHeadline(level),
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _headlineText(alert),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_dateTimeLabel(alert['timestamp'])} - ${_locationText(alert)}',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete this log',
            onPressed: () => _deleteAlertFromFeed(alert),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildActionPill({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    Color? border,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border ?? Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPanel({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 30, color: _brandGreen),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _sortedAlerts(List<Map<String, dynamic>> alerts) {
    final items = [...alerts];
    items.sort((left, right) {
      final dispatchPriority = _hospitalDispatchSortWeight(
        right,
      ).compareTo(_hospitalDispatchSortWeight(left));
      if (dispatchPriority != 0) {
        return dispatchPriority;
      }
      final severityCompare = _impactLevel(right).compareTo(_impactLevel(left));
      if (severityCompare != 0) {
        return severityCompare;
      }
      return AppRepository.parseTimestamp(
        right['timestamp'],
      ).compareTo(AppRepository.parseTimestamp(left['timestamp']));
    });
    return items;
  }

  Map<String, dynamic>? _firstPendingHospitalDispatchAlert(
    List<Map<String, dynamic>> alerts,
  ) {
    for (final alert in alerts) {
      final alertId = _alertId(alert);
      if (alertId.isEmpty ||
          alertId == _activeAlertId ||
          _hiddenAlertIds.contains(alertId)) {
        continue;
      }
      if (_isHospitalDispatchPending(alert)) {
        return alert;
      }
    }
    return null;
  }

  bool _isHospitalDispatchPending(Map<String, dynamic> alert) {
    final dispatchRequested = alert['driver_dispatch_requested'] == true;
    final dispatchStatus =
        alert['driver_dispatch_status']?.toString().toLowerCase() ?? '';
    final level = _impactLevel(alert);
    return level >= 4 &&
        dispatchRequested &&
        (dispatchStatus.isEmpty || dispatchStatus == 'pending');
  }

  int _hospitalDispatchSortWeight(Map<String, dynamic> alert) {
    if (_isHospitalDispatchPending(alert)) {
      return 2;
    }
    final dispatchStatus =
        alert['driver_dispatch_status']?.toString().toLowerCase() ?? '';
    if (dispatchStatus == 'accepted' || dispatchStatus == 'arrived') {
      return 1;
    }
    return 0;
  }

  List<Map<String, dynamic>> _filterNearbyAlerts(
    List<Map<String, dynamic>> alerts,
  ) {
    if (_currentPosition == null) {
      return alerts;
    }

    final nearby = alerts
        .where((alert) {
          final lat = (alert['latitude'] as num?)?.toDouble();
          final lng = (alert['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) {
            return true;
          }

          final meters = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            lat,
            lng,
          );
          return meters <= 10000;
        })
        .toList(growable: false);

    return nearby;
  }

  List<Map<String, dynamic>> _filteredLogAlerts(
    List<Map<String, dynamic>> alerts,
  ) {
    final selectedDate = _selectedLogDate;
    if (selectedDate == null) {
      return alerts;
    }

    return alerts
        .where((alert) {
          final timestamp = AppRepository.parseTimestamp(alert['timestamp']);
          return _isSameDate(timestamp, selectedDate);
        })
        .toList(growable: false);
  }

  List<String> _alertIds(List<Map<String, dynamic>> alerts) {
    return alerts
        .map(_alertId)
        .where((id) => id.trim().isNotEmpty)
        .toList(growable: false);
  }

  bool _isRealFeedAlert(Map<String, dynamic> alert) {
    final alertId = _alertId(alert);
    final userId = alert['user_id']?.toString().trim() ?? '';
    final timestamp = alert['timestamp']?.toString().trim() ?? '';
    final source = alert['source']?.toString().toLowerCase() ?? '';
    final type = alert['type']?.toString().toLowerCase() ?? '';
    final sourceDetail = alert['source_detail']?.toString().toLowerCase() ?? '';

    final hasEvAlertSource =
        source == 'sensor' ||
        source == 'button' ||
        type == 'auto' ||
        type == 'manual' ||
        sourceDetail.contains('accelerometer') ||
        sourceDetail.contains('manual') ||
        sourceDetail.contains('impact');

    return alertId.isNotEmpty &&
        userId.isNotEmpty &&
        timestamp.isNotEmpty &&
        hasEvAlertSource;
  }

  Map<String, dynamic>? _resolveActiveAlert(List<Map<String, dynamic>> alerts) {
    if (_activeAlertId == null) {
      for (final alert in alerts) {
        final status = alert['status']?.toString().toLowerCase() ?? '';
        if (status.contains('en route') || status.contains('arrived')) {
          _activeAlertId = _alertId(alert);
          _activeCaseStatus = status.contains('arrived')
              ? 'Arrived'
              : 'En Route';
          return alert;
        }
      }
      return null;
    }

    for (final alert in alerts) {
      if (_alertId(alert) == _activeAlertId) {
        return alert;
      }
    }
    return null;
  }

  int _impactLevel(Map<String, dynamic> alert) {
    return ((alert['impact_level'] ?? 1) as num).toInt().clamp(1, 5);
  }

  _AlertPalette _paletteFor(int level) {
    if (level >= 5) {
      return const _AlertPalette(
        primary: Color(0xFFE53935),
        border: Color(0xFFFFB7B2),
        soft: Color(0xFFFFE4E1),
      );
    }
    if (level >= 4) {
      return const _AlertPalette(
        primary: Color(0xFFF39C12),
        border: Color(0xFFFFD36E),
        soft: Color(0xFFFFF2D6),
      );
    }
    if (level >= 3) {
      return const _AlertPalette(
        primary: Color(0xFFF4A62A),
        border: Color(0xFFFFDF96),
        soft: Color(0xFFFFF4DD),
      );
    }
    return const _AlertPalette(
      primary: Color(0xFF67A954),
      border: Color(0xFFD8E9D1),
      soft: Color(0xFFE9F4E5),
    );
  }

  String _severityHeadline(int level) {
    if (level >= 5) {
      return 'LEVEL 5 - CRITICAL';
    }
    if (level >= 4) {
      return 'LEVEL 4 Accident';
    }
    if (level >= 3) {
      return 'LEVEL 3 Accident';
    }
    return 'LEVEL 1-2 Accident';
  }

  String _headlineText(Map<String, dynamic> alert) {
    final vehicleStatus = alert['vehicle_status']?.toString().trim() ?? '';
    if (vehicleStatus.isNotEmpty) {
      return vehicleStatus;
    }

    final vehicleCondition =
        alert['vehicle_condition']?.toString().trim() ?? '';
    if (vehicleCondition.isNotEmpty) {
      return vehicleCondition;
    }

    final title = alert['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }

    final description = alert['incident_description']?.toString().trim() ?? '';
    if (description.isNotEmpty) {
      return description;
    }

    return AppRepository.severityExplanation(_impactLevel(alert));
  }

  bool _isAutomatic(Map<String, dynamic> alert) {
    final values = [
      alert['type'],
      alert['alert_type'],
      alert['source'],
      alert['alert_source'],
    ].whereType<Object>().map((value) => value.toString().toLowerCase());

    for (final item in values) {
      if (item.contains('auto') ||
          item.contains('sensor') ||
          item.contains('accelerometer')) {
        return true;
      }
    }

    return false;
  }

  String _sourceLabel(Map<String, dynamic> alert) {
    final sourceDetail = alert['source_detail']?.toString().trim() ?? '';
    final mode = _isAutomatic(alert) ? 'Auto detection' : 'Manual report';
    final relativeTime = _relativeTime(alert['timestamp']);

    if (sourceDetail.isEmpty) {
      return '$relativeTime - $mode';
    }
    return '$relativeTime - $mode - $sourceDetail';
  }

  String _locationText(Map<String, dynamic> alert) {
    final locationName = alert['location_name']?.toString().trim() ?? '';
    final roadName = alert['road_name']?.toString().trim() ?? '';
    if (locationName.isEmpty && roadName.isEmpty) {
      return 'Unknown location';
    }
    if (locationName.isEmpty) {
      return roadName;
    }
    if (roadName.isEmpty) {
      return locationName;
    }
    return '$locationName - $roadName';
  }

  String _personName(Map<String, dynamic> alert) {
    final name =
        alert['user_name']?.toString().trim() ??
        alert['driver']?.toString().trim() ??
        alert['name']?.toString().trim() ??
        '';
    final vehicle = alert['vehicle']?.toString().trim() ?? '';
    final userId = alert['user_id']?.toString().trim() ?? '';

    final resolvedName = name.isEmpty ? 'Unknown user' : name;
    final suffix = vehicle.isNotEmpty
        ? vehicle
        : userId.isNotEmpty
        ? 'ID $userId'
        : '';

    return suffix.isEmpty ? resolvedName : '$resolvedName - $suffix';
  }

  String _phoneText(Map<String, dynamic> alert) {
    return alert['phone']?.toString().trim() ??
        alert['contact_number']?.toString().trim() ??
        alert['driver_phone']?.toString().trim() ??
        alert['user_phone']?.toString().trim() ??
        '';
  }

  String _alertId(Map<String, dynamic> alert) {
    return alert['alert_id']?.toString() ?? alert['id']?.toString() ?? '';
  }

  String _relativeTime(Object? value) {
    final date = AppRepository.parseTimestamp(value).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) {
      return 'Just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  String _estimatedEta(int level) {
    final minutes = (12 - (level * 2)).clamp(4, 10);
    return '$minutes mins';
  }

  String _formatClockTime(DateTime value) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute$suffix';
  }

  bool _isSameDate(DateTime left, DateTime right) {
    final localLeft = left.toLocal();
    final localRight = right.toLocal();
    return localLeft.year == localRight.year &&
        localLeft.month == localRight.month &&
        localLeft.day == localRight.day;
  }

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _dateTimeLabel(Object? value) {
    final local = AppRepository.parseTimestamp(value).toLocal();
    return '${_dateLabel(local)} ${_formatClockTime(local)}';
  }

  Map<String, dynamic>? _nearestHospitalForAlert(Map<String, dynamic> alert) {
    final latitude =
        (alert['latitude'] as num?)?.toDouble() ?? _currentPosition?.latitude;
    final longitude =
        (alert['longitude'] as num?)?.toDouble() ?? _currentPosition?.longitude;
    if (latitude == null || longitude == null) {
      return AssistDirectory.healthProviders.isEmpty
          ? null
          : AssistDirectory.healthProviders.first;
    }

    return AssistDirectory.nearestProvider(
      AssistDirectory.healthProviders,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      tooltip: 'Refresh emergency feed',
      onPressed: _isRefreshing ? null : _refreshDashboard,
      icon: _isRefreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(_brandGreen),
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 22, color: _brandGreen),
    );
  }

  String? _impactMagnitudeLabel(Map<String, dynamic> alert) {
    final magnitude = (alert['acceleration_magnitude'] as num?)?.toDouble();
    if (magnitude == null) {
      return null;
    }
    return '${magnitude.toStringAsFixed(1)} m/s2 impact';
  }

  String _statusLabel(Map<String, dynamic> alert) {
    return alert['status']?.toString().trim() ?? '';
  }

  void _toggleResponderAvailability(bool value) {
    setState(() {
      _isResponderAvailable = value;
      _latestUpdate = _isResponderAvailable
          ? 'Responder is available for the next emergency alert.'
          : 'Responder availability is turned off for now.';
    });
  }
}

class _AlertPalette {
  const _AlertPalette({
    required this.primary,
    required this.border,
    required this.soft,
  });

  final Color primary;
  final Color border;
  final Color soft;
}
