import 'package:flutter/material.dart';

import 'responder_messages_base.dart';

class AmbulanceDriverMessagesPage extends StatelessWidget {
  const AmbulanceDriverMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponderMessagesPage(
      role: 'hospital',
      title: 'Ambulance Driver Messages',
      emptySubtitle:
          'Driver hospital chats will appear here as soon as a user selects a nearby hospital or clinic from the map.',
      showNearbyHospitalsShortcut: true,
    );
  }
}
