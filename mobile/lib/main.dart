import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:async';
import 'dart:ui';

import 'dart:isolate';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Material(
      color: Colors.transparent,
      child: OverlayFloatingPttButton(),
    ),
  ));
}

class OverlayFloatingPttButton extends StatefulWidget {
  const OverlayFloatingPttButton({super.key});

  @override
  State<OverlayFloatingPttButton> createState() => _OverlayFloatingPttButtonState();
}

class _OverlayFloatingPttButtonState extends State<OverlayFloatingPttButton> {
  String _pttState = "idle";
  String _pttButtonText = "PTT";
  Timer? _statusRequestTimer;
  ReceivePort? _overlayReceivePort;

  // Button and overlay size constants
  static const double kButtonSize = 90.0;
  static const double kOverlaySize = 100.0;

  // Screen size dimensions (retrieved dynamically during build)
  double _screenWidth = 360;
  double _screenHeight = 640;

  // Draggable state variables
  double _buttonX = 0;
  double _buttonY = 0;
  bool _isDragging = false;
  bool _isPttActive = false;

  // Initial touch & button position (for displacement-based drag detection)
  double _touchStartX = 0;
  double _touchStartY = 0;
  double _initialButtonX = 0;
  double _initialButtonY = 0;

  // Distance (px) finger must move before switching to drag mode
  static const double _dragThreshold = 10.0;

  // Last known position of the overlay window
  // -1 means not yet loaded from SharedPreferences
  double _lastOverlayX = -1;
  double _lastOverlayY = -1;

