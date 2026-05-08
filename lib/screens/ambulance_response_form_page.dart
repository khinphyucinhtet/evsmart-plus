import 'package:flutter/material.dart';

class AmbulanceResponseFormPage extends StatefulWidget {
  const AmbulanceResponseFormPage({
    super.key,
    required this.locationLabel,
    required this.severityLabel,
    required this.severityDescription,
    required this.initialUnit,
    required this.initialContact,
  });

  final String locationLabel;
  final String severityLabel;
  final String severityDescription;
  final String initialUnit;
  final String initialContact;

  @override
  State<AmbulanceResponseFormPage> createState() =>
      _AmbulanceResponseFormPageState();
}

class _AmbulanceResponseFormPageState extends State<AmbulanceResponseFormPage> {
  static const Color _brandGreen = Color(0xFF2E7D32);
  static const Color _canvas = Color(0xFFF3F4F2);
  static const Color _textPrimary = Color(0xFF273128);
  static const Color _textMuted = Color(0xFF6D746E);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _etaController;
  late final TextEditingController _unitController;
  late final TextEditingController _contactController;
  late final TextEditingController _teamController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _etaController = TextEditingController(text: '8');
    _unitController = TextEditingController(text: widget.initialUnit);
    _contactController = TextEditingController(text: widget.initialContact);
    _teamController = TextEditingController(text: '2');
    _notesController = TextEditingController(
      text:
          'Ambulance team accepted the nearby emergency and is preparing to move.',
    );
  }

  @override
  void dispose() {
    _etaController.dispose();
    _unitController.dispose();
    _contactController.dispose();
    _teamController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: const Text('Accept Emergency Case'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14375D42),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Going to accident?',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Fill this quick ambulance response form. It will be sent to the hospital dashboard as a live update.',
                        style: TextStyle(color: _textMuted, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      _buildHighlightCard(
                        icon: Icons.location_on_rounded,
                        title: widget.locationLabel,
                        subtitle: 'Nearest emergency destination',
                      ),
                      const SizedBox(height: 12),
                      _buildHighlightCard(
                        icon: Icons.warning_amber_rounded,
                        title: widget.severityLabel,
                        subtitle: widget.severityDescription,
                      ),
                      const SizedBox(height: 18),
                      _buildInput(
                        controller: _etaController,
                        label: 'Estimated arrival time',
                        suffixText: 'minutes',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final eta = int.tryParse(value?.trim() ?? '');
                          if (eta == null || eta <= 0) {
                            return 'Enter ETA in minutes.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        controller: _unitController,
                        label: 'Ambulance unit',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter ambulance unit.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        controller: _contactController,
                        label: 'Contact number',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter contact number.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        controller: _teamController,
                        label: 'Team size',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final size = int.tryParse(value?.trim() ?? '');
                          if (size == null || size <= 0) {
                            return 'Enter team size.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildInput(
                        controller: _notesController,
                        label: 'Response note for hospital',
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Add a short note.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _brandGreen,
                                side: const BorderSide(
                                  color: Color(0xFFCDE0CF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(Icons.local_shipping_rounded),
                              label: const Text(
                                'Send & Go',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE9DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F3E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _brandGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                  style: const TextStyle(color: _textMuted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    String? suffixText,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        filled: true,
        fillColor: _canvas,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop({
      'eta_minutes': int.parse(_etaController.text.trim()),
      'ambulance_unit': _unitController.text.trim(),
      'contact_number': _contactController.text.trim(),
      'team_size': int.parse(_teamController.text.trim()),
      'notes': _notesController.text.trim(),
    });
  }
}
