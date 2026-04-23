import 'dart:async';

import 'package:flutter/material.dart';

class AmbulanceTripProgressPage extends StatefulWidget {
  const AmbulanceTripProgressPage({
    super.key,
    required this.destinationLabel,
    required this.driverLabel,
    required this.severityLabel,
    required this.ambulanceUnit,
    required this.etaMinutes,
  });

  final String destinationLabel;
  final String driverLabel;
  final String severityLabel;
  final String ambulanceUnit;
  final int etaMinutes;

  @override
  State<AmbulanceTripProgressPage> createState() =>
      _AmbulanceTripProgressPageState();
}

class _AmbulanceTripProgressPageState extends State<AmbulanceTripProgressPage> {
  static const Color _brandGreen = Color(0xFF2E7D32);
  static const Color _canvas = Color(0xFFF3F4F2);
  static const Color _textPrimary = Color(0xFF273128);
  static const Color _textMuted = Color(0xFF6D746E);

  Timer? _timer;
  double _progress = 0;

  bool get _isComplete => _progress >= 1;

  @override
  void initState() {
    super.initState();
    _startProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startProgress() {
    const totalSteps = 25;
    const tick = Duration(milliseconds: 140);
    var currentStep = 0;

    _timer = Timer.periodic(tick, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentStep += 1;
      final nextProgress = (currentStep / totalSteps).clamp(0, 1).toDouble();
      setState(() {
        _progress = nextProgress;
      });

      if (currentStep >= totalSteps) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_progress * 100).round();

    return PopScope(
      canPop: _isComplete,
      child: Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: _brandGreen,
          automaticallyImplyLeading: false,
          title: const Text(
            'Ambulance Dispatch',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: 420,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14375D42),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3E9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: _brandGreen,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text(
                        'Going to destination...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _isComplete
                            ? 'Ambulance has reached the EV user location.'
                            : 'Dispatch progress is being simulated for the emergency response demo.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _textMuted, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInfoCard(
                      title: widget.destinationLabel,
                      subtitle:
                          '${widget.severityLabel} • ${widget.ambulanceUnit}',
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      title: widget.driverLabel,
                      subtitle:
                          'Estimated travel time: ${widget.etaMinutes} min',
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 14,
                        backgroundColor: const Color(0xFFE7ECE7),
                        valueColor: const AlwaysStoppedAnimation(_brandGreen),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '$percentage%',
                        style: const TextStyle(
                          color: _brandGreen,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed: _isComplete
                              ? () => Navigator.of(context).pop(true)
                              : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF17201A),
                            disabledBackgroundColor: const Color(0xFFF4F7F4),
                            disabledForegroundColor: const Color(0xFF9AA39B),
                            side: const BorderSide(
                              color: Color(0xFFBFD8C1),
                              width: 1.4,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            _isComplete ? 'Arrived' : 'Reaching destination...',
                            style: const TextStyle(fontWeight: FontWeight.w800),
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

  Widget _buildInfoCard({required String title, required String subtitle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1EAE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: _textMuted,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
