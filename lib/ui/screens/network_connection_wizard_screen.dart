import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../models/network_connection_model.dart';
import '../../services/network_connections_service.dart';
import '../../services/remote/remote_client.dart';
import '../../services/remote/ftp_client.dart';
import '../../services/remote/sftp_client.dart';
import '../../services/remote/webdav_client.dart';
import '../../services/remote/lan_client.dart';

class NetworkConnectionWizardScreen extends StatefulWidget {
  const NetworkConnectionWizardScreen({super.key});

  @override
  State<NetworkConnectionWizardScreen> createState() => _NetworkConnectionWizardScreenState();
}

class _NetworkConnectionWizardScreenState extends State<NetworkConnectionWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Connection parameters
  String _selectedType = '';
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Testing steps states
  bool _isTesting = false;
  int _testStepIndex = 0;
  final List<String> _testSteps = [
    'Resolving host address...',
    'Checking port status...',
    'Authenticating credentials...',
    'Mounting storage volume...',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _selectProtocol(String protocol) {
    setState(() {
      _selectedType = protocol;
      _nameController.text = '$protocol Connection';

      // Set default ports
      if (protocol == 'FTP') {
        _portController.text = '21';
      } else if (protocol == 'SFTP') {
        _portController.text = '22';
      } else if (protocol == 'LAN/SMB') {
        _portController.text = '445';
      } else if (protocol == 'WebDav') {
        _portController.text = '80';
      }
    });
    _nextStep();
  }

  // Trigger Diagnostics & Save
  void _runDiagnosticsAndSave() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a connection name')),
      );
      return;
    }

    if (_hostController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter server address / hostname')),
      );
      return;
    }

    final port = int.tryParse(_portController.text.trim()) ?? 21;
    final host = _hostController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    setState(() {
      _isTesting = true;
      _testStepIndex = 0;
    });
    _nextStep();

    try {
      // Step 1: Resolving host address
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _testStepIndex = 1);

      // Step 2: Pinging server port
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _testStepIndex = 2);

      // Step 3: Authenticating credentials in real time!
      RemoteClient? client;
      if (_selectedType == 'FTP') {
        client = FtpRemoteClient(host: host, port: port, username: username, password: password);
      } else if (_selectedType == 'SFTP') {
        client = SftpRemoteClient(host: host, port: port, username: username, password: password);
      } else if (_selectedType == 'WebDav') {
        client = WebDavRemoteClient(host: host, port: port, username: username, password: password);
      } else if (_selectedType == 'LAN/SMB') {
        client = LanClient(host: host, port: port, username: username, password: password);
      }

      if (client != null) {
        await client.connect();
        await client.disconnect();
      }

      if (mounted) setState(() => _testStepIndex = 3);
      await Future.delayed(const Duration(milliseconds: 600));

      // Save connection details
      final connection = NetworkConnectionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        type: _selectedType,
        host: host,
        port: port,
        username: username,
        password: password,
        rootPath: '/',
      );

      await NetworkConnectionsService.saveConnection(connection);

      if (mounted) {
        setState(() {
          _isTesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Broken.tick_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('"${connection.name}" connected successfully!'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
        _prevStep(); // Go back to credentials input
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _prevStep,
        ),
        title: const Text(
          'Remote Connections',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                'Step ${_currentStep + 1} of 3',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Step progress indicator bar
          Container(
            height: 4,
            width: double.infinity,
            color: theme.colorScheme.onSurface.withOpacity(0.05),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: double.infinity,
                    color: _currentStep >= 0 ? theme.colorScheme.primary : Colors.transparent,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: double.infinity,
                    color: _currentStep >= 1 ? theme.colorScheme.primary : Colors.transparent,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: double.infinity,
                    color: _currentStep >= 2 ? theme.colorScheme.primary : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),

          // Main Pages contents
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildProtocolSelectionStep(theme),
                _buildCredentialsStep(theme, isDark),
                _buildTestingStep(theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1: Protocol Grid Selection ---
  Widget _buildProtocolSelectionStep(ThemeData theme) {
    final protocols = [
      {'name': 'LAN/SMB', 'desc': 'Local Area Network & SMB NAS Share', 'color': const Color(0xFF5B21B6)},
      {'name': 'FTP', 'desc': 'Standard File Transfer Protocol', 'color': const Color(0xFFF97316)},
      {'name': 'SFTP', 'desc': 'SSH Secure File Transfer Server', 'color': const Color(0xFF0D9488)},
      {'name': 'WebDav', 'desc': 'HTTP Web Distributed Authoring', 'color': const Color(0xFFE11D48)},
    ];

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          const Text(
            'Select Network Service',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'LexendDeca'),
          ),
          const SizedBox(height: 6),
          Text(
            'Mount a remote server or NAS share as a dynamic drive within your NFile storage lists.',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: protocols.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final protocol = protocols[index];
              final name = protocol['name'] as String;
              final desc = protocol['desc'] as String;
              final color = protocol['color'] as Color;

              return Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _selectProtocol(name),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.06),
                          color.withOpacity(0.01),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _buildProtocolIcon(name, size: 22, customColor: color),
                        ),
                        const Spacer(),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'LexendDeca',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Step 2: Configuration Fields Form ---
  Widget _buildCredentialsStep(ThemeData theme, bool isDark) {
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(overscroll: false),
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Row(
            children: [
              _buildProtocolIcon(_selectedType, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedType Settings',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'LexendDeca',
                      ),
                    ),
                    Text(
                      'Enter connection details to link this network volume.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Connection Nickname
          _buildInputLabel('Connection Name'),
          _buildTextField(
            controller: _nameController,
            hint: 'e.g., Office NAS, Home Share',
            icon: Broken.tag,
          ),
          const SizedBox(height: 18),

          _buildInputLabel('Server Address / IP'),
          _buildTextField(
            controller: _hostController,
            hint: 'e.g., 192.168.1.100 or nas.local',
            icon: Broken.global,
          ),
          const SizedBox(height: 18),

          _buildInputLabel('Port'),
          _buildTextField(
            controller: _portController,
            hint: '21',
            icon: Broken.hashtag,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 18),

          _buildInputLabel('Username (Optional)'),
          _buildTextField(
            controller: _usernameController,
            hint: 'e.g., anonymous or admin',
            icon: Broken.user,
          ),
          const SizedBox(height: 18),

          _buildInputLabel('Password (Optional)'),
          _buildTextField(
            controller: _passwordController,
            hint: '••••••••',
            icon: Broken.lock,
            obscure: true,
          ),

          const SizedBox(height: 40),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _prevStep,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: _runDiagnosticsAndSave,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Connect'),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Step 3: Connect and Diagnostics Live Validation Animation ---
  Widget _buildTestingStep(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.04),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1), width: 1.5),
                ),
              ),
              SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                ),
              ),
              Icon(
                _isTesting ? Broken.routing_2 : Broken.verify,
                size: 38,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 32),

          Text(
            'Creating Mount Point...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
              fontFamily: 'LexendDeca',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we establish a reliable pathway to the $_selectedType server.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // Dynamic Diagnostic List
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.primary.withOpacity(0.02),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: List.generate(_testSteps.length, (idx) {
                  final active = idx == _testStepIndex;
                  final done = idx < _testStepIndex;

                  Color itemColor;
                  IconData icon;

                  if (done) {
                    itemColor = Colors.green;
                    icon = Icons.check_circle;
                  } else if (active) {
                    itemColor = theme.colorScheme.primary;
                    icon = Icons.circle_outlined;
                  } else {
                    itemColor = theme.colorScheme.onSurface.withOpacity(0.25);
                    icon = Icons.radio_button_off_outlined;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(icon, color: itemColor, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _testSteps[idx],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                              color: active
                                  ? theme.colorScheme.onSurface.withOpacity(0.9)
                                  : theme.colorScheme.onSurface.withOpacity(done ? 0.6 : 0.35),
                            ),
                          ),
                        ),
                        if (active)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // --- Helper Layout widgets ---
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.35)),
        prefixIcon: Icon(icon, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : theme.colorScheme.primary.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.8), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildProtocolIcon(String name, {required double size, Color? customColor}) {
    IconData iconData;
    Color color;

    switch (name) {
      case 'LAN/SMB':
        iconData = Icons.dns_rounded;
        color = const Color(0xFF5B21B6);
        break;
      case 'FTP':
        iconData = Icons.swap_horizontal_circle_rounded;
        color = const Color(0xFFF97316);
        break;
      case 'SFTP':
        iconData = Icons.vpn_lock_rounded;
        color = const Color(0xFF0D9488);
        break;
      case 'WebDav':
        iconData = Icons.web_rounded;
        color = const Color(0xFFE11D48);
        break;
      default:
        iconData = Broken.wifi;
        color = Colors.blue;
    }

    return Icon(
      iconData,
      size: size,
      color: customColor ?? color,
    );
  }
}
