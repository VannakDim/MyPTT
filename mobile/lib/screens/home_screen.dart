import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../services/image_service.dart';
import '../models/user.model.dart';
import 'login_screen.dart';
import 'console_tab.dart';
import 'users_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _username = '';
  String _email = '';
  String _role = 'user';
  String _avatarStr = '';
  String? _token;

  List<Group> _myGroups = [];
  Group? _selectedGroup;
  bool _showLogs = false;
  bool _showPttButton = true;
  String _currentView = 'chat'; // 'chat' or 'users'
  final GlobalKey<ConsoleTabState> _consoleKey = GlobalKey<ConsoleTabState>();

  final List<String> _presetEmojis = [
    '👨‍✈️', '👩‍✈️', '👮', '🕵️', '👷', '🧑‍⚕️', '🧑‍💻', '🦊', '🦁', '🐯', '🐼', '🐨', '🚀', '🔥', '💎', '🎯'
  ];
  final List<Color> _presetColors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal, Colors.amber, Colors.blueGrey
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString('ptt_token');
      _username = prefs.getString('ptt_username') ?? 'User';
      _email = prefs.getString('ptt_email') ?? '';
      _role = prefs.getString('ptt_role') ?? 'user';
      _avatarStr = prefs.getString('ptt_avatar') ?? '';
      _showPttButton = prefs.getBool('ptt_show_button') ?? true;
    });
    if (_token != null) {
      _fetchGroups();
    }
  }

  Future<void> _savePttButtonConfig(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ptt_show_button', val);
    setState(() {
      _showPttButton = val;
    });
  }

  Future<void> _fetchGroups() async {
    try {
      final groups = await ApiService.getMyGroups();
      setState(() {
        _myGroups = groups;
        if (groups.isNotEmpty) {
          _selectedGroup = groups.first;
        }
      });
    } catch (e) {
      debugPrint("Failed fetching groups: $e");
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  // Helper: Parse avatar details
  Map<String, dynamic> _parseAvatar(String str) {
    if (str.isEmpty) return {'type': 'initial', 'value': _username.isNotEmpty ? _username[0].toUpperCase() : 'U'};
    try {
      return jsonDecode(str);
    } catch (e) {
      if (str.startsWith('data:image/')) {
        return {'type': 'image', 'value': str};
      }
      return {'type': 'initial', 'value': str[0].toUpperCase()};
    }
  }

  // Helper: Get color from username hash for dynamic initials background
  Color _getHashColor(String name) {
    final colors = _presetColors;
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  // Get custom avatar widget based on parsed details
  Widget _buildAvatarWidget(String str, double size) {
    final parsed = _parseAvatar(str);
    if (parsed['type'] == 'image') {
      final base64Val = parsed['value'] as String;
      try {
        final cleanBase64 = base64Val.split(',').last;
        final bytes = base64Decode(cleanBase64);
        return CircleAvatar(
          radius: size,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        print("Image decoding error: $e");
      }
    } else if (parsed['type'] == 'emoji') {
      final colorHex = parsed['bg'] as String?;
      Color bgColor = Colors.blue;
      if (colorHex != null) {
        try {
          bgColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        } catch (e) {
          bgColor = Colors.blue;
        }
      }
      return CircleAvatar(
        radius: size,
        backgroundColor: bgColor,
        child: Text(
          parsed['value'] ?? '🦊',
          style: TextStyle(fontSize: size * 1.1),
        ),
      );
    }

    // Default Fallback: Initial letter with dynamic hash color
    return CircleAvatar(
      radius: size,
      backgroundColor: _getHashColor(_username),
      child: Text(
        parsed['value'] ?? 'U',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.9,
        ),
      ),
    );
  }

  void _openEditProfileDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return EditProfileDialog(
          initialName: _username,
          initialEmail: _email,
          avatarStr: _avatarStr,
          presetEmojis: _presetEmojis,
          presetColors: _presetColors,
          onSaveSuccess: (newName, newEmail, newAvatar) {
            setState(() {
              _username = newName;
              _email = newEmail;
              _avatarStr = newAvatar;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ រក្សាទុកព័ត៌មានផ្ទាល់ខ្លួនដោយជោគជ័យ!")),
            );
          },
        );
      },
    );
  }

  void _startPrivateCall(String targetUsername) {
    setState(() {
      _currentView = 'chat';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consoleKey.currentState?.makeCall(targetUsername);
    });
  }

  void _openCallListDialog() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    final users = await ApiService.getAllUsers();
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("📞 ជ្រើសរើសសមាជិកដើម្បីហៅទូរស័ព្ទ", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 300,
            height: 380,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i];
                if (u.name.toLowerCase() == _username.toLowerCase()) return const SizedBox.shrink();
                
                return ListTile(
                  leading: _buildAvatarWidget(u.avatar ?? '', 16),
                  title: Text(u.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(u.email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                  trailing: const Icon(Icons.call_rounded, color: Color(0xFF2ECC71), size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _startPrivateCall(u.name);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          _currentView == 'users'
              ? "👥 គ្រប់គ្រងអ្នកប្រើប្រាស់"
              : (_selectedGroup != null ? "📻 ${_selectedGroup!.displayName}" : "CamboCom"),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F172A),
        child: Column(
          children: [
            // Drawer Header
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _openEditProfileDialog();
              },
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                ),
                currentAccountPicture: _buildAvatarWidget(_avatarStr, 32),
                accountName: Row(
                  children: [
                    Text(
                      _username,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _role == 'admin' ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _role.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                accountEmail: Text(
                  _email,
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                ),
              ),
            ),

            // Channels Section
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 12, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "ប៉ុស្តិ៍វិទ្យុទាក់ទង",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            // List Channels
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _myGroups.length,
                itemBuilder: (context, i) {
                  final g = _myGroups[i];
                  final isSelected = _selectedGroup?.id == g.id && _currentView == 'chat';
                  
                  return ListTile(
                    leading: Icon(
                      Icons.radio_rounded,
                      color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                      size: 20,
                    ),
                    title: Text(
                      g.displayName,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    tileColor: isSelected ? const Color(0xFF1E293B).withOpacity(0.3) : null,
                    onTap: () {
                      setState(() {
                        _selectedGroup = g;
                        _currentView = 'chat';
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            
            const Divider(color: Color(0xFF334155), height: 1),

            // General Menu Section
            ListTile(
              leading: const Icon(Icons.call_rounded, color: Color(0xFF2ECC71), size: 20),
              title: const Text("📞 ហៅទូរស័ព្ទ (Private Call)", style: TextStyle(color: Colors.white, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _openCallListDialog();
              },
            ),

            if (_role == 'admin')
              ListTile(
                leading: const Icon(Icons.people_alt_rounded, color: Color(0xFF38BDF8), size: 20),
                title: const Text("👥 គ្រប់គ្រងអ្នកប្រើប្រាស់", style: TextStyle(color: Colors.white, fontSize: 13)),
                tileColor: _currentView == 'users' ? const Color(0xFF1E293B) : null,
                onTap: () {
                  setState(() {
                    _currentView = 'users';
                  });
                  Navigator.pop(context);
                },
              ),

            SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined, color: Color(0xFFE2E8F0), size: 20),
              title: const Text("បង្ហាញ System Logs", style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showLogs,
              activeColor: const Color(0xFF38BDF8),
              onChanged: (val) {
                setState(() {
                  _showLogs = val;
                });
              },
            ),

            SwitchListTile(
              secondary: const Icon(Icons.radio_button_checked_rounded, color: Color(0xFFE2E8F0), size: 20),
              title: const Text("បង្ហាញប៊ូតុង PTT", style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showPttButton,
              activeColor: const Color(0xFF38BDF8),
              onChanged: (val) {
                _savePttButtonConfig(val);
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 20),
              title: const Text("🚪 ចាកចេញពីគណនី", style: TextStyle(color: Color(0xFFF87171), fontSize: 13, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentView == 'users' && _role == 'admin') {
      return UsersTab(userToken: _token!);
    }
    return ConsoleTab(
      key: _consoleKey,
      userToken: _token!,
      selectedGroup: _selectedGroup,
      myGroups: _myGroups,
      showLogs: _showLogs,
      showPttButton: _showPttButton,
    );
  }
}

// Dialog Component for Profile Customization and Editing
class EditProfileDialog extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String avatarStr;
  final List<String> presetEmojis;
  final List<Color> presetColors;
  final Function(String, String, String) onSaveSuccess;

  const EditProfileDialog({
    super.key,
    required this.initialName,
    required this.initialEmail,
    required this.avatarStr,
    required this.presetEmojis,
    required this.presetColors,
    required this.onSaveSuccess,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  bool _isSaving = false;
  bool _isCompressing = false;
  String? _errorMsg;

  // Avatar Config Panel State
  String _selectedEmoji = '🦊';
  Color _selectedBgColor = Colors.blue;
  String? _selectedImageBase64;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _emailController.text = widget.initialEmail;
    _tabController = TabController(length: 2, vsync: this);

    _initAvatarState();
  }

  void _initAvatarState() {
    if (widget.avatarStr.isEmpty) return;
    try {
      final parsed = jsonDecode(widget.avatarStr);
      if (parsed['type'] == 'image') {
        _selectedImageBase64 = parsed['value'];
        _tabController.index = 1;
      } else if (parsed['type'] == 'emoji') {
        _selectedEmoji = parsed['value'] ?? '🦊';
        final colorHex = parsed['bg'] as String?;
        if (colorHex != null) {
          _selectedBgColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        }
        _tabController.index = 0;
      }
    } catch (e) {
      if (widget.avatarStr.startsWith('data:image/')) {
        _selectedImageBase64 = widget.avatarStr;
        _tabController.index = 1;
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _isCompressing = true;
      _errorMsg = null;
    });

    try {
      final file = File(result.files.first.path!);
      final bytes = await file.readAsBytes();
      
      // Compress image to JPEG format base64
      final base64Str = await ImageService.compressToBase64(bytes, maxDimension: 800, quality: 75);
      
      setState(() {
        _selectedImageBase64 = base64Str;
      });
    } catch (e) {
      setState(() {
        _errorMsg = "មិនអាចបង្ហោះរូបភាព៖ $e";
      });
    } finally {
      setState(() {
        _isCompressing = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    String avatarJson = '';
    if (_tabController.index == 1 && _selectedImageBase64 != null) {
      avatarJson = jsonEncode({'type': 'image', 'value': _selectedImageBase64});
    } else {
      final colorHex = '#${_selectedBgColor.value.toRadixString(16).substring(2)}';
      avatarJson = jsonEncode({
        'type': 'emoji',
        'value': _selectedEmoji,
        'bg': colorHex,
      });
    }

    final result = await ApiService.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
      avatar: avatarJson,
    );

    setState(() {
      _isSaving = false;
    });

    if (result['success']) {
      final User updatedUser = result['user'];
      widget.onSaveSuccess(updatedUser.name, updatedUser.email, updatedUser.avatar ?? '');
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _errorMsg = result['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("✏️ កែប្រែព័ត៌មានផ្ទាល់ខ្លួន", style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "ឈ្មោះ",
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? "សូមបញ្ចូលឈ្មោះ" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "អ៊ីមែល",
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                  validator: (val) => (val == null || val.isEmpty) ? "សូមបញ្ចូលអ៊ីមែល" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Password ថ្មី (ទុកទទេរបើមិនចង់ប្តូរ)",
                    labelStyle: TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(height: 25),

                // Avatar Settings Title
                const Text(
                  "រូបសញ្ញាគណនី (Avatar)",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF38BDF8),
                  labelColor: const Color(0xFF38BDF8),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  tabs: const [
                    Tab(text: "🤩 Emoji"),
                    Tab(text: "🖼️ បង្ហោះរូបភាព"),
                  ],
                ),
                const SizedBox(height: 15),

                // Tab Bar Views Custom Panel
                SizedBox(
                  height: 180,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Emoji Tab Screen
                      Column(
                        children: [
                          // Preview circle
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _selectedBgColor,
                            child: Text(_selectedEmoji, style: const TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(height: 10),
                          // Preset Emojis Grid
                          Expanded(
                            child: GridView.builder(
                              itemCount: widget.presetEmojis.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 8,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                              itemBuilder: (context, i) {
                                final em = widget.presetEmojis[i];
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedEmoji = em),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _selectedEmoji == em
                                          ? const Color(0xFF38BDF8).withOpacity(0.2)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: _selectedEmoji == em ? const Color(0xFF38BDF8) : Colors.transparent,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(em, style: const TextStyle(fontSize: 16)),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Preset Colors Grid
                          SizedBox(
                            height: 25,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.presetColors.length,
                              itemBuilder: (context, i) {
                                final col = widget.presetColors[i];
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedBgColor = col),
                                  child: Container(
                                    width: 25,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: col,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedBgColor == col ? Colors.white : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Image Upload Tab Screen
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isCompressing) ...[
                            const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                            const SizedBox(height: 10),
                            const Text("កំពុងបង្ហាប់រូបភាព...", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          ] else if (_selectedImageBase64 != null) ...[
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: MemoryImage(
                                base64Decode(_selectedImageBase64!.split(',').last),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => setState(() => _selectedImageBase64 = null),
                              child: const Text("លុបរូបភាពចេញ", style: TextStyle(color: Colors.redAccent)),
                            ),
                          ] else ...[
                            const Icon(Icons.image_outlined, size: 50, color: Color(0xFF64748B)),
                            const SizedBox(height: 10),
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                              label: const Text("ជ្រើសរើសរូបភាព", style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text("បោះបង់", style: TextStyle(color: Color(0xFF94A3B8))),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
          child: _isSaving
              ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("រក្សាទុក", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
