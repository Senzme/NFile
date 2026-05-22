import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../services/vault_service.dart';
import 'vault_explorer_screen.dart';

class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({super.key});

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> with SingleTickerProviderStateMixin {
  bool _isPasswordSet = false;
  bool _checkingPasswordStatus = true;
  
  // Setup Flow State
  bool _isConfirmMode = false;
  String _tempPassword = '';
  
  // Input State
  String _inputBuffer = '';
  String _message = 'Enter Password to Unlock';
  bool _isError = false;

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _checkPasswordStatus();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkPasswordStatus() async {
    final isSet = await VaultService.isPasswordSet();
    if (mounted) {
      setState(() {
        _isPasswordSet = isSet;
        _checkingPasswordStatus = false;
        _message = isSet ? 'Enter PIN to Unlock Wallet' : 'Set your 4-digit Wallet PIN';
      });
    }
  }

  void _onKeyPress(String key) {
    if (_inputBuffer.length >= 8) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      _inputBuffer += key;
    });

    if (_inputBuffer.length == 4 && !_isPasswordSet && !_isConfirmMode) {
      // First time set password: proceed to confirm
      Future.delayed(const Duration(milliseconds: 200), () {
        setState(() {
          _tempPassword = _inputBuffer;
          _inputBuffer = '';
          _isConfirmMode = true;
          _message = 'Confirm your 4-digit PIN';
        });
      });
    } else if (_inputBuffer.length == 4 && !_isPasswordSet && _isConfirmMode) {
      // Confirm password matching check
      Future.delayed(const Duration(milliseconds: 200), () async {
        if (_inputBuffer == _tempPassword) {
          HapticFeedback.mediumImpact();
          await VaultService.setPassword(_inputBuffer);
          if (mounted) {
            setState(() {
              _isPasswordSet = true;
              _isConfirmMode = false;
              _message = 'PIN Set Successfully!';
            });
            _unlockWallet(_inputBuffer);
          }
        } else {
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0.0);
          setState(() {
            _inputBuffer = '';
            _isError = true;
            _message = 'PINs do not match. Try again!';
          });
        }
      });
    } else if (_inputBuffer.length == 4 && _isPasswordSet) {
      // Unlock verification check
      Future.delayed(const Duration(milliseconds: 200), () async {
        final success = await VaultService.verifyPassword(_inputBuffer);
        if (success) {
          HapticFeedback.mediumImpact();
          _unlockWallet(_inputBuffer);
        } else {
          HapticFeedback.heavyImpact();
          _shakeController.forward(from: 0.0);
          setState(() {
            _inputBuffer = '';
            _isError = true;
            _message = 'Incorrect PIN. Try again!';
          });
        }
      });
    }
  }

  void _onDelete() {
    if (_inputBuffer.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isError = false;
      _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
    });
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _inputBuffer = '';
      _isError = false;
    });
  }

  void _unlockWallet(String password) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => VaultExplorerScreen(password: password),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_checkingPasswordStatus) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF020617)]
                : [theme.colorScheme.primaryContainer.withOpacity(0.4), theme.colorScheme.surface, theme.colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Back Button
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0, top: 12.0),
                  child: IconButton(
                    icon: const Icon(Broken.arrow_left, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              const Spacer(),

              // Logo & Title
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Broken.lock,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Private Wallet',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: _isError 
                          ? theme.colorScheme.error 
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // PIN Indicators
              ShakeWidget(
                controller: _shakeController,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _inputBuffer.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled 
                            ? theme.colorScheme.primary 
                            : Colors.transparent,
                        border: Border.all(
                          color: isFilled 
                              ? theme.colorScheme.primary 
                              : theme.colorScheme.onSurface.withOpacity(0.24),
                          width: 2,
                        ),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),

              const Spacer(flex: 2),

              // Keypad Widget
              _buildKeypad(theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('1'),
              _buildKeyButton('2'),
              _buildKeyButton('3'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('4'),
              _buildKeyButton('5'),
              _buildKeyButton('6'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('7'),
              _buildKeyButton('8'),
              _buildKeyButton('9'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionKeyButton(
                icon: Icons.clear_rounded,
                onPressed: _onClear,
                tooltip: 'Clear All',
              ),
              _buildKeyButton('0'),
              _buildActionKeyButton(
                icon: Icons.backspace_rounded,
                onPressed: _onDelete,
                tooltip: 'Backspace',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(40),
        splashColor: theme.colorScheme.primary.withOpacity(0.12),
        highlightColor: theme.colorScheme.primary.withOpacity(0.06),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1.5,
            ),
            color: isDark 
                ? Colors.white.withOpacity(0.02) 
                : Colors.black.withOpacity(0.01),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKeyButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        splashColor: theme.colorScheme.primary.withOpacity(0.12),
        highlightColor: theme.colorScheme.primary.withOpacity(0.06),
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }
}

// Shake Animation Helper Widget
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double shakeCount;
  final double shakeOffset;
  final AnimationController controller;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.controller,
    this.duration = const Duration(milliseconds: 350),
    this.shakeCount = 3,
    this.shakeOffset = 16.0,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final sineValue = sin(widget.shakeCount * 2 * pi * widget.controller.value);
        return Transform.translate(
          offset: Offset(sineValue * widget.shakeOffset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
