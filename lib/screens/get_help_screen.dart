import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GetHelpScreen extends StatefulWidget {
  final Map<String, dynamic> business;

  const GetHelpScreen({super.key, required this.business});

  @override
  State<GetHelpScreen> createState() => _GetHelpScreenState();
}

class _GetHelpScreenState extends State<GetHelpScreen> {
  final user = FirebaseAuth.instance.currentUser;

  String? _qrToken;
  String _status = 'pending'; // pending | verified | expired
  bool _loading = true;
  Timer? _expiryTimer;
  Timer? _pollTimer;
  int _secondsLeft = 3600; // 5 min expiry

  @override
  void initState() {
    super.initState();
    _generateToken();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateToken() async {
    // Create a one-time token document in Firestore
    final doc = await FirebaseFirestore.instance
        .collection('help_requests')
        .add({
          'userId': user?.uid,
          'userPhone': user?.phoneNumber,
          'businessId': widget.business['id'],
          'businessName': widget.business['name'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': DateTime.now().add(const Duration(hours: 1)),
        });

    setState(() {
      _qrToken = doc.id;
      _loading = false;
    });

    // Countdown timer
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _expireToken();
      }
    });

    // Poll Firestore every 3s to check if business scanned it
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      final snap = await FirebaseFirestore.instance
          .collection('help_requests')
          .doc(_qrToken)
          .get();
      final status = snap.data()?['status'] ?? 'pending';
      if (status == 'verified' && mounted) {
        _pollTimer?.cancel();
        _expiryTimer?.cancel();
        setState(() => _status = 'verified');
      }
    });
  }

  Future<void> _expireToken() async {
    if (_qrToken == null) return;
    await FirebaseFirestore.instance
        .collection('help_requests')
        .doc(_qrToken)
        .update({'status': 'expired'});
    if (mounted) setState(() => _status = 'expired');
  }

  Future<void> _regenerate() async {
    _expiryTimer?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _loading = true;
      _qrToken = null;
      _status = 'pending';
      _secondsLeft = 3600;
    });
    await _generateToken();
  }

  String get _timeFormatted {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isMental = (widget.business['safeSpaceType'] ?? '')
        .toString()
        .contains('Mental');
    final themeColor = isMental ? Colors.purple : Colors.blue.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: BackButton(color: themeColor),
        title: Text(
          widget.business['name'] ?? 'Get Help',
          style: TextStyle(color: themeColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _status == 'verified'
              ? _buildVerified(themeColor)
              : _status == 'expired'
              ? _buildExpired(themeColor)
              : _buildQrView(themeColor),
        ),
      ),
    );
  }

  // ─── QR View ─────────────────────────────────────────────────────────────────

  Widget _buildQrView(Color themeColor) {
    final isUrgent = _secondsLeft < 60;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code_2, color: themeColor, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Show this QR code to staff',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'A member of staff will scan this to verify you and begin helping.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: QrImageView(
            data: _qrToken!,
            version: QrVersions.auto,
            size: 220,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: themeColor,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Token ID (shortened for display)
        Text(
          'Code: ${_qrToken!.substring(0, 8).toUpperCase()}',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),

        // Countdown
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer,
              size: 16,
              color: isUrgent ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              'Expires in $_timeFormatted',
              style: TextStyle(
                color: isUrgent ? Colors.red : Colors.grey.shade600,
                fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // One-time use badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: const Text(
            '🔒 One-time use only',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const Spacer(),

        // Waiting indicator
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Waiting for staff to scan...',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ─── Verified ────────────────────────────────────────────────────────────────

  Widget _buildVerified(Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Verified!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Staff at ${widget.business['name']} have verified your request. Help is on the way.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ─── Expired ─────────────────────────────────────────────────────────────────

  Widget _buildExpired(Color themeColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_off, color: Colors.grey.shade400, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Code Expired',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'This QR code has expired. Generate a new one to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _regenerate,
            icon: const Icon(Icons.refresh),
            label: const Text('Generate New Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
