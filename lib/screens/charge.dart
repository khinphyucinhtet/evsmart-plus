import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_repository.dart';
import '../services/impact_detection_service.dart';
import 'alert.dart';
import 'app_footer.dart';
import 'app_header.dart';
import 'global_search.dart';
import 'home_driver.dart';
import 'noti.dart';
import 'rewards.dart';

class ChargePage extends StatefulWidget {
  const ChargePage({super.key});

  @override
  State<ChargePage> createState() => _ChargePageState();
}

class _ChargePageState extends State<ChargePage> {
  final MapController mapController = MapController();
  final LatLng defaultCenter = const LatLng(3.0738, 101.5183);
  final TextEditingController searchController = TextEditingController();

  LatLng? userLocation;
  StreamSubscription<Position>? positionStream;
  List<Map<String, dynamic>> filteredStations = [];
  bool showSuggestions = false;
  Map<String, dynamic>? selectedStation;
  late final ImpactDetectionService _impactService;
  bool _isImpactDialogVisible = false;

  @override
  void initState() {
    super.initState();
    AppRepository.ensureChargingStations();
    _impactService = ImpactDetectionService(onImpact: _handleImpactDetected);
    _impactService.start();
    _requestLocation();
  }

  @override
  void dispose() {
    _impactService.stop();
    positionStream?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _requestLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          final newLocation = LatLng(position.latitude, position.longitude);
          if (!mounted) {
            return;
          }
          setState(() {
            userLocation = newLocation;
          });
        });
  }

  void _handleImpactDetected(ImpactEvent event) {
    if (!mounted || _isImpactDialogVisible) {
      return;
    }

    _showEmergencyCountdown(
      title: 'Potential accident detected. Cancel if safe.',
      subtitle:
          '${AppRepository.severityLabel(event.level)} detected from the phone accelerometer. ${event.description}',
      impactLevel: event.level,
      source: 'accelerometer',
      autoDispatch: event.level >= 4,
      accelerationMagnitude: event.magnitude,
      detectedAt: event.detectedAt,
    );
  }

  Future<void> _createAlert({
    required int impactLevel,
    required String source,
    required bool emergencyTriggered,
    double? accelerationMagnitude,
    DateTime? detectedAt,
  }) async {
    final latitude = userLocation?.latitude ?? defaultCenter.latitude;
    final longitude = userLocation?.longitude ?? defaultCenter.longitude;

    final alert = await AppRepository.sendAutomaticAlert(
      impactLevel: impactLevel,
      vehicleStatus: _vehicleStatusForLevel(impactLevel),
      latitude: latitude,
      longitude: longitude,
      emergencyTriggered: emergencyTriggered,
      sourceDetail: source,
      title: 'Potential accident detected',
      accidentStatus: emergencyTriggered
          ? 'Emergency dispatch initiated'
          : 'Impact logged for monitoring',
      accelerationMagnitude: accelerationMagnitude,
      timestamp: detectedAt,
      extraData: {
        'gps_location':
            '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
        'impact_detected_by': 'Phone accelerometer IoT simulation',
      },
    );

    if (!mounted) {
      return;
    }

    _showHelpOnTheWay(
      emergencyTriggered,
      alert['impact_label']?.toString() ??
          AppRepository.severityLabel(impactLevel),
    );
  }

  Future<void> _showEmergencyCountdown({
    required String title,
    required String subtitle,
    required int impactLevel,
    required String source,
    required bool autoDispatch,
    double? accelerationMagnitude,
    DateTime? detectedAt,
  }) async {
    if (_isImpactDialogVisible) {
      return;
    }

    _isImpactDialogVisible = true;
    int seconds = 5;
    bool cancelled = false;
    Timer? timer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (value) async {
              if (seconds == 0) {
                value.cancel();
                if (Navigator.of(dialogContext).canPop()) {
                  Navigator.of(dialogContext).pop();
                }
                await _createAlert(
                  impactLevel: impactLevel,
                  source: source,
                  emergencyTriggered: autoDispatch,
                  accelerationMagnitude: accelerationMagnitude,
                  detectedAt: detectedAt,
                );
                return;
              }

              seconds -= 1;
              if (context.mounted) {
                setState(() {});
              }
            });

            return AlertDialog(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(subtitle),
                  const SizedBox(height: 16),
                  Text(
                    autoDispatch
                        ? 'Emergency services will be notified in $seconds seconds.'
                        : 'This alert will be saved in $seconds seconds.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: seconds / 5,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This simulates vehicle IoT impact sensors using the phone accelerometer.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelled = true;
                    timer?.cancel();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    timer?.cancel();
    _isImpactDialogVisible = false;
    if (cancelled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emergency flow cancelled by driver')),
      );
    }
  }

  void _showHelpOnTheWay(bool emergencyTriggered, String severityLabel) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(emergencyTriggered ? 'Help is on the way' : 'Alert logged'),
        content: Text(
          emergencyTriggered
              ? '$severityLabel was sent to Firebase, the hospital emergency dashboard, the notification page, and insurance analytics.'
              : '$severityLabel was stored in Firebase and added to the alert history and notification page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleStatusForLevel(int level) {
    switch (level) {
      case 1:
        return 'Small bump detected. Driver should inspect vehicle body and bumper alignment.';
      case 2:
        return 'Minor collision suspected. Brake, tire, and sensor checks recommended.';
      case 3:
        return 'Moderate accident detected. Vehicle diagnostics and technician support required.';
      case 4:
        return 'Severe accident suspected. Emergency support and ambulance dispatch initiated.';
      case 5:
        return 'Critical crash pattern detected. Immediate emergency response required.';
      default:
        return 'Vehicle status unavailable.';
    }
  }

  void searchStations(String query, List<Map<String, dynamic>> stations) {
    if (query.isEmpty) {
      setState(() {
        filteredStations = [];
        showSuggestions = false;
      });
      return;
    }

    final normalized = query.toLowerCase();
    final results = stations.where((station) {
      final name = station['name']?.toString().toLowerCase() ?? '';
      final address = station['address']?.toString().toLowerCase() ?? '';
      return name.contains(normalized) || address.contains(normalized);
    }).toList();

    if (userLocation != null) {
      results.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));
    }

    setState(() {
      filteredStations = results.take(8).toList();
      showSuggestions = true;
    });
  }

  double _distanceTo(Map<String, dynamic> station) {
    if (userLocation == null) {
      return double.infinity;
    }
    return Geolocator.distanceBetween(
      userLocation!.latitude,
      userLocation!.longitude,
      (station['lat'] as num).toDouble(),
      (station['lng'] as num).toDouble(),
    );
  }

  int _totalChargers(Map<String, dynamic> station) {
    return (station['chargers'] as num?)?.toInt() ?? 0;
  }

  int _queueCount(Map<String, dynamic> station) {
    return (station['queue'] as num?)?.toInt() ?? 0;
  }

  int _availableChargers(Map<String, dynamic> station) {
    final total = _totalChargers(station);
    final queue = _queueCount(station);
    return (total - queue).clamp(0, total);
  }

  String _stationStatus(Map<String, dynamic> station) {
    return _availableChargers(station) > 0 ? 'Available' : 'Full';
  }

  String _estimatedWait(Map<String, dynamic> station) {
    return station['wait']?.toString() ??
        (_availableChargers(station) > 0 ? '5 minutes' : '15 minutes');
  }

  bool _shouldShowEstimatedWait(Map<String, dynamic> station) {
    return _availableChargers(station) == 0;
  }

  String distanceToStation(Map<String, dynamic> station) {
    if (userLocation == null) {
      return station['address']?.toString() ?? '';
    }

    final km = _distanceTo(station) / 1000;
    return '${km.toStringAsFixed(1)} km away';
  }

  void selectStation(Map<String, dynamic> station) {
    final point = LatLng(
      (station['lat'] as num).toDouble(),
      (station['lng'] as num).toDouble(),
    );
    mapController.move(point, 15.8);
    setState(() {
      showSuggestions = false;
      searchController.clear();
    });
    showStationPreview(station);
  }

  // Shows the bottom station preview card when a marker is tapped.
  void showStationPreview(Map<String, dynamic> station) {
    setState(() {
      selectedStation = station;
      showSuggestions = false;
    });
  }

  void hideStationPreview() {
    if (!mounted) {
      return;
    }
    setState(() {
      selectedStation = null;
    });
  }

  // Displays the centered reservation dialog without interrupting the map flow.
  Future<void> showReserveDialog(Map<String, dynamic> station) async {
    hideStationPreview();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station['name']?.toString() ?? 'Charging Station',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  station['address']?.toString() ?? '-',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 18),
                _dialogLine(
                  Icons.ev_station,
                  'Chargers: ${_availableChargers(station)} / ${_totalChargers(station)}',
                ),
                _dialogLine(
                  Icons.directions_car_outlined,
                  'Queue: ${_queueCount(station)}',
                ),
                if (_shouldShowEstimatedWait(station))
                  _dialogLine(
                    Icons.timer_outlined,
                    'Estimated wait: ${_estimatedWait(station)}',
                  ),
                _dialogLine(
                  Icons.map_outlined,
                  'Distance: ${distanceToStation(station)}',
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF2E7D32)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.of(dialogContext).pop();
                          await _openGoogleMapsNavigation(station);
                        },
                        child: const Text(
                          'Locate',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // Opens Google Maps navigation from the current view to the selected station.
  Future<void> _openGoogleMapsNavigation(Map<String, dynamic> station) async {
    final lat = (station['lat'] as num).toDouble();
    final lng = (station['lng'] as num).toDouble();
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open Google Maps navigation.')),
      );
    }
  }

  List<Marker> buildMarkers(List<Map<String, dynamic>> stations) {
    final markers = <Marker>[];

    if (userLocation != null) {
      markers.add(
        Marker(
          point: userLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }

    for (final station in stations) {
      markers.add(
        Marker(
          point: LatLng(
            (station['lat'] as num).toDouble(),
            (station['lng'] as num).toDouble(),
          ),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => showStationPreview(station),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.ev_station,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildStationPreviewCard() {
    final station = selectedStation;
    final visible = station != null;
    final status = visible ? _stationStatus(station) : '';
    final statusColor = status == 'Available'
        ? const Color(0xFF2E7D32)
        : Colors.red;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      left: 16,
      right: 16,
      bottom: visible ? 95 : -320,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: visible ? 1 : 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: station == null
                  ? const SizedBox.shrink()
                  : SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  station['name']?.toString() ??
                                      'Charging Station',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: hideStationPreview,
                                icon: const Icon(Icons.close_rounded),
                                splashRadius: 22,
                              ),
                            ],
                          ),
                          Text(
                            'Status: $status',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Available Chargers: ${_availableChargers(station)} / ${_totalChargers(station)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Chargers: ${_totalChargers(station)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_shouldShowEstimatedWait(station)) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Estimated Wait: ${_estimatedWait(station)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: () => showReserveDialog(station),
                              child: const Text(
                                'Reserve Charging Slot',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppRepository.streamChargingStations(),
      builder: (context, snapshot) {
        final stations = snapshot.data ?? const <Map<String, dynamic>>[];

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                AppHeader(
                  onSearch: (key) {
                    GlobalSearchHandler.handleSearch(context, key);
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: defaultCenter,
                          initialZoom: 9.5,
                          onTap: (tapPosition, point) {
                            hideStationPreview();
                            if (showSuggestions) {
                              setState(() {
                                showSuggestions = false;
                              });
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'com.evsmart.plus.evsmart_plus',
                          ),
                          MarkerLayer(markers: buildMarkers(stations)),
                        ],
                      ),
                      Positioned(
                        top: 16,
                        left: 15,
                        right: 15,
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: searchController,
                                onChanged: (value) =>
                                    searchStations(value, stations),
                                decoration: const InputDecoration(
                                  hintText: 'Search charging stations...',
                                  prefixIcon: Icon(Icons.search),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(14),
                                ),
                              ),
                            ),
                            if (showSuggestions)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 8,
                                      color: Colors.black12,
                                    ),
                                  ],
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filteredStations.length,
                                  itemBuilder: (context, index) {
                                    final station = filteredStations[index];
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.ev_station,
                                        color: Color(0xFF2E7D32),
                                      ),
                                      title: Text(
                                        station['name']?.toString() ?? '',
                                      ),
                                      subtitle: Text(
                                        distanceToStation(station),
                                      ),
                                      onTap: () => selectStation(station),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        right: 20,
                        child: GestureDetector(
                          onTap: () {
                            if (userLocation != null) {
                              mapController.move(userLocation!, 15.8);
                            }
                          },
                          child: Container(
                            height: 56,
                            width: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      _buildStationPreviewCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: AppFooter(
            currentIndex: 1,
            onTap: _handleFooterTap,
          ),
        );
      },
    );
  }

  void _handleFooterTap(int index) {
    if (index == 1) {
      return;
    }

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DriverHomePage()),
      );
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AlertPage()),
      );
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const NotificationPage()),
      );
    }

    if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RewardsPage()),
      );
    }
  }
}
