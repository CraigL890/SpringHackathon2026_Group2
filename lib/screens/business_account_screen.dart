import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessAccountScreen extends StatefulWidget {
  const BusinessAccountScreen({super.key});

  @override
  State<BusinessAccountScreen> createState() => _BusinessAccountScreenState();
}

class _BusinessAccountScreenState extends State<BusinessAccountScreen> {
  final user = FirebaseAuth.instance.currentUser;

  bool _receiveSOSAlerts = true;
  bool _shareLocationWithUsers = true;
  bool _listedAsActiveSafeSpace = true;
  bool _notifyOnNearbyIncident = false;

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = user?.email ?? user?.phoneNumber ?? 'Business Account';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Business Account',
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: const Color(0xFFE3F2FD),
                    child: Icon(
                      Icons.store,
                      color: const Color(0xFF1565C0),
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Registered SafeSpace',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _sectionLabel('Alert Preferences'),
            _settingsTile(
              icon: Icons.sos,
              title: 'Receive SOS Alerts',
              subtitle: 'Get notified when someone nearby sends an SOS signal',
              value: _receiveSOSAlerts,
              onChanged: (v) => setState(() => _receiveSOSAlerts = v),
            ),
            _settingsTile(
              icon: Icons.campaign_outlined,
              title: 'Nearby Incident Alerts',
              subtitle: 'Be notified about safety incidents in your wider area',
              value: _notifyOnNearbyIncident,
              onChanged: (v) => setState(() => _notifyOnNearbyIncident = v),
            ),

            const SizedBox(height: 20),

            _sectionLabel('Visibility'),
            _settingsTile(
              icon: Icons.storefront_outlined,
              title: 'Listed as Active SafeSpace',
              subtitle:
                  'Show your location to users looking for a safe space nearby',
              value: _listedAsActiveSafeSpace,
              onChanged: (v) => setState(() => _listedAsActiveSafeSpace = v),
            ),
            _settingsTile(
              icon: Icons.location_on_outlined,
              title: 'Share Location with Users',
              subtitle:
                  'Allow SafeSpace users to see your exact location on their map',
              value: _shareLocationWithUsers,
              onChanged: (v) => setState(() => _shareLocationWithUsers = v),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE3F2FD),
          child: Icon(icon, color: const Color(0xFF1565C0), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF1565C0),
        ),
      ),
    );
  }
}
