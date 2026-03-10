import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'account_screen.dart';
import 'get_help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _sosSent = false;
  int _currentIndex = 0;

  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(52.6369, -1.1398);
  String _currentStreet = 'Locating...';
  StreamSubscription<Position>? _positionStream;

  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _businesses = [];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadBusinesses();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    Position pos = await Geolocator.getCurrentPosition();
    _updatePosition(pos);

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_updatePosition);
  }

  void _updatePosition(Position pos) async {
    if (!mounted) return;
    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() => _currentPosition = latLng);
    _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _currentStreet =
              p.street ?? p.thoroughfare ?? p.name ?? 'Unknown Street';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBusinesses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .get();

      final businesses = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      final Set<Marker> newMarkers = {};

      for (final biz in businesses) {
        double? lat;
        double? lng;

        if (biz['location'] is GeoPoint) {
          final geo = biz['location'] as GeoPoint;
          lat = geo.latitude;
          lng = geo.longitude;
        } else if (biz['lat'] != null && biz['lng'] != null) {
          lat = (biz['lat'] as num).toDouble();
          lng = (biz['lng'] as num).toDouble();
        }

        if (lat == null || lng == null) continue;

        final isMental = (biz['safeSpaceType'] ?? '').toString().contains(
          'Mental',
        );
        final markerColor = isMental
            ? BitmapDescriptor.hueViolet
            : BitmapDescriptor.hueAzure;

        newMarkers.add(
          Marker(
            markerId: MarkerId(biz['id']),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(markerColor),
            infoWindow: InfoWindow(
              title: biz['name'] ?? 'Safe Space',
              snippet: biz['safeSpaceType'] ?? biz['businessType'] ?? '',
            ),
            onTap: () => _showBusinessSheet(biz),
          ),
        );
      }

      setState(() {
        _businesses = businesses;
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    } catch (e) {
      debugPrint('Error loading businesses: $e');
    }
  }

  // ─── Find Nearest ─────────────────────────────────────────────────────────────

  void _flyToNearest(bool mental) {
    final filtered = _businesses.where((biz) {
      final isMental = (biz['safeSpaceType'] ?? '').toString().contains(
        'Mental',
      );
      // Only include businesses that have coordinates
      final hasCoords =
          (biz['location'] is GeoPoint) ||
          (biz['lat'] != null && biz['lng'] != null);
      return isMental == mental && hasCoords;
    }).toList();

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mental
                ? 'No Mental Wellbeing Centres found nearby'
                : 'No Immediate Help Centres found nearby',
          ),
        ),
      );
      return;
    }

    filtered.sort((a, b) => _distanceTo(a).compareTo(_distanceTo(b)));

    final nearest = filtered.first;
    double? lat;
    double? lng;

    if (nearest['location'] is GeoPoint) {
      lat = (nearest['location'] as GeoPoint).latitude;
      lng = (nearest['location'] as GeoPoint).longitude;
    } else if (nearest['lat'] != null) {
      lat = (nearest['lat'] as num).toDouble();
      lng = (nearest['lng'] as num).toDouble();
    }

    if (lat == null || lng == null) return;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _showBusinessSheet(nearest);
    });
  }

  double _distanceTo(Map<String, dynamic> biz) {
    double? lat;
    double? lng;

    if (biz['location'] is GeoPoint) {
      lat = (biz['location'] as GeoPoint).latitude;
      lng = (biz['location'] as GeoPoint).longitude;
    } else if (biz['lat'] != null) {
      lat = (biz['lat'] as num).toDouble();
      lng = (biz['lng'] as num).toDouble();
    }

    if (lat == null || lng == null) return double.infinity;

    return Geolocator.distanceBetween(
      _currentPosition.latitude,
      _currentPosition.longitude,
      lat,
      lng,
    );
  }

  // ─── Business Detail Bottom Sheet ────────────────────────────────────────────

  void _showBusinessSheet(Map<String, dynamic> biz) {
    final isMental = (biz['safeSpaceType'] ?? '').toString().contains('Mental');
    final typeColor = isMental ? Colors.purple : Colors.blue.shade700;
    final typeLabel = isMental
        ? '🧠 Mental Wellbeing Centre'
        : '🆘 Immediate Help Centre';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: typeColor.withOpacity(0.4)),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                biz['name'] ?? 'Safe Space',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              if (biz['businessType'] != null)
                Text(
                  biz['businessType'],
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              const Divider(height: 24),
              if (biz['address'] != null || biz['postcode'] != null)
                _infoRow(
                  Icons.location_on,
                  [
                    biz['address'],
                    biz['postcode'],
                  ].where((v) => v != null).join(', '),
                  typeColor,
                ),
              if (biz['phone'] != null)
                _infoRow(Icons.phone, biz['phone'], typeColor),
              if (biz['open24h'] == true)
                _infoRow(Icons.access_time, 'Open 24 hours', typeColor),
              if (biz['disabledAccess'] == true)
                _infoRow(
                  Icons.accessible,
                  'Disabled / wheelchair access',
                  typeColor,
                ),
              if (biz['description'] != null &&
                  biz['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'About',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  biz['description'],
                  style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GetHelpScreen(business: biz),
                    ),
                  );
                },
                icon: const Icon(Icons.health_and_safety),
                label: const Text(
                  'Get Help Here',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // ─── Map Style ───────────────────────────────────────────────────────────────

  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212a37"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#746855"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#515c6d"}]}
]
''';

  Widget _buildLegend() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendItem(Colors.blue.shade700, '🆘 Immediate Help'),
            const SizedBox(height: 4),
            _legendItem(Colors.purple, '🧠 Mental Wellbeing'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ─── Tabs ─────────────────────────────────────────────────────────────────────

  Widget _buildMapTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            'Current Street (Live): $_currentStreet',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition,
                  zoom: 17,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                markers: _markers,
                onMapCreated: (controller) {
                  _mapController = controller;
                  controller.setMapStyle(_darkMapStyle);
                },
              ),
              _buildLegend(),
            ],
          ),
        ),
        // ─── Bottom Buttons ───────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _flyToNearest(false),
                      icon: const Text('🆘', style: TextStyle(fontSize: 15)),
                      label: const Text(
                        'Nearest Immediate Help',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _flyToNearest(true),
                      icon: const Text('🧠', style: TextStyle(fontSize: 15)),
                      label: const Text(
                        'Nearest Mental Health',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Help & Safety Tips',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _helpCard(
            Icons.health_and_safety,
            'SOS Alert',
            'Tap "Emergency SOS" to send your location to emergency contacts immediately.',
          ),
          _helpCard(
            Icons.qr_code,
            'QR Code',
            'Your QR code links to your SafeSpace profile. Share it with trusted contacts.',
          ),
          _helpCard(
            Icons.location_on,
            'Live Location',
            'Your location is tracked in real time so help can find you.',
          ),
          _helpCard(
            Icons.phone,
            'Emergency',
            'Always call 999 in a life-threatening emergency.',
          ),
        ],
      ),
    );
  }

  Widget _helpCard(IconData icon, String title, String body) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF9C27B0), size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [_buildMapTab(), _buildHelpTab()];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F0FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Color(0xFFEDE7F6),
            child: Icon(Icons.person, color: Color(0xFF9C27B0)),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountScreen()),
          ),
        ),
        title: Text(
          '${_markers.length} Safe Space${_markers.length == 1 ? '' : 's'} nearby',
          style: const TextStyle(color: Colors.black87, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF9C27B0),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.help_outline),
            label: 'Help',
          ),
        ],
      ),
    );
  }
}
