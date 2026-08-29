import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

const String _vpnApiUrl = 'http://194.48.198.154:8000/api/playlists/vpn-configs/';

http.Client _createInsecureClient() {
  final ioClient = HttpClient()
    ..badCertificateCallback = (_, __, ___) => true;
  return IOClient(ioClient);
}

// ============================================
// صفحه VPN
// ============================================
class VpnScreen extends StatefulWidget {
  const VpnScreen({super.key});

  @override
  State<VpnScreen> createState() => _VpnScreenState();
}

class _VpnScreenState extends State<VpnScreen>
    with SingleTickerProviderStateMixin {
  late FlutterV2ray _flutterV2ray;
  V2RayStatus _status = V2RayStatus();
  int _selectedIndex = 0;
  bool _isConnecting = false;
  bool _loadingConfigs = true;
  String? _loadError;
  List<Map<String, dynamic>> _configs = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _flutterV2ray = FlutterV2ray(
      onStatusChanged: (status) {
        if (mounted) setState(() => _status = status);
      },
    );
    _initV2ray();
    _fetchConfigs();
  }

  Future<void> _initV2ray() async {
    await _flutterV2ray.initializeV2Ray(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
  }

  Future<void> _fetchConfigs() async {
    setState(() { _loadingConfigs = true; _loadError = null; });
    try {
      final client = _createInsecureClient();
      final res = await client
          .get(Uri.parse(_vpnApiUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() {
          _configs = data.cast<Map<String, dynamic>>();
          _selectedIndex = 0;
          _loadingConfigs = false;
        });
      } else {
        setState(() { _loadError = 'خطای سرور: ${res.statusCode}'; _loadingConfigs = false; });
      }
    } catch (e) {
      setState(() { _loadError = 'اتصال به سرور ممکن نیست'; _loadingConfigs = false; });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isConnected => _status.state == 'CONNECTED';
  bool get _isDisconnected =>
      _status.state == 'DISCONNECTED' || _status.state == '';

  Future<void> _toggleVpn() async {
    if (_isConnecting) return;

    if (_isConnected) {
      _flutterV2ray.stopV2Ray();
      return;
    }

    final permission = await _flutterV2ray.requestPermission();
    if (!permission) {
      _snack('دسترسی VPN رد شد');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final configUrl = _configs[_selectedIndex]['url'] as String;
      final parser = FlutterV2ray.parseFromURL(configUrl);

      await _flutterV2ray.startV2Ray(
        remark: parser.remark,
        config: parser.getFullConfiguration(),
        proxyOnly: false,
      );
    } catch (e) {
      _snack('خطا در اتصال: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Color get _statusColor {
    switch (_status.state) {
      case 'CONNECTED':
        return const Color(0xFF00C853);
      case 'CONNECTING':
        return const Color(0xFFFFB300);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String get _statusText {
    if (_isConnecting) return 'در حال اتصال...';
    switch (_status.state) {
      case 'CONNECTED':
        return 'متصل';
      case 'CONNECTING':
        return 'در حال اتصال...';
      case 'DISCONNECTING':
        return 'در حال قطع...';
      default:
        return 'قطع';
    }
  }

  IconData get _statusIcon {
    switch (_status.state) {
      case 'CONNECTED':
        return Icons.shield;
      case 'CONNECTING':
        return Icons.shield_outlined;
      default:
        return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildStatusButton(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 28),
                    _buildServerList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.vpn_lock, color: Color(0xFF00C853), size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            'VPN',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _statusText,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton() {
    final bool active = _isConnected;

    return GestureDetector(
      onTap: _toggleVpn,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: (active || _isConnecting) ? _pulseAnim.value : 1.0,
            child: child,
          );
        },
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: active
                  ? [
                      const Color(0xFF00C853).withOpacity(0.35),
                      const Color(0xFF00C853).withOpacity(0.05),
                    ]
                  : [
                      Colors.white.withOpacity(0.06),
                      Colors.white.withOpacity(0.01),
                    ],
            ),
            border: Border.all(
              color: active
                  ? const Color(0xFF00C853)
                  : Colors.white.withOpacity(0.15),
              width: 2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C853).withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isConnecting)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFB300),
                    strokeWidth: 3,
                  ),
                )
              else
                Icon(
                  _statusIcon,
                  size: 56,
                  color: active ? const Color(0xFF00C853) : Colors.white38,
                ),
              const SizedBox(height: 10),
              Text(
                active ? 'قطع کن' : 'وصل شو',
                style: TextStyle(
                  color: active ? const Color(0xFF00C853) : Colors.white54,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final upload = _status.upload?.toString() ?? '0 B';
    final download = _status.download?.toString() ?? '0 B';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.arrow_upward_rounded,
            label: 'آپلود',
            value: upload,
            color: const Color(0xFF448AFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.arrow_downward_rounded,
            label: 'دانلود',
            value: download,
            color: const Color(0xFF00C853),
          ),
        ),
      ],
    );
  }

  Widget _buildServerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'انتخاب سرور',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            if (!_loadingConfigs)
              GestureDetector(
                onTap: _fetchConfigs,
                child: const Icon(Icons.refresh, color: Colors.white38, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (_loadingConfigs)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: Color(0xFF00C853),
                strokeWidth: 2,
              ),
            ),
          )
        else if (_loadError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.cloud_off, color: Colors.red, size: 32),
                const SizedBox(height: 8),
                Text(_loadError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _fetchConfigs,
                  child: const Text('تلاش دوباره', style: TextStyle(color: Color(0xFF00C853))),
                ),
              ],
            ),
          )
        else if (_configs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('هیچ سروری تعریف نشده', style: TextStyle(color: Colors.white38)),
            ),
          )
        else
          ...List.generate(_configs.length, (i) {
            final cfg = _configs[i];
            final selected = _selectedIndex == i;
            final flag = cfg['flag'] as String? ?? '🌐';
            final name = cfg['name'] as String? ?? 'سرور ${i + 1}';
            return GestureDetector(
              onTap: _isConnected ? null : () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF00C853).withOpacity(0.1)
                      : const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF00C853).withOpacity(0.6)
                        : Colors.white.withOpacity(0.07),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF00C853).withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(child: Text(flag, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: selected ? const Color(0xFF00C853) : Colors.white70,
                          fontSize: 15,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 20)
                    else
                      const Icon(Icons.radio_button_unchecked, color: Colors.white24, size: 20),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ============================================
// ویجت آمار
// ============================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