  @override
  void initState() {
    super.initState();
    _loadInitialPosition();

    // Register overlay_port so the main app can send us updates
    IsolateNameServer.removePortNameMapping('overlay_port');
    _overlayReceivePort = ReceivePort();
    IsolateNameServer.registerPortWithName(_overlayReceivePort!.sendPort, 'overlay_port');

    _overlayReceivePort!.listen((dynamic message) {
      if (message is Map<String, dynamic>) {
        if (message['type'] == 'ptt_status') {
          final status = message['status'];
          if (mounted) {
            setState(() {
              _pttState = status;
              if (status == 'talking') {
                _pttButtonText = "🗣️";
              } else if (status == 'busy') {
                _pttButtonText = "🛑";
              } else {
                _pttButtonText = "PTT";
              }
            });
          }
        }
      }
    });

    // Periodically request status from main app
    _statusRequestTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _sendAction('request_status');
    });
    // Immediate request
    _sendAction('request_status');
  }

  Future<void> _loadInitialPosition() async {
    try {
      // First try to load saved position from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedX = prefs.getDouble('overlay_pos_x');
      final savedY = prefs.getDouble('overlay_pos_y');

      if (savedX != null && savedY != null) {
        if (mounted) {
          setState(() {
            _lastOverlayX = savedX;
            _lastOverlayY = savedY;
          });
        }
        // Move overlay to saved position
        await FlutterOverlayWindow.moveOverlay(OverlayPosition(savedX, savedY));
      } else {
        // Default position: bottom-right corner
        // We'll set after we know screen size, use a reasonable default for now
        _lastOverlayX = 270;
        _lastOverlayY = 500;
        await FlutterOverlayWindow.moveOverlay(OverlayPosition(270, 500));
      }
    } catch (e) {
      debugPrint("Error loading position: $e");
      _lastOverlayX = 270;
      _lastOverlayY = 500;
    }
  }

  Future<void> _savePosition(double x, double y) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('overlay_pos_x', x);
      await prefs.setDouble('overlay_pos_y', y);
    } catch (e) {
      debugPrint("Error saving position: $e");
    }
  }

  void _sendAction(String action) {
    final mainAppPort = IsolateNameServer.lookupPortByName('main_app_port');
    if (mainAppPort != null) {
      mainAppPort.send({
        'action': action,
      });
    }
  }

  Future<void> _onPointerDown(PointerDownEvent event) async {
    // Record where the finger landed and where the button currently is
    _touchStartX = event.position.dx;
    _touchStartY = event.position.dy;
    final double bx = _lastOverlayX < 0 ? _screenWidth - kButtonSize - 20 : _lastOverlayX;
    final double by = _lastOverlayY < 0 ? _screenHeight - kButtonSize - 120 : _lastOverlayY;
    _initialButtonX = bx;
    _initialButtonY = by;

    if (mounted) {
      setState(() {
        _buttonX = bx;
        _buttonY = by;
        _isDragging = false;
        _isPttActive = true;
      });
    }

    // Start PTT immediately
    _sendAction('ptt_start');

    // Expand overlay to full screen so move events are received everywhere
    await FlutterOverlayWindow.resizeOverlay(-1, -1, false);
    await FlutterOverlayWindow.moveOverlay(const OverlayPosition(0, 0));
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!mounted) return;
    final double dx = event.position.dx - _touchStartX;
    final double dy = event.position.dy - _touchStartY;

    // Switch to drag mode once finger moves beyond threshold
    if (!_isDragging && (dx * dx + dy * dy) > (_dragThreshold * _dragThreshold)) {
      if (_isPttActive) {
        _sendAction('ptt_stop');
      }
      setState(() {
        _isPttActive = false;
        _isDragging = true;
      });
    }

    if (_isDragging) {
      setState(() {
        _buttonX = (_initialButtonX + dx).clamp(0.0, _screenWidth - kButtonSize);
        _buttonY = (_initialButtonY + dy).clamp(0.0, _screenHeight - kButtonSize);
      });
    }
  }

  Future<void> _onPointerUp(PointerUpEvent event) async {
    if (_isPttActive) {
      // Finger lifted without dragging — stop PTT
      _sendAction('ptt_stop');
      if (mounted) setState(() { _isPttActive = false; });
    }

    if (_isDragging) {
      // Save new position
      _lastOverlayX = _buttonX;
      _lastOverlayY = _buttonY;
      _savePosition(_lastOverlayX, _lastOverlayY);
      if (mounted) setState(() { _isDragging = false; });
    }

    // Restore compact size at saved position
    if (_lastOverlayX >= 0) {
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(_lastOverlayX, _lastOverlayY));
    }
    await FlutterOverlayWindow.resizeOverlay(kOverlaySize.toInt(), kOverlaySize.toInt(), false);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isPttActive) {
      _sendAction('ptt_stop');
    }
    if (mounted) {
      setState(() {
        _isDragging = false;
        _isPttActive = false;
      });
    }
    if (_lastOverlayX >= 0) {
      FlutterOverlayWindow.moveOverlay(OverlayPosition(_lastOverlayX, _lastOverlayY));
    }
    FlutterOverlayWindow.resizeOverlay(kOverlaySize.toInt(), kOverlaySize.toInt(), false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;

    Color btnColor = const Color(0xFF0EA5E9);
    if (_pttState == "talking") {
      btnColor = const Color(0xFF2ECC71);
    } else if (_pttState == "busy") {
      btnColor = const Color(0xFFEF4444);
    }

    final buttonWidget = Container(
      width: kButtonSize,
      height: kButtonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: btnColor,
        boxShadow: [
          BoxShadow(
            color: btnColor.withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 3,
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 3),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isPttActive ? "🗣️" : _pttButtonText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (!_isPttActive && _pttButtonText == "PTT")
            const Text(
              "PUSH",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
        ],
      ),
    );

    if (_isDragging) {
      // Drag mode: full-screen transparent catcher + floating button
      return Stack(
        children: [
          // Full-screen invisible layer to catch all pointer events during drag
          Positioned.fill(
            child: Listener(
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Container(color: Colors.transparent),
            ),
          ),
          // PTT button follows finger
          Positioned(
            left: _buttonX,
            top: _buttonY,
            child: buttonWidget,
          ),
        ],
      );
    }

    // Compact mode: single button centered in the overlay window
    return Center(
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: buttonWidget,
      ),
    );
  }

  @override
  void dispose() {
    _statusRequestTimer?.cancel();
    IsolateNameServer.removePortNameMapping('overlay_port');
    _overlayReceivePort?.close();
    super.dispose();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CamboComApp());
}

class CamboComApp extends StatefulWidget {
  const CamboComApp({super.key});

  @override
  State<CamboComApp> createState() => _CamboComAppState();
}

class _CamboComAppState extends State<CamboComApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('ptt_token');
      setState(() {
        _isLoggedIn = token != null && token.isNotEmpty;
      });
    } catch (e) {
      debugPrint("[Session Check Error] $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CamboCom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF0EA5E9), // Cyan 500
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),
          secondary: Color(0xFF38BDF8),
          background: const Color(0xFF0F172A),
          surface: Color(0xFF1E293B), // Slate 800
          onBackground: Colors.white,
          onSurface: Color(0xFFF1F5F9), // Slate 100
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF1F5F9)),
          bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
        ),
      ),
      home: _isLoading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0EA5E9),
                ),
              ),
            )
          : (_isLoggedIn ? const HomeScreen() : const LoginScreen()),
    );
  }
}
