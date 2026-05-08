import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'gemini_service.dart';

class AppRepository {
  AppRepository._();

  static const String databaseUrl =
      'https://evsmart-2694c-default-rtdb.asia-southeast1.firebasedatabase.app';

  static final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: databaseUrl,
  );

  static DatabaseReference get root => _database.ref();
  static DatabaseReference get usersRef => root.child('users');
  static DatabaseReference get legacyUsersRef => root.child('Users');
  static DatabaseReference get vehiclesRef => root.child('vehicles');
  static DatabaseReference get alertsRef => root.child('alerts');
  static DatabaseReference get notificationsRef => root.child('notifications');
  static DatabaseReference get ambulanceProfilesRef =>
      root.child('ambulance_profiles');
  static DatabaseReference get technicianProfilesRef =>
      root.child('technician_profiles');
  static DatabaseReference get chargingStationsRef =>
      root.child('charging_stations');
  static DatabaseReference get accidentReportsRef =>
      root.child('accident_reports');
  static DatabaseReference get messageThreadsRef =>
      root.child('message_threads');
  static DatabaseReference get messageBadgesRef => root.child('message_badges');

  static String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final uid = currentUserId;
    if (uid == null) {
      return null;
    }

    final snapshot = await usersRef.child(uid).get();
    if (snapshot.exists) {
      return _readMap(snapshot.value);
    }

    final legacySnapshot = await legacyUsersRef.child(uid).get();
    if (legacySnapshot.exists) {
      final data = _readMap(legacySnapshot.value);
      if (data != null) {
        await usersRef.child(uid).set(data);
      }
      return data;
    }

    return null;
  }

  static Future<Map<String, dynamic>?> getProfileByPath(
    DatabaseReference reference,
    String uid,
  ) async {
    final snapshot = await reference.child(uid).get();
    return snapshot.exists ? _readMap(snapshot.value) : null;
  }

  static Future<Map<String, dynamic>?> getCurrentVehicle() async {
    final uid = currentUserId;
    if (uid == null) {
      return null;
    }

    final snapshot = await vehiclesRef.child(uid).get();
    return snapshot.exists ? _readMap(snapshot.value) : null;
  }

  static Future<Map<String, dynamic>> getCurrentUserRewards() async {
    final uid = currentUserId;
    if (uid == null) {
      return <String, dynamic>{};
    }

    final snapshot = await usersRef.child(uid).get();
    if (!snapshot.exists) {
      return <String, dynamic>{};
    }

    final data = _readMap(snapshot.value) ?? <String, dynamic>{};
    final rewards = _readMap(data['rewards']) ?? <String, dynamic>{};

    return <String, dynamic>{
      'points': data['points'] ?? rewards['points'],
      'checkIn':
          _readMap(data['checkIn']) ??
          _readMap(rewards['checkIn']) ??
          <String, dynamic>{},
      'missions':
          _readMap(data['missions']) ??
          _readMap(rewards['missions']) ??
          <String, dynamic>{},
      'stats':
          _readMap(data['stats']) ??
          _readMap(rewards['stats']) ??
          <String, dynamic>{},
    };
  }

  static Future<void> upsertCurrentUserRewards({
    int? points,
    Map<String, dynamic>? checkIn,
    Map<String, dynamic>? missions,
    Map<String, dynamic>? stats,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      return;
    }

    final updates = <String, Object?>{};

    void addNestedUpdates(String rootKey, Map<String, dynamic>? values) {
      if (values == null) {
        return;
      }
      for (final entry in values.entries) {
        updates['$rootKey/${entry.key}'] = entry.value;
        updates['rewards/$rootKey/${entry.key}'] = entry.value;
      }
    }

    if (points != null) {
      updates['points'] = points;
      updates['rewards/points'] = points;
    }
    addNestedUpdates('checkIn', checkIn);
    addNestedUpdates('missions', missions);
    addNestedUpdates('stats', stats);

    if (updates.isEmpty) {
      return;
    }

    await Future.wait([
      usersRef.child(uid).update(updates),
      legacyUsersRef.child(uid).update(updates),
    ]);
  }

  static Future<List<Map<String, dynamic>>> getCurrentUserAlerts() async {
    final uid = currentUserId;
    if (uid == null) {
      return <Map<String, dynamic>>[];
    }

    final snapshot = await alertsRef.get();
    return _snapshotList(
      snapshot,
    ).where((item) => item['user_id'] == uid).toList()..sort(
      (a, b) => _parseTimestamp(
        b['timestamp'],
      ).compareTo(_parseTimestamp(a['timestamp'])),
    );
  }

  static Future<List<Map<String, dynamic>>> getCurrentUserNotifications({
    String? type,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      return <Map<String, dynamic>>[];
    }

    final snapshot = await notificationsRef.get();
    return _snapshotList(snapshot)
        .map((item) {
          if (item['type']?.toString() == 'Reward') {
            item['type'] = 'Rewards';
          }
          return item;
        })
        .where((item) {
          final audience = item['audience'];
          final itemUserId = item['user_id'];
          final typeMatches = type == null || item['type'] == type;
          return typeMatches &&
              (itemUserId == null || itemUserId == uid || audience == 'all');
        })
        .toList()
      ..sort(
        (a, b) => _parseTimestamp(
          b['timestamp'],
        ).compareTo(_parseTimestamp(a['timestamp'])),
      );
  }

  static Future<bool> queueDailyCheckInReminderIfNeeded({
    required DateTime now,
    String? lastCheckInDate,
    String? reminderSentDate,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      return false;
    }

    final todayKey = _dateOnlyString(now);
    if (now.hour < 20 ||
        lastCheckInDate == todayKey ||
        reminderSentDate == todayKey) {
      return false;
    }

    await _pushNotification(
      audience: 'driver',
      userId: uid,
      type: 'Rewards',
      title: 'Daily check-in reminder',
      message: "Don't forget your daily check-in!",
      alertId: 'rewards_check_in_$todayKey',
    );

    await upsertCurrentUserRewards(checkIn: {'reminderSentDate': todayKey});

    return true;
  }

  static Future<void> logRewardNotification({
    required String title,
    required String message,
    required int pointsDelta,
    String? rewardKind,
    DateTime? timestamp,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      return;
    }

    final occurredAt = timestamp ?? DateTime.now();
    final rewardId = 'reward_${occurredAt.microsecondsSinceEpoch}';

    await _pushNotification(
      audience: 'driver',
      userId: uid,
      type: 'Rewards',
      title: title,
      message: message,
      alertId: rewardId,
      timestamp: occurredAt,
      extraData: {
        'points_delta': pointsDelta,
        'reward_kind': rewardKind ?? title.toLowerCase().replaceAll(' ', '_'),
      },
    );
  }

  static Future<void> upsertUserProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await Future.wait([
      usersRef.child(uid).update(data),
      legacyUsersRef.child(uid).update(data),
    ]);
  }

  static Future<void> upsertVehicle(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await vehiclesRef.child(uid).update(data);
  }

  static Future<void> upsertAmbulanceProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await ambulanceProfilesRef.child(uid).update(data);
  }

  static Future<void> upsertTechnicianProfile(
    String uid,
    Map<String, dynamic> data,
  ) async {
    await technicianProfilesRef.child(uid).update(data);
  }

  static Future<void> upsertNotificationToken(
    String uid,
    String token, {
    bool? notificationsEnabled,
  }) async {
    final payload = <String, dynamic>{
      'notification_token': token,
      'notification_token_updated_at': DateTime.now().toIso8601String(),
      ...notificationsEnabled == null
          ? const <String, dynamic>{}
          : {'notifications_enabled': notificationsEnabled},
    };

    await Future.wait([
      usersRef.child(uid).update(payload),
      legacyUsersRef.child(uid).update(payload),
    ]);

    if (uid != currentUserId) {
      return;
    }

    final profile = await getCurrentUserProfile() ?? <String, dynamic>{};
    final role = profile['role']?.toString().toLowerCase() ?? '';

    if (role.contains('ambulance') || role.contains('hospital')) {
      await ambulanceProfilesRef.child(uid).update(payload);
    } else if (role.contains('technician') ||
        role.contains('mechanic') ||
        role.contains('tow')) {
      await technicianProfilesRef.child(uid).update(payload);
    }
  }

  static Future<void> ensureChargingStations() async {
    final snapshot = await chargingStationsRef.get();
    if (snapshot.exists && snapshot.children.isNotEmpty) {
      return;
    }

    final batch = <String, Map<String, dynamic>>{};
    for (final station in _seedStations) {
      batch[station['id'] as String] = station;
    }
    await chargingStationsRef.set(batch);
  }

  static Stream<List<Map<String, dynamic>>> streamAlerts() {
    return alertsRef.onValue.map((event) {
      return _snapshotList(event.snapshot)..sort(
        (a, b) => _parseTimestamp(
          b['timestamp'],
        ).compareTo(_parseTimestamp(a['timestamp'])),
      );
    });
  }

  static Stream<List<Map<String, dynamic>>> streamAmbulanceProfiles() {
    return ambulanceProfilesRef.onValue.map((event) {
      return _snapshotList(event.snapshot);
    });
  }

  static Stream<List<Map<String, dynamic>>> streamNotifications({
    String? userId,
  }) {
    final targetUserId = userId ?? currentUserId;
    return notificationsRef.onValue.map((event) {
      final items = _snapshotList(event.snapshot)
        ..forEach((item) {
          if (item['type']?.toString() == 'Reward') {
            item['type'] = 'Rewards';
          }
        })
        ..sort(
          (a, b) => _parseTimestamp(
            b['timestamp'],
          ).compareTo(_parseTimestamp(a['timestamp'])),
        );
      if (targetUserId == null) {
        return items;
      }
      return items.where((item) {
        final audience = item['audience'];
        final itemUserId = item['user_id'];
        return itemUserId == null ||
            itemUserId == targetUserId ||
            audience == 'all';
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> streamChargingStations() {
    return chargingStationsRef.onValue.map((event) {
      return _snapshotList(event.snapshot);
    });
  }

  static Stream<List<Map<String, dynamic>>> streamUserConversations({
    String? userId,
  }) {
    final targetUserId = userId ?? currentUserId;
    return messageThreadsRef.onValue.map((event) {
      final items = _snapshotList(event.snapshot)
        ..sort(
          (a, b) => _parseTimestamp(
            b['updated_at'],
          ).compareTo(_parseTimestamp(a['updated_at'])),
        );
      if (targetUserId == null) {
        return <Map<String, dynamic>>[];
      }
      return items.where((item) {
        return item['user_id'] == targetUserId &&
            item['hidden_for_driver'] != true;
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> streamRoleConversations(
    String role,
  ) {
    return messageThreadsRef.onValue.map((event) {
      final items = _snapshotList(event.snapshot)
        ..sort(
          (a, b) => _parseTimestamp(
            b['updated_at'],
          ).compareTo(_parseTimestamp(a['updated_at'])),
        );
      return items.where((item) {
        return item['responder_role'] == role &&
            item['hidden_for_${role.toLowerCase()}'] != true;
      }).toList();
    });
  }

  static Stream<List<Map<String, dynamic>>> streamConversationMessages(
    String threadId,
  ) {
    return messageThreadsRef.child(threadId).child('messages').onValue.map((
      event,
    ) {
      final items = _snapshotList(event.snapshot)
        ..sort(
          (a, b) => _parseTimestamp(
            a['timestamp'],
          ).compareTo(_parseTimestamp(b['timestamp'])),
        );
      return items;
    });
  }

  static Future<String> startAssistanceConversation({
    required String responderRole,
    required String responderName,
    required String responderPhone,
    required String locationName,
    required String issueLabel,
    String? responderId,
    bool autoDispatch = false,
    String? initialMessage,
  }) async {
    final uid = currentUserId ?? 'guest_driver';
    final userProfile = await getCurrentUserProfile() ?? <String, dynamic>{};
    final vehicle = await getCurrentVehicle() ?? <String, dynamic>{};
    final driverName =
        userProfile['fullName']?.toString() ??
        userProfile['username']?.toString() ??
        'EV Driver';
    final vehicleLabel = _vehicleLabel(userProfile, vehicle);
    final nowIso = DateTime.now().toIso8601String();
    final snapshot = await messageThreadsRef.get();
    final existingThreads = _snapshotList(snapshot);

    Map<String, dynamic>? existingThread;
    for (final thread in existingThreads) {
      final sameUser = thread['user_id'] == uid;
      final sameRole = thread['responder_role'] == responderRole;
      final sameResponder = responderId == null
          ? thread['responder_name'] == responderName
          : thread['responder_id'] == responderId;
      final isActive = thread['status']?.toString().toLowerCase() != 'closed';
      if (sameUser && sameRole && sameResponder && isActive) {
        existingThread = thread;
        break;
      }
    }

    final threadRef = existingThread == null
        ? messageThreadsRef.push()
        : messageThreadsRef.child(existingThread['thread_id'].toString());
    final threadId =
        existingThread?['thread_id']?.toString() ?? threadRef.key ?? '';

    final threadData = <String, dynamic>{
      'thread_id': threadId,
      'user_id': uid,
      'driver_name': driverName,
      'vehicle': vehicleLabel,
      'responder_role': responderRole,
      'responder_role_label': roleLabel(responderRole),
      'responder_id': responderId ?? responderRole,
      'responder_name': responderName,
      'responder_phone': responderPhone,
      'location_name': locationName,
      'issue_label': issueLabel,
      'status': 'active',
      'auto_dispatch': autoDispatch,
      'updated_at': nowIso,
      if (existingThread == null) 'created_at': nowIso,
    };

    await threadRef.update(threadData);

    if (existingThread == null) {
      await _appendConversationMessage(
        threadId: threadId,
        senderId: 'system',
        senderName: 'EVSmart+',
        senderRole: 'system',
        text: autoDispatch
            ? 'Automatic emergency dispatch is active. You can still message $responderName for manual coordination.'
            : 'You are now connected with $responderName.',
      );

      if (responderRole == 'technician') {
        await _appendConversationMessage(
          threadId: threadId,
          senderId: responderId ?? 'nearby_technician_bot',
          senderName: responderName,
          senderRole: 'technician',
          text:
              'Hi, this is $responderName roadside support. We are near $locationName and ready to help with EV battery, tire, brake, towing, or impact issues. Tell me what happened, whether the EV can still move, if any warning light is showing, and send a vehicle photo so I can guide the right next step.',
        );
      } else if (responderRole == 'hospital') {
        await _appendConversationMessage(
          threadId: threadId,
          senderId: responderId ?? 'nearby_hospital_bot',
          senderName: responderName,
          senderRole: 'hospital',
          text:
              'Hello, this is $responderName emergency triage. I can help check the situation near $locationName. Are you safe right now? Please tell me if anyone is injured, how many people are inside the EV, whether there is smoke/fire, and send a photo of the vehicle or accident area if it is safe to do so.',
        );
      }
    }

    if (responderRole == 'technician') {
      await pushDashboardNotification(
        audience: 'insurance',
        type: 'Support',
        title: 'Technician support requested',
        message:
            '$driverName contacted $responderName near $locationName for EV roadside help.',
        alertId: threadId,
        userId: uid,
        extraData: {'thread_id': threadId, 'support_role': 'technician'},
      );
    } else if (responderRole == 'hospital') {
      await pushDashboardNotification(
        audience: 'hospital',
        type: 'Message',
        title: 'Hospital assist requested',
        message:
            '$driverName contacted $responderName near $locationName for emergency guidance.',
        alertId: threadId,
        userId: uid,
        extraData: {'thread_id': threadId, 'support_role': 'hospital'},
      );
    }

    final trimmedMessage = initialMessage?.trim() ?? '';
    if (trimmedMessage.isNotEmpty) {
      await sendConversationMessage(
        threadId: threadId,
        senderRole: 'driver',
        senderName: driverName,
        text: trimmedMessage,
      );
    }

    return threadId;
  }

  static Future<Map<String, dynamic>> ensureResponderConversationFromAlert({
    required String responderRole,
    required Map<String, dynamic> alert,
    String? initialMessage,
  }) async {
    final responderUid = currentUserId ?? responderRole;
    final responderProfile = responderRole == 'hospital'
        ? await getProfileByPath(ambulanceProfilesRef, responderUid)
        : await getProfileByPath(technicianProfilesRef, responderUid);
    final profileData = responderProfile ?? const <String, dynamic>{};
    final responderName = responderRole == 'hospital'
        ? profileData['driver_name']?.toString() ??
              profileData['hospital_name']?.toString() ??
              'Ambulance Driver'
        : profileData['technician_name']?.toString() ??
              profileData['company_name']?.toString() ??
              'EV Technician';
    final responderPhone = responderRole == 'hospital'
        ? profileData['phone']?.toString() ??
              profileData['contact']?.toString() ??
              'Not provided'
        : profileData['phone']?.toString() ??
              profileData['contact_number']?.toString() ??
              'Not provided';
    final userId = alert['user_id']?.toString() ?? 'guest_driver';
    final driverName = alert['driver']?.toString() ?? 'EV Driver';
    final vehicle = alert['vehicle']?.toString() ?? 'EV Vehicle';
    final locationName =
        alert['location_name']?.toString() ?? 'Unknown location';
    final issueLabel = alert['impact_label']?.toString() ?? 'Incident support';
    final alertId = alert['alert_id']?.toString() ?? '';
    final nowIso = DateTime.now().toIso8601String();
    final snapshot = await messageThreadsRef.get();
    final existingThreads = _snapshotList(snapshot);

    Map<String, dynamic>? existingThread;
    for (final thread in existingThreads) {
      final sameUser = thread['user_id'] == userId;
      final sameRole = thread['responder_role'] == responderRole;
      final sameResponder = thread['responder_id'] == responderUid;
      final sameAlert = alertId.isNotEmpty && thread['alert_id'] == alertId;
      final isActive = thread['status']?.toString().toLowerCase() != 'closed';
      if (sameUser && sameRole && sameResponder && sameAlert && isActive) {
        existingThread = thread;
        break;
      }
    }

    final threadRef = existingThread == null
        ? messageThreadsRef.push()
        : messageThreadsRef.child(existingThread['thread_id'].toString());
    final threadId =
        existingThread?['thread_id']?.toString() ?? threadRef.key ?? '';

    final threadData = <String, dynamic>{
      'thread_id': threadId,
      'alert_id': alertId,
      'user_id': userId,
      'driver_name': driverName,
      'vehicle': vehicle,
      'responder_role': responderRole,
      'responder_role_label': roleLabel(responderRole),
      'responder_id': responderUid,
      'responder_name': responderName,
      'responder_phone': responderPhone,
      'location_name': locationName,
      'issue_label': issueLabel,
      'status': 'active',
      'auto_dispatch': alert['emergency_triggered'] == true,
      'updated_at': nowIso,
      if (existingThread == null) 'created_at': nowIso,
    };

    await threadRef.update(threadData);

    if (existingThread == null) {
      await _appendConversationMessage(
        threadId: threadId,
        senderId: 'system',
        senderName: 'EVSmart+',
        senderRole: 'system',
        text:
            '${roleLabel(responderRole)} opened this case from the alert dashboard.',
      );
    }

    final trimmedMessage = initialMessage?.trim() ?? '';
    if (trimmedMessage.isNotEmpty) {
      await sendConversationMessage(
        threadId: threadId,
        senderRole: responderRole,
        senderName: responderName,
        text: trimmedMessage,
      );
    }

    final refreshedSnapshot = await messageThreadsRef.child(threadId).get();
    return _readMap(refreshedSnapshot.value) ?? threadData;
  }

  static Future<void> sendConversationMessage({
    required String threadId,
    required String senderRole,
    required String senderName,
    required String text,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final senderId = currentUserId ?? senderRole;
    await _appendConversationMessage(
      threadId: threadId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: trimmedText,
    );

    final threadSnapshot = await messageThreadsRef.child(threadId).get();
    final thread = _readMap(threadSnapshot.value);
    if (thread == null) {
      return;
    }

    if (senderRole == 'driver') {
      unawaited(
        _incrementUnreadBadge(
          thread['responder_role']?.toString() ?? 'support',
        ),
      );
      unawaited(
        _pushNotification(
          audience: thread['responder_role']?.toString() ?? 'support',
          type: 'Message',
          title: 'New driver message',
          message:
              '${thread['driver_name']?.toString() ?? 'Driver'}: $trimmedText',
          alertId: threadId,
        ),
      );

      await _maybeSendAutomatedResponderReply(
        thread: thread,
        driverMessage: trimmedText,
        imageShared: false,
      );
      await _logSupportConversationUpdate(
        thread: thread,
        detail: 'user sent message inquiry',
      );
      return;
    }

    unawaited(
      _incrementUnreadBadge('driver', userId: thread['user_id']?.toString()),
    );
    unawaited(
      _pushNotification(
        audience: 'driver',
        userId: thread['user_id']?.toString(),
        type: 'Message',
        title:
            'Reply from ${thread['responder_name']?.toString() ?? 'support'}',
        message: trimmedText,
        alertId: threadId,
      ),
    );
  }

  static Future<void> sendConversationImage({
    required String threadId,
    required String senderRole,
    required String senderName,
    required String imageBase64,
    String? caption,
    String imageMimeType = 'image/jpeg',
  }) async {
    if (imageBase64.trim().isEmpty) {
      return;
    }

    final senderId = currentUserId ?? senderRole;
    final trimmedCaption = caption?.trim() ?? '';
    await _appendConversationMessage(
      threadId: threadId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      text: trimmedCaption,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );

    final threadSnapshot = await messageThreadsRef.child(threadId).get();
    final thread = _readMap(threadSnapshot.value);
    if (thread == null) {
      return;
    }

    if (senderRole == 'driver') {
      unawaited(
        _incrementUnreadBadge(
          thread['responder_role']?.toString() ?? 'support',
        ),
      );
      unawaited(
        _pushNotification(
          audience: thread['responder_role']?.toString() ?? 'support',
          type: 'Message',
          title: 'Driver shared a vehicle photo',
          message:
              '${thread['driver_name']?.toString() ?? 'Driver'} shared a vehicle-condition photo.',
          alertId: threadId,
        ),
      );
      await _maybeSendAutomatedResponderReply(
        thread: thread,
        driverMessage: trimmedCaption,
        imageShared: true,
        imageBase64: imageBase64,
        imageMimeType: imageMimeType,
      );
      await _logSupportConversationUpdate(
        thread: thread,
        detail: 'car condition image submitted',
      );
      return;
    }

    unawaited(
      _incrementUnreadBadge('driver', userId: thread['user_id']?.toString()),
    );
    unawaited(
      _pushNotification(
        audience: 'driver',
        userId: thread['user_id']?.toString(),
        type: 'Message',
        title:
            'Image from ${thread['responder_name']?.toString() ?? 'support'}',
        message: trimmedCaption.isEmpty
            ? 'A new image was added to the conversation.'
            : trimmedCaption,
        alertId: threadId,
      ),
    );
  }

  static Future<void> deleteConversationThread(String threadId) async {
    if (threadId.trim().isEmpty) {
      return;
    }
    await messageThreadsRef.child(threadId).remove();
  }

  static Future<void> deleteConversationMessages(
    String threadId,
    List<String> messageIds,
  ) async {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) {
      return;
    }

    final threadRef = messageThreadsRef.child(threadId);
    final messagesRef = threadRef.child('messages');
    await Future.wait(ids.map((id) => messagesRef.child(id).remove()));

    final remainingSnapshot = await messagesRef.get();
    final remainingMessages = _snapshotList(remainingSnapshot)
      ..sort(
        (a, b) => _parseTimestamp(
          a['timestamp'],
        ).compareTo(_parseTimestamp(b['timestamp'])),
      );

    if (remainingMessages.isEmpty) {
      await threadRef.remove();
      return;
    }

    final lastMessage = remainingMessages.last;
    await threadRef.update({
      'last_message': _messagePreview(lastMessage),
      'last_sender_role': lastMessage['sender_role']?.toString() ?? '',
      'updated_at':
          lastMessage['timestamp']?.toString() ??
          DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>> createAlert({
    required int impactLevel,
    required String vehicleStatus,
    required double latitude,
    required double longitude,
    required bool emergencyTriggered,
    required String source,
    String? alertType,
    String? alertSource,
    DateTime? timestamp,
    String? title,
    String? assignedRole,
    double? accelerationMagnitude,
    String? accidentStatus,
    Map<String, dynamic>? extraData,
  }) async {
    final uid = currentUserId ?? 'guest_driver';
    final alertRef = alertsRef.push();
    final alertId = alertRef.key!;
    final occurredAt = timestamp ?? DateTime.now();
    final timestampIso = occurredAt.toIso8601String();
    final userProfile = await getCurrentUserProfile() ?? <String, dynamic>{};
    final vehicle = await getCurrentVehicle() ?? <String, dynamic>{};
    final driverName =
        userProfile['fullName']?.toString() ??
        userProfile['username']?.toString() ??
        'EVSmart Driver';
    final vehicleId =
        vehicle['vehicle_id']?.toString() ??
        userProfile['vehicle_id']?.toString() ??
        uid;
    final locationName = inferLocationName(latitude, longitude);
    final roadName = inferRoadName(latitude, longitude);
    final peopleCount = ((extraData?['number_of_people'] as num?)?.toInt() ?? 1)
        .clamp(1, 9);
    final resolvedType = alertType ?? inferAlertType(source);
    final resolvedSource = alertSource ?? inferAlertSource(source);
    final resolvedSeverity = severityCategory(impactLevel);

    final alertData = <String, dynamic>{
      ...?extraData,
      'alert_id': alertId,
      'user_id': uid,
      'vehicle_id': vehicleId,
      'driver': driverName,
      'vehicle': _vehicleLabel(userProfile, vehicle),
      'impact_level': impactLevel,
      'impact_label': severityLabel(impactLevel),
      'type': resolvedType,
      'severity': resolvedSeverity,
      'severity_explanation': severityExplanation(impactLevel),
      'timestamp': timestampIso,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'road_name': roadName,
      'vehicle_status': vehicleStatus,
      'emergency_triggered': emergencyTriggered,
      'source': resolvedSource,
      'source_detail': source,
      'title': title ?? defaultAlertTitle(impactLevel, emergencyTriggered),
      'status': accidentStatus ?? defaultStatus(emergencyTriggered),
      'assigned_role':
          assignedRole ??
          (impactLevel >= 4 || emergencyTriggered ? 'hospital' : 'technician'),
      'number_of_people': peopleCount,
      'incident_description': incidentDescription(impactLevel, vehicleStatus),
      'recommended_response': recommendedResponse(impactLevel),
      'insurance_status': 'Pending review',
      'notification_synced': true,
      ...?accelerationMagnitude == null
          ? null
          : {'acceleration_magnitude': accelerationMagnitude},
    };

    await alertRef.set(alertData);
    await accidentReportsRef.child(alertId).set(alertData);

    final emergencyMessage =
        'Emergency Alert\n'
        'User: $driverName\n'
        'Location: $locationName - $roadName\n'
        'Severity: ${severityLabel(impactLevel)}\n'
        'Time: $timestampIso\n\n'
        'Emergency services are being notified.';

    await _pushNotification(
      audience: 'driver',
      userId: uid,
      type: emergencyTriggered ? 'Alert' : 'System',
      title: alertData['title'].toString(),
      message: emergencyTriggered
          ? emergencyMessage
          : '${severityLabel(impactLevel)} recorded at $locationName and synced to EVSmart+.',
      alertId: alertId,
    );

    if (impactLevel >= 4 || emergencyTriggered) {
      await _pushNotification(
        audience: 'emergency_contact',
        type: 'Alert',
        title: 'Emergency Alert',
        message: emergencyMessage,
        alertId: alertId,
      );
      await _pushNotification(
        audience: 'hospital',
        type: 'Alert',
        title: 'Emergency Alert',
        message: emergencyMessage,
        alertId: alertId,
      );
    }

    await _pushNotification(
      audience: 'insurance',
      type: 'Alert',
      title: 'Insurance analytics updated',
      message: '$locationName logged with ${severityLabel(impactLevel)}.',
      alertId: alertId,
    );

    return alertData;
  }

  static Future<void> updateAlert(
    String alertId,
    Map<String, dynamic> data,
  ) async {
    await Future.wait([
      alertsRef.child(alertId).update(data),
      accidentReportsRef.child(alertId).update(data),
    ]);
  }

  static Future<void> deleteAlert(String alertId) async {
    await Future.wait([
      alertsRef.child(alertId).remove(),
      accidentReportsRef.child(alertId).remove(),
    ]);
  }

  static Future<void> deleteAlerts(List<String> alertIds) async {
    final ids = alertIds.where((id) => id.trim().isNotEmpty).toSet();
    await Future.wait(ids.map(deleteAlert));
  }

  static Future<void> deleteNotification(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      return;
    }
    await notificationsRef.child(notificationId).remove();
  }

  static Future<void> deleteNotifications(List<String> notificationIds) async {
    final ids = notificationIds.where((id) => id.trim().isNotEmpty).toSet();
    await Future.wait(ids.map(deleteNotification));
  }

  static Future<void> deleteNotificationsByAlertIds(
    List<String> alertIds,
  ) async {
    final ids = alertIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) {
      return;
    }

    final snapshot = await notificationsRef.get();
    final notificationIds = _snapshotList(snapshot)
        .where((item) => ids.contains(item['alert_id']?.toString() ?? ''))
        .map((item) => item['notification_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    await deleteNotifications(notificationIds);
  }

  static Future<int> deleteAlertsOlderThan(int days) async {
    final snapshot = await alertsRef.get();
    final alerts = _snapshotList(snapshot);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final ids = alerts
        .where((alert) => _parseTimestamp(alert['timestamp']).isBefore(cutoff))
        .map((alert) => alert['alert_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    if (ids.isEmpty) {
      return 0;
    }

    await deleteAlerts(ids);
    return ids.length;
  }

  static Future<Map<String, dynamic>> sendManualAlert({
    required int impactLevel,
    required String vehicleStatus,
    required double latitude,
    required double longitude,
    required bool emergencyTriggered,
    String sourceDetail = 'manual_button',
    String? title,
    String? assignedRole,
    double? accelerationMagnitude,
    String? accidentStatus,
    DateTime? timestamp,
    Map<String, dynamic>? extraData,
  }) {
    return createAlert(
      impactLevel: impactLevel,
      vehicleStatus: vehicleStatus,
      latitude: latitude,
      longitude: longitude,
      emergencyTriggered: emergencyTriggered,
      source: sourceDetail,
      alertType: 'manual',
      alertSource: 'button',
      title: title,
      assignedRole: assignedRole,
      accelerationMagnitude: accelerationMagnitude,
      accidentStatus: accidentStatus,
      timestamp: timestamp,
      extraData: extraData,
    );
  }

  static Future<Map<String, dynamic>> sendAutomaticAlert({
    required int impactLevel,
    required String vehicleStatus,
    required double latitude,
    required double longitude,
    required bool emergencyTriggered,
    String sourceDetail = 'accelerometer',
    String? title,
    String? assignedRole,
    double? accelerationMagnitude,
    String? accidentStatus,
    DateTime? timestamp,
    Map<String, dynamic>? extraData,
  }) {
    return createAlert(
      impactLevel: impactLevel,
      vehicleStatus: vehicleStatus,
      latitude: latitude,
      longitude: longitude,
      emergencyTriggered: emergencyTriggered,
      source: sourceDetail,
      alertType: 'auto',
      alertSource: 'sensor',
      title: title,
      assignedRole: assignedRole,
      accelerationMagnitude: accelerationMagnitude,
      accidentStatus: accidentStatus,
      timestamp: timestamp,
      extraData: extraData,
    );
  }

  static Future<void> pushDashboardNotification({
    required String audience,
    required String type,
    required String title,
    required String message,
    String? alertId,
    String? userId,
    DateTime? timestamp,
    Map<String, dynamic>? extraData,
  }) {
    final resolvedAlertId = alertId?.trim().isNotEmpty == true
        ? alertId!.trim()
        : 'dashboard_${DateTime.now().microsecondsSinceEpoch}';

    return _pushNotification(
      audience: audience,
      type: type,
      title: title,
      message: message,
      alertId: resolvedAlertId,
      userId: userId,
      timestamp: timestamp,
      extraData: extraData,
    );
  }

  static Future<void> _pushNotification({
    required String audience,
    required String type,
    required String title,
    required String message,
    required String alertId,
    String? userId,
    DateTime? timestamp,
    Map<String, dynamic>? extraData,
  }) async {
    final ref = notificationsRef.push();
    await ref.set({
      ...?extraData,
      'notification_id': ref.key,
      'alert_id': alertId,
      'user_id': userId,
      'audience': audience,
      'type': type,
      'title': title,
      'message': message,
      'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
    });
  }

  static String defaultAlertTitle(int level, bool emergencyTriggered) {
    return emergencyTriggered
        ? 'Emergency impact detected'
        : 'Impact level $level logged';
  }

  static String inferAlertType(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('manual') ||
        normalized.contains('sos') ||
        normalized.contains('button')) {
      return 'manual';
    }
    return 'auto';
  }

  static String inferAlertSource(String source) {
    final normalized = source.toLowerCase();
    if (normalized.contains('sensor') ||
        normalized.contains('accelerometer') ||
        normalized.contains('impact')) {
      return 'sensor';
    }
    return 'button';
  }

  static String severityCategory(int level) {
    if (level >= 4) {
      return 'high';
    }
    if (level == 3) {
      return 'medium';
    }
    return 'low';
  }

  static String defaultStatus(bool emergencyTriggered) {
    return emergencyTriggered ? 'Awaiting hospital response' : 'Logged';
  }

  static String severityLabel(int level) {
    switch (level) {
      case 1:
        return 'Level 1 - Minor bump';
      case 2:
        return 'Level 2 - Light impact';
      case 3:
        return 'Level 3 - Moderate impact';
      case 4:
        return 'Level 4 - Serious accident';
      case 5:
        return 'Level 5 - Critical accident';
      default:
        return 'Unknown';
    }
  }

  static String severityExplanation(int level) {
    switch (level) {
      case 1:
        return 'A small bump was recorded and should be monitored for minor exterior damage.';
      case 2:
        return 'A light impact was detected. The driver should inspect the vehicle and continue with caution.';
      case 3:
        return 'A moderate impact was detected. Mechanical inspection and incident review are recommended.';
      case 4:
        return 'A serious accident pattern was detected and hospital response should be prepared immediately.';
      case 5:
        return 'A critical accident pattern was detected. Full emergency response is strongly recommended.';
      default:
        return 'Impact severity is unavailable.';
    }
  }

  static String recommendedResponse(int level) {
    switch (level) {
      case 1:
        return 'Log the bump, inspect the vehicle, and continue monitoring.';
      case 2:
        return 'Inspect the driver and vehicle, then schedule technician follow-up.';
      case 3:
        return 'Open the incident details, notify technician support, and review the scene.';
      case 4:
        return 'Hospital users should accept the case, notify the emergency team, and dispatch immediately.';
      case 5:
        return 'Dispatch emergency services, prepare trauma support, and treat the location as high priority.';
      default:
        return 'Review the incident manually.';
    }
  }

  static String incidentDescription(int level, String vehicleStatus) {
    return '${severityLabel(level)} recorded. Vehicle status: $vehicleStatus';
  }

  static String inferLocationName(double latitude, double longitude) {
    const zones = [
      _LocationZone('Shah Alam', 3.0733, 101.5185),
      _LocationZone('Subang Jaya', 3.0738, 101.5853),
      _LocationZone('Federal Highway', 3.0982, 101.5968),
      _LocationZone('PLUS Highway KM 23', 3.0060, 101.4455),
      _LocationZone('Petaling Jaya', 3.1467, 101.6151),
      _LocationZone('Kuala Lumpur', 3.1579, 101.7123),
      _LocationZone('Putrajaya', 2.9694, 101.7137),
      _LocationZone('Cyberjaya', 2.9213, 101.6559),
    ];

    _LocationZone? closest;
    var closestDistance = double.infinity;
    for (final zone in zones) {
      final distance = sqrt(
        pow(zone.latitude - latitude, 2) + pow(zone.longitude - longitude, 2),
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = zone;
      }
    }
    return closest?.name ?? 'Unknown location';
  }

  static String inferRoadName(double latitude, double longitude) {
    switch (inferLocationName(latitude, longitude)) {
      case 'Shah Alam':
        return 'Persiaran Kayangan';
      case 'Subang Jaya':
        return 'Subang Jaya Link';
      case 'Federal Highway':
        return 'Federal Highway';
      case 'PLUS Highway KM 23':
        return 'PLUS Highway KM 23';
      case 'Petaling Jaya':
        return 'Damansara-Puchong Expressway';
      case 'Kuala Lumpur':
        return 'Jalan Tun Razak';
      case 'Putrajaya':
        return 'Persiaran Selatan';
      case 'Cyberjaya':
        return 'Lingkaran Cyber Point';
      default:
        return 'Unknown Road';
    }
  }

  static DateTime parseTimestamp(Object? value) => _parseTimestamp(value);

  static Stream<int> streamUnreadBadgeCount(String role, {String? userId}) {
    final key = unreadBadgeKey(role, userId: userId);
    return messageBadgesRef.child(key).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    });
  }

  static Future<void> markInboxRead(String role, {String? userId}) async {
    final key = unreadBadgeKey(role, userId: userId);
    await messageBadgesRef.child(key).set(0);
  }

  static String unreadBadgeKey(String role, {String? userId}) {
    if (role == 'driver') {
      final id = userId ?? currentUserId ?? 'guest_driver';
      return 'driver_$id';
    }
    if (role == 'hospital') {
      return 'hospital';
    }
    if (role == 'technician') {
      return 'technician';
    }
    return role;
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'hospital':
        return 'Health Assist';
      case 'technician':
        return 'Technician Assist';
      default:
        return 'Support';
    }
  }

  static Map<String, dynamic>? _readMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  static List<Map<String, dynamic>> _snapshotList(DataSnapshot snapshot) {
    if (snapshot.value is! Map) {
      return <Map<String, dynamic>>[];
    }

    final map = snapshot.value as Map<dynamic, dynamic>;
    return map.entries.map((entry) {
      final value = _readMap(entry.value) ?? <String, dynamic>{};
      value.putIfAbsent('id', () => entry.key.toString());
      return value;
    }).toList();
  }

  static DateTime _parseTimestamp(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _dateOnlyString(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  static String _vehicleLabel(
    Map<String, dynamic> profile,
    Map<String, dynamic> vehicle,
  ) {
    final brand =
        vehicle['brand']?.toString() ?? profile['brand']?.toString() ?? '';
    final model =
        vehicle['model']?.toString() ??
        profile['vehicle_model']?.toString() ??
        profile['model']?.toString() ??
        '';
    final plate =
        vehicle['plate']?.toString() ??
        profile['vehicle_plate']?.toString() ??
        profile['plate']?.toString() ??
        '';
    final label = '$brand $model'.trim();
    if (plate.isNotEmpty) {
      return '$label ($plate)'.trim();
    }
    return label.isEmpty ? 'EV Vehicle' : label;
  }

  static Future<void> _appendConversationMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final threadRef = messageThreadsRef.child(threadId);
    final messageRef = threadRef.child('messages').push();
    final nowIso = DateTime.now().toIso8601String();
    final trimmedText = text.trim();

    await messageRef.set({
      'message_id': messageRef.key,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': trimmedText,
      if (imageBase64 != null && imageBase64.trim().isNotEmpty)
        'image_base64': imageBase64,
      if (imageMimeType != null && imageMimeType.trim().isNotEmpty)
        'image_mime_type': imageMimeType,
      'timestamp': nowIso,
    });

    await threadRef.update({
      'last_message': imageBase64 != null && imageBase64.trim().isNotEmpty
          ? (trimmedText.isEmpty
                ? 'Vehicle condition image shared'
                : 'Photo shared: $trimmedText')
          : trimmedText,
      'last_sender_role': senderRole,
      'updated_at': nowIso,
      'hidden_for_driver': false,
      'hidden_for_hospital': false,
      'hidden_for_technician': false,
    });
  }

  static Future<DatabaseReference> _appendTypingMessage({
    required String threadId,
    required String senderId,
    required String senderName,
    required String senderRole,
  }) async {
    final threadRef = messageThreadsRef.child(threadId);
    final messageRef = threadRef.child('messages').push();
    final nowIso = DateTime.now().toIso8601String();

    await messageRef.set({
      'message_id': messageRef.key,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': 'typing...',
      'is_typing': true,
      'timestamp': nowIso,
    });

    await threadRef.update({
      'last_message': 'typing...',
      'last_sender_role': senderRole,
      'updated_at': nowIso,
      'hidden_for_driver': false,
      'hidden_for_hospital': false,
      'hidden_for_technician': false,
    });

    return messageRef;
  }

  static Future<void> _incrementUnreadBadge(
    String role, {
    String? userId,
  }) async {
    final key = unreadBadgeKey(role, userId: userId);
    final badgeRef = messageBadgesRef.child(key);
    final snapshot = await badgeRef.get();
    final current = snapshot.value is num
        ? (snapshot.value as num).toInt()
        : int.tryParse(snapshot.value?.toString() ?? '') ?? 0;
    await badgeRef.set(current + 1);
  }

  static Future<void> _maybeSendAutomatedResponderReply({
    required Map<String, dynamic> thread,
    required String driverMessage,
    required bool imageShared,
    String? imageBase64,
    String imageMimeType = 'image/jpeg',
  }) async {
    final responderRole = thread['responder_role']?.toString();
    final responderId = thread['responder_id']?.toString() ?? '';
    if (responderId.trim().isEmpty) {
      return;
    }

    final isTechnicianBot = responderRole == 'technician';
    final isHospitalAssistBot =
        responderRole == 'hospital' &&
        (thread['alert_id']?.toString().trim().isEmpty ?? true);
    if (!isTechnicianBot && !isHospitalAssistBot) {
      return;
    }

    if (isTechnicianBot) {
      final technicianProfile = await getProfileByPath(
        technicianProfilesRef,
        responderId,
      );
      if (technicianProfile != null) {
        return;
      }
    }

    final ruleReply = isTechnicianBot
        ? _automatedTechnicianReply(
            driverMessage,
            thread,
            imageShared: imageShared,
          )
        : _automatedHospitalReply(
            driverMessage,
            thread,
            imageShared: imageShared,
          );
    final threadId = thread['thread_id']?.toString() ?? '';
    final fallbackName = isTechnicianBot
        ? 'Nearby EV Technician'
        : 'Hospital Emergency Triage';
    final senderName = thread['responder_name']?.toString() ?? fallbackName;

    DatabaseReference? typingRef;
    if (threadId.isNotEmpty) {
      typingRef = await _appendTypingMessage(
        threadId: threadId,
        senderId: responderId,
        senderName: senderName,
        senderRole: responderRole ?? 'support',
      );
    }

    final aiReplyFuture = GeminiService.askSupportGemini(
      responderRole: responderRole ?? 'support',
      responderName: senderName,
      locationName: thread['location_name']?.toString() ?? 'current location',
      driverMessage: driverMessage.trim().isEmpty
          ? (imageShared ? 'Driver shared a vehicle condition photo.' : 'Help')
          : driverMessage,
      imageShared: imageShared,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );
    await Future.delayed(const Duration(seconds: 2));
    final aiReply = await aiReplyFuture;
    await typingRef?.remove();

    final reply = _isWeakAiReply(aiReply) ? ruleReply : aiReply!;
    await _appendConversationMessage(
      threadId: threadId,
      senderId: responderId,
      senderName: senderName,
      senderRole: responderRole ?? 'support',
      text: reply,
    );

    await _pushNotification(
      audience: 'driver',
      userId: thread['user_id']?.toString(),
      type: 'Message',
      title:
          'Reply from ${thread['responder_name']?.toString() ?? fallbackName}',
      message: reply,
      alertId: thread['thread_id']?.toString() ?? '',
    );
  }

  static bool _isWeakAiReply(String? text) {
    final reply = text?.trim().toLowerCase() ?? '';
    if (reply.isEmpty) {
      return true;
    }

    const weakReplies = <String>{
      'noted',
      'okay',
      'ok',
      'alright',
      'yes',
      'yes we can help.',
      'okay sentul',
      'noted.',
      'alright.',
      'ok.',
    };

    if (weakReplies.contains(reply)) {
      return true;
    }

    if ((reply.startsWith('okay ') || reply.startsWith('ok ')) &&
        reply.split(RegExp(r'\s+')).length <= 4) {
      return true;
    }

    if (reply.split(RegExp(r'\s+')).length <= 3) {
      return true;
    }

    return false;
  }

  static String _automatedTechnicianReply(
    String driverMessage,
    Map<String, dynamic> thread, {
    required bool imageShared,
  }) {
    final message = driverMessage.toLowerCase();
    final location = thread['location_name']?.toString() ?? 'your location';
    final workshop =
        thread['responder_name']?.toString() ?? 'Nearby EV Technician';
    final trimmedMessage = driverMessage.trim();
    final looksLikeTypedLocation =
        RegExp(
          r'(jalan|road|street|lorong|parking|level|mall|station|near|opposite|beside|\d{2,})',
          caseSensitive: false,
        ).hasMatch(trimmedMessage) &&
        trimmedMessage.length > 7;

    if (imageShared) {
      return 'Thanks, I received the vehicle photo for your $workshop case near $location. Please stay parked and send one dashboard photo too if any warning is showing. Can the EV still move, or is it fully stuck?';
    }

    if (message == 'yes' ||
        message.contains('yes use my current location') ||
        message.contains('use my current location') ||
        message.contains('current location is correct') ||
        message.contains('that location is correct')) {
      return 'Okay, tow service activated for $location. Dispatching the nearest recovery driver now with ETA about 12 minutes. Please keep your phone nearby.';
    }
    if (message == 'no' ||
        message.contains('wrong location') ||
        message.contains('not correct')) {
      return 'No problem. Send the exact pickup location, nearest landmark, or parking level and I will update the tow request right away.';
    }
    if (looksLikeTypedLocation ||
        message.contains('my location is') ||
        message.contains('i am at') ||
        message.contains('pickup location')) {
      return 'Thanks, I updated the pickup point. Help is on the way now, and the nearest tow driver is being dispatched. Please stay with the EV if it is safe.';
    }
    if (message.contains('not start') ||
        message.contains('won\'t start') ||
        message.contains('cannot start') ||
        message.contains("can't start") ||
        message.contains('car not starting')) {
      return 'Please stop trying to start it for now. Send me a dashboard warning photo if you can, and tell me whether the EV powers on at all or stays fully dead.';
    }
    if (message.contains('battery') || message.contains('charge')) {
      return 'Please stop driving if the EV shows a battery or charging warning. Send me a dashboard photo first, then tell me the battery percentage and whether the car can still shift into Drive.';
    }
    if (message.contains('tire') ||
        message.contains('tyre') ||
        message.contains('wheel')) {
      return 'This sounds like a tire or wheel issue. Park safely, turn on hazard lights, and send a photo of the damaged side. Is the tire flat, or is the rim damaged too?';
    }
    if (message.contains('brake') || message.contains('steering')) {
      return 'Brake or steering problems are high risk, so please keep the EV parked. Send a dashboard photo and tell me if the steering is locked or the brake pedal feels soft.';
    }
    if (message.contains('tow') || message.contains('truck')) {
      return 'Tow service can be activated. I am using your current app location as $location. Is that the correct pickup point? Tap Yes or No below, or send the exact location if it is different.';
    }
    if (message.contains('smoke') ||
        message.contains('burn') ||
        message.contains('fire')) {
      return 'This is $workshop. Smoke, burning smell, or heat near an EV battery is serious. Move away from the vehicle, do not charge it, and do not touch the battery area. If there is visible smoke or fire, contact emergency services first and keep distance.';
    }
    if (message.contains('cannot move') ||
        message.contains("can't move") ||
        message.contains('won\'t move')) {
      return 'Understood. Since the EV cannot move near $location, please send a dashboard warning photo and tell me whether the gear selector, parking brake, or 12V system seems stuck.';
    }
    if (message.contains('accident') ||
        message.contains('crash') ||
        message.contains('bump') ||
        message.contains('impact')) {
      return 'Accident details noted by $workshop. Please stay safe first. Tell us the impact side, whether airbags deployed, whether the EV can still move, and send a photo of the damaged area. If anyone is injured, use the hospital emergency flow immediately.';
    }
    if (message.contains('on the way') ||
        message.contains('come') ||
        message.contains('send someone')) {
      return 'Help can be sent to $location. Please stand by in a safe place. If towing is needed, I can dispatch the nearest recovery driver as soon as you confirm the pickup location.';
    }
    if (message.contains('where') ||
        message.contains('location') ||
        message.contains('address')) {
      return '$workshop is using the location attached to this chat: $location. If that is not accurate, send your nearest landmark, road name, parking level, or shop lot number so we can update the case.';
    }
    if (message.contains('hi') ||
        message.contains('hello') ||
        message.contains('help')) {
      return 'Hi, this is $workshop. Tell me what happened, whether the EV can still move, and send a dashboard or vehicle photo so I can guide the next step.';
    }
    return 'I can help with that. Tell me what happened in one line and send a dashboard or vehicle photo so I can guide the next step.';
  }

  static String _automatedHospitalReply(
    String driverMessage,
    Map<String, dynamic> thread, {
    required bool imageShared,
  }) {
    final message = driverMessage.toLowerCase();
    final location = thread['location_name']?.toString() ?? 'your location';
    final hospital =
        thread['responder_name']?.toString() ?? 'Hospital Emergency Triage';

    if (imageShared) {
      return 'Thanks, I received the photo for triage near $location. Please tell me how many people are involved, whether anyone is injured or trapped, and if there is smoke, fire, or battery heat.';
    }
    if (message.contains('injur') ||
        message.contains('bleed') ||
        message.contains('pain') ||
        message.contains('hurt') ||
        message.contains('unconscious')) {
      return '$hospital has marked this as a possible injury case. Keep the injured person still unless there is fire or immediate danger. Tell me their condition: conscious or unconscious, breathing normally, bleeding, chest/head/neck pain, and number of patients.';
    }
    if (message.contains('accident') ||
        message.contains('crash') ||
        message.contains('impact') ||
        message.contains('bump') ||
        message.contains('level 4') ||
        message.contains('level 5')) {
      return 'Accident details noted by $hospital. Please do not continue driving yet. Confirm the impact side, whether airbags deployed, whether doors can open, number of passengers, and send a photo of the vehicle or road scene if it is safe.';
    }
    if (message.contains('smoke') ||
        message.contains('fire') ||
        message.contains('burn') ||
        message.contains('battery heat') ||
        message.contains('hot')) {
      return 'Smoke, fire, burning smell, or battery heat is serious for an EV. Move everyone at least several metres away, do not touch the battery area, do not charge the vehicle, and tell me if emergency services are already nearby.';
    }
    if (message.contains('location') ||
        message.contains('where') ||
        message.contains('address') ||
        message.contains('lost')) {
      return '$hospital is using the location attached to this chat: $location. If it is not exact, reply with a landmark, road name, parking level, shop lot, or send your live location from the map screen.';
    }
    if (message.contains('ambulance') ||
        message.contains('come') ||
        message.contains('send') ||
        message.contains('on the way')) {
      return 'Please keep your phone on and stay visible near $location. Help is being arranged, so confirm patient count and whether anyone has severe bleeding or breathing difficulty.';
    }
    if (message.contains('safe') ||
        message.contains('ok') ||
        message.contains('fine') ||
        message.contains('cancel')) {
      return 'Safety update noted by $hospital. Even if you feel okay, monitor dizziness, chest pain, headache, neck pain, or breathing difficulty. If symptoms appear, reply here and avoid driving until the EV is checked.';
    }
    if (message.contains('hi') ||
        message.contains('hello') ||
        message.contains('help') ||
        message.contains('emergency')) {
      return 'Hello, this is $hospital emergency triage. Move to a safe place if you can, then tell me how many people are involved and whether the EV has smoke, fire, or battery heat near $location.';
    }
    return 'I’m here with you. Please tell me how many people are involved, whether everyone can exit the EV, and if there is any smoke, fire, or battery heat.';
  }

  static String _messagePreview(Map<String, dynamic> message) {
    final text = message['text']?.toString().trim() ?? '';
    final hasImage = message['image_base64']?.toString().isNotEmpty ?? false;
    if (hasImage && text.isNotEmpty) {
      return 'Photo shared: $text';
    }
    if (hasImage) {
      return 'Vehicle condition image shared';
    }
    return text;
  }

  static Future<void> _logSupportConversationUpdate({
    required Map<String, dynamic> thread,
    required String detail,
  }) async {
    final role = thread['responder_role']?.toString() ?? '';
    if (role != 'technician' && role != 'hospital') {
      return;
    }

    final audience = role == 'hospital' ? 'hospital' : 'insurance';
    final title = role == 'hospital'
        ? 'Hospital assist chat updated'
        : 'Technician case updated';
    final responderLabel = role == 'hospital'
        ? 'hospital emergency desk'
        : 'EV technician';
    await pushDashboardNotification(
      audience: audience,
      type: role == 'hospital' ? 'Message' : 'Support',
      title: title,
      message:
          '${thread['driver_name']?.toString() ?? 'Driver'}: $detail with ${thread['responder_name']?.toString() ?? responderLabel} near ${thread['location_name']?.toString() ?? 'current location'}.',
      alertId: thread['thread_id']?.toString(),
      userId: thread['user_id']?.toString(),
      extraData: {'thread_id': thread['thread_id'], 'support_role': role},
    );
  }

  static const List<Map<String, dynamic>> _seedStations = [
    {
      'id': 'icity',
      'name': 'Shah Alam EV Station',
      'lat': 3.0648,
      'lng': 101.4876,
      'chargers': 6,
      'queue': 3,
      'wait': '5 mins',
      'address': 'Shah Alam, Selangor',
    },
    {
      'id': 'sunway_pyramid',
      'name': 'Sunway Pyramid EV Hub',
      'lat': 3.0730,
      'lng': 101.6072,
      'chargers': 5,
      'queue': 5,
      'wait': '15 mins',
      'address': 'Bandar Sunway',
    },
    {
      'id': 'one_utama',
      'name': '1 Utama Charging Station',
      'lat': 3.1467,
      'lng': 101.6151,
      'chargers': 4,
      'queue': 1,
      'wait': '4 mins',
      'address': 'Petaling Jaya',
    },
    {
      'id': 'mid_valley',
      'name': 'Mid Valley Charge Point',
      'lat': 3.1174,
      'lng': 101.6773,
      'chargers': 6,
      'queue': 4,
      'wait': '12 mins',
      'address': 'Mid Valley City',
    },
    {
      'id': 'klcc',
      'name': 'KLCC EV Station',
      'lat': 3.1579,
      'lng': 101.7123,
      'chargers': 4,
      'queue': 0,
      'wait': '0 mins',
      'address': 'Kuala Lumpur City Centre',
    },
    {
      'id': 'putrajaya_iocc',
      'name': 'Putrajaya Green Charge',
      'lat': 2.9694,
      'lng': 101.7137,
      'chargers': 5,
      'queue': 2,
      'wait': '8 mins',
      'address': 'Putrajaya',
    },
    {
      'id': 'cyberjaya_dpulze',
      'name': 'Cyberjaya EV Station',
      'lat': 2.9213,
      'lng': 101.6559,
      'chargers': 4,
      'queue': 4,
      'wait': '15 mins',
      'address': 'Cyberjaya',
    },
    {
      'id': 'aeon_bukit_tinggi',
      'name': 'Bukit Tinggi EV Hub',
      'lat': 3.0060,
      'lng': 101.4455,
      'chargers': 4,
      'queue': 1,
      'wait': '6 mins',
      'address': 'Klang',
    },
  ];
}

class _LocationZone {
  const _LocationZone(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;
}
