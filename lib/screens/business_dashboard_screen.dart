import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kBusinessTypes = [
  'Police Station',
  'Hospital / A&E',
  'Pharmacy',
  'University / College',
  'Religious Centre',
  'Gym',
  'Shopping Centre',
  'Bar / Club',
  'Mental Wellbeing Centre',
  'Immediate Help Centre',
  'Other',
];

const List<String> kSafeSpaceTypes = [
  'Immediate Help Centre',
  'Mental Wellbeing Centre',
];

class BusinessDashboardScreen extends StatefulWidget {
  const BusinessDashboardScreen({super.key});

  @override
  State<BusinessDashboardScreen> createState() =>
      _BusinessDashboardScreenState();
}

class _BusinessDashboardScreenState extends State<BusinessDashboardScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _saved = false;

  // Form fields
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedBusinessType = kBusinessTypes[0];
  String _selectedSafeSpaceType = kSafeSpaceTypes[0];
  bool _isOpen24h = false;
  bool _hasDisabledAccess = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final doc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(user?.uid)
        .get();
    if (doc.exists && doc.data()?['name'] != null) {
      final data = doc.data()!;
      setState(() {
        _nameController.text = data['name'] ?? '';
        _addressController.text = data['address'] ?? '';
        _postcodeController.text = data['postcode'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _descController.text = data['description'] ?? '';
        _selectedBusinessType = data['businessType'] ?? kBusinessTypes[0];
        _selectedSafeSpaceType = data['safeSpaceType'] ?? kSafeSpaceTypes[0];
        _isOpen24h = data['open24h'] ?? false;
        _hasDisabledAccess = data['disabledAccess'] ?? false;
        _saved = true;
      });
    }
  }

  Future<void> _saveListing() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(user?.uid)
        .update({
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'postcode': _postcodeController.text.trim().toUpperCase(),
      'phone': _phoneController.text.trim(),
      'description': _descController.text.trim(),
      'businessType': _selectedBusinessType,
      'safeSpaceType': _selectedSafeSpaceType,
      'open24h': _isOpen24h,
      'disabledAccess': _hasDisabledAccess,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    setState(() {
      _loading = false;
      _saved = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Listing saved! Awaiting verification.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        title: const Text('SafeSpace Business',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              _StatusBanner(saved: _saved),
              const SizedBox(height: 24),

              const _SectionTitle('Business Details'),
              const SizedBox(height: 12),

              // Business name
              _buildField(
                controller: _nameController,
                label: 'Business / Centre Name',
                icon: Icons.business,
                validator: (v) =>
                    v!.isEmpty ? 'Please enter your business name' : null,
              ),
              const SizedBox(height: 12),

              // Address
              _buildField(
                controller: _addressController,
                label: 'Full Address',
                icon: Icons.location_on,
                validator: (v) =>
                    v!.isEmpty ? 'Please enter your address' : null,
              ),
              const SizedBox(height: 12),

              // Postcode
              _buildField(
                controller: _postcodeController,
                label: 'Postcode',
                icon: Icons.markunread_mailbox_outlined,
                validator: (v) =>
                    v!.isEmpty ? 'Please enter your postcode' : null,
              ),
              const SizedBox(height: 12),

              // Phone
              _buildField(
                controller: _phoneController,
                label: 'Contact Phone Number',
                icon: Icons.phone,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: _inputDecoration('Brief Description', Icons.info),
              ),
              const SizedBox(height: 20),

              const _SectionTitle('Classification'),
              const SizedBox(height: 12),

              // Business type
              const Text('Business Type',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedBusinessType,
                items: kBusinessTypes,
                icon: Icons.category,
                onChanged: (v) =>
                    setState(() => _selectedBusinessType = v!),
              ),
              const SizedBox(height: 12),

              // Safe space type
              const Text('Safe Space Type',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedSafeSpaceType,
                items: kSafeSpaceTypes,
                icon: Icons.shield,
                onChanged: (v) =>
                    setState(() => _selectedSafeSpaceType = v!),
              ),
              const SizedBox(height: 20),

              const _SectionTitle('Accessibility'),
              const SizedBox(height: 12),

              // Checkboxes
              _buildCheckbox(
                label: 'Open 24 hours',
                icon: Icons.access_time,
                value: _isOpen24h,
                onChanged: (v) => setState(() => _isOpen24h = v!),
              ),
              _buildCheckbox(
                label: 'Disabled / wheelchair access',
                icon: Icons.accessible,
                value: _hasDisabledAccess,
                onChanged: (v) => setState(() => _hasDisabledAccess = v!),
              ),

              const SizedBox(height: 28),

              // Save button
              ElevatedButton.icon(
                onPressed: _loading ? null : _saveListing,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_loading ? 'Saving...' : 'Save Listing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1A237E)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A237E)),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCheckbox({
    required String label,
    required IconData icon,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(label),
        secondary: Icon(icon, color: const Color(0xFF1A237E)),
        activeColor: const Color(0xFF1A237E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool saved;
  const _StatusBanner({required this.saved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: saved
            ? Colors.orange.withOpacity(0.15)
            : Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: saved ? Colors.orange.shade300 : Colors.blue.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            saved ? Icons.hourglass_top : Icons.info_outline,
            color: saved ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saved ? 'Pending Verification' : 'Complete Your Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: saved ? Colors.orange.shade800 : Colors.blue.shade800,
                  ),
                ),
                Text(
                  saved
                      ? 'Your listing is under review. You\'ll appear on the map once approved.'
                      : 'Fill in your details below to register as a Safe Space.',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        saved ? Colors.orange.shade700 : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A237E),
      ),
    );
  }
}