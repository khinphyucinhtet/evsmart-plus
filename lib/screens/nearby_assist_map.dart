import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_repository.dart';
import '../services/assist_directory.dart';
import 'user_message.dart';

enum AssistType { health, technician }

class NearbyAssistMapPage extends StatefulWidget {
  const NearbyAssistMapPage({
    super.key,
    required this.assistType,
  });

  final AssistType assistType;

  @override
  State<NearbyAssistMapPage> createState() => _NearbyAssistMapPageState();
}

class _NearbyAssistMapPageState extends State<NearbyAssistMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<Position>? _positionSubscription;
  LatLng _userLocation = const LatLng(3.1390, 101.6869);
  List<Map<String, dynamic>> _filteredProviders = const <Map<String, dynamic>>[];
  Map<String, dynamic>? _selectedProvider;
  bool _showSuggestions = false;

  List<Map<String, dynamic>> get _providers {
    return widget.assistType == AssistType.health
        ? AssistDirectory.healthProviders
        : AssistDirectory.technicianProviders;
  }

  String get _title {
    return widget.assistType == AssistType.health
        ? 'Nearby Hospitals'
        : 'Nearby EV Technicians';
  }

  String get _assistLabel {
    return widget.assistType == AssistType.health
        ? 'Health Assist'
        : 'Technician Assist';
  }

  String get _userLocationLabel {
    return AppRepository.inferLocationName(
      _userLocation.latitude,
      _userLocation.longitude,
    );
  }

  @override
  void initState() {
    super.initState();
    _filteredProviders = _providers;
    _requestLocation();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _searchController.dispose();
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

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final nextPoint = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() {
        _userLocation = nextPoint;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final providers = _sortedProviders(_providers);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        automaticallyImplyLeading: false,
        title: Text(_title, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation,
              initialZoom: 11.8,
              onTap: (tapPosition, point) {
                FocusScope.of(context).unfocus();
                setState(() {
                  _showSuggestions = false;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.evsmart.plus.evsmart_plus',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation,
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
                  ...providers.map(_buildMarker),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildSearchBox(),
                if (_showSuggestions) _buildSuggestions(),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: _selectedProvider == null
                ? _buildGuideCard()
                : _buildProviderCard(_selectedProvider!),
          ),
          Positioned(
            bottom: _selectedProvider == null ? 160 : 315,
            right: 20,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: Container(
                height: 56,
                width: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _searchProviders,
        decoration: InputDecoration(
          hintText: 'Search $_assistLabel nearby...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _searchProviders('');
                  },
                  icon: const Icon(Icons.close),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredProviders.length,
        itemBuilder: (context, index) {
          final provider = _filteredProviders[index];
          return ListTile(
            leading: Icon(
              widget.assistType == AssistType.health
                  ? Icons.local_hospital
                  : Icons.ev_station,
              color: const Color(0xFF2E7D32),
            ),
            title: Text(provider['name']?.toString() ?? ''),
            subtitle: Text(provider['address']?.toString() ?? ''),
            trailing: Text(_distanceLabel(provider)),
            onTap: () => _selectProvider(provider),
          );
        },
      ),
    );
  }

  Marker _buildMarker(Map<String, dynamic> provider) {
    final isSelected = _selectedProvider?['id'] == provider['id'];
    return Marker(
      point: LatLng(
        (provider['lat'] as num).toDouble(),
        (provider['lng'] as num).toDouble(),
      ),
      width: 74,
      height: 74,
      child: GestureDetector(
        onTap: () => _selectProvider(provider),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? Colors.redAccent : const Color(0xFF2E7D32),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: (isSelected ? Colors.redAccent : Colors.green)
                    .withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            widget.assistType == AssistType.health
                ? Icons.local_hospital
                : Icons.build,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.assistType == AssistType.health
                ? 'Select a nearby hospital for directions, phone, or message support.'
                : 'Select a nearby EV specialist for directions, phone, or AI workshop chat.',
            style: const TextStyle(fontWeight: FontWeight.bold, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Your current location: $_userLocationLabel. Tap a marker or search result to self-navigate using Google Maps.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            provider['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            provider['address']?.toString() ?? '',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'Phone: ${provider['phone']?.toString() ?? '-'}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${provider['availability']} - ${_distanceLabel(provider)} away',
            style: const TextStyle(
              color: Color(0xFF2E7D32),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your location: $_userLocationLabel',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.assistType == AssistType.health
                ? 'Hospital service point: ${provider['address']?.toString() ?? '-'}'
                : 'Workshop service point: ${provider['address']?.toString() ?? '-'}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGoogleMapsNavigation(provider),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchPhone(
                    provider['phone']?.toString() ?? '',
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _startConversation(provider),
              icon: const Icon(Icons.message),
              label: Text(
                widget.assistType == AssistType.health
                    ? 'Message Hospital'
                    : 'Message AI Workshop Assistant',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _searchProviders(String query) {
    final normalized = query.trim().toLowerCase();
    final providers = _sortedProviders(_providers);
    final results = normalized.isEmpty
        ? providers
        : providers.where((provider) {
            final name = provider['name']?.toString().toLowerCase() ?? '';
            final address = provider['address']?.toString().toLowerCase() ?? '';
            return name.contains(normalized) || address.contains(normalized);
          }).toList();

    setState(() {
      _filteredProviders = results.take(10).toList();
      _showSuggestions = true;
    });
  }

  void _selectProvider(Map<String, dynamic> provider) {
    final point = LatLng(
      (provider['lat'] as num).toDouble(),
      (provider['lng'] as num).toDouble(),
    );
    _mapController.move(point, 15.2);
    setState(() {
      _selectedProvider = provider;
      _showSuggestions = false;
      _searchController.clear();
    });
  }

  void _centerOnUser() {
    _mapController.move(_userLocation, 15.4);
    setState(() {
      _selectedProvider = null;
      _showSuggestions = false;
    });
  }

  Future<void> _startConversation(Map<String, dynamic> provider) async {
    final initialMessage = widget.assistType == AssistType.health
        ? 'Hi, I need emergency health assistance near $_userLocationLabel. The driver may still be mobile and needs support.'
        : 'Hi, I need an EV technician near $_userLocationLabel. My EV may need roadside inspection and I can share more details in chat.';

    final threadId = await AppRepository.startAssistanceConversation(
      responderRole:
          widget.assistType == AssistType.health ? 'hospital' : 'technician',
      responderId: provider['id']?.toString(),
      responderName: provider['name']?.toString() ?? '',
      responderPhone: provider['phone']?.toString() ?? '',
      locationName: _userLocationLabel,
      issueLabel: _assistLabel,
      initialMessage: initialMessage,
      autoDispatch: false,
    );

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UserMessagePage(initialThreadId: threadId),
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    if (phone.isEmpty) {
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    await launchUrl(uri);
  }

  Future<void> _openGoogleMapsNavigation(Map<String, dynamic> provider) async {
    final lat = (provider['lat'] as num).toDouble();
    final lng = (provider['lng'] as num).toDouble();
    final origin =
        '${_userLocation.latitude.toStringAsFixed(6)},${_userLocation.longitude.toStringAsFixed(6)}';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$lat,$lng&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    final fallback = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    await launchUrl(fallback, mode: LaunchMode.externalApplication);
  }

  String _distanceLabel(Map<String, dynamic> provider) {
    final distance = Geolocator.distanceBetween(
      _userLocation.latitude,
      _userLocation.longitude,
      (provider['lat'] as num).toDouble(),
      (provider['lng'] as num).toDouble(),
    );
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  List<Map<String, dynamic>> _sortedProviders(List<Map<String, dynamic>> items) {
    return AssistDirectory.sortedProviders(
      items,
      latitude: _userLocation.latitude,
      longitude: _userLocation.longitude,
    );
  }
}
