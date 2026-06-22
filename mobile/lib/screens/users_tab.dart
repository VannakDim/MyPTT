import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.model.dart';

class UsersTab extends StatefulWidget {
  final String userToken;
  const UsersTab({super.key, required this.userToken});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<User> _users = [];
  List<Group> _allGroups = [];
  bool _isLoading = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchUsersAndGroups();
  }

  Future<void> _fetchUsersAndGroups() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await ApiService.getAllUsers();
      final groups = await ApiService.getAllGroups();
      setState(() {
        _users = list;
        _allGroups = groups;
      });
    } catch (e) {
      print("Failed loading users data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<User> _getFilteredUsers() {
    if (_searchQuery.trim().isEmpty) return _users;
    final query = _searchQuery.toLowerCase();
    return _users.where((u) {
      return u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query);
    }).toList();
  }

  void _openCreateUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UserFormDialog(
          isEditMode: false,
          availableGroups: _allGroups,
          onSaveSuccess: () {
            _fetchUsersAndGroups();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ បង្កើតអ្នកប្រើប្រាស់ថ្មីដោយជោគជ័យ!")),
            );
          },
        );
      },
    );
  }

  void _openEditUserDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return UserFormDialog(
          isEditMode: true,
          user: user,
          availableGroups: _allGroups,
          onSaveSuccess: () {
            _fetchUsersAndGroups();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ កែប្រែព័ត៌មានអ្នកប្រើប្រាស់ដោយជោគជ័យ!")),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("លុបគណនី", style: TextStyle(color: Colors.white)),
          content: Text(
            "តើអ្នកពិតជាចង់លុបគណនី \"${user.name}\" មែនទេ?",
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("បោះបង់", style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              child: const Text("លុបគណនី", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final result = await ApiService.deleteUser(user.id);
      if (result['success']) {
        _fetchUsersAndGroups();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ ${result['message']}")),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ ${result['message']}")),
          );
        }
      }
    }
  }

  // Helper: Build avatar dynamically based on db string
  Widget _buildUserAvatar(User user, double size) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      try {
        final parsed = jsonDecode(user.avatar!);
        if (parsed['type'] == 'image') {
          final cleanBase64 = (parsed['value'] as String).split(',').last;
          return CircleAvatar(
            radius: size,
            backgroundImage: MemoryImage(base64Decode(cleanBase64)),
          );
        } else if (parsed['type'] == 'emoji') {
          final hexColor = parsed['bg'] as String? ?? '#3498db';
          final bgColor = Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
          return CircleAvatar(
            radius: size,
            backgroundColor: bgColor,
            child: Text(parsed['value'] ?? '🦊', style: TextStyle(fontSize: size * 1.1)),
          );
        }
      } catch (e) {}
    }
    // Fallback
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
    final color = colors[user.name.length % colors.length];
    return CircleAvatar(
      radius: size,
      backgroundColor: color,
      child: Text(
        user.name[0].toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: size * 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _getFilteredUsers();

    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Header Actions
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "👥 គ្រប់គ្រងអ្នកប្រើប្រាស់",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateUserDialog,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text("បង្កើតថ្មី", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "🔍 ស្វែងរកតាម ឈ្មោះ ឬ អ៊ីមែល...",
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          const SizedBox(height: 10),

          // Users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                    ? const Center(child: Text("គ្មានអ្នកប្រើប្រាស់ឡើយ", style: TextStyle(color: Color(0xFF64748B))))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, i) {
                          final user = filteredUsers[i];
                          return Card(
                            color: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: Color(0xFF334155)),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildUserAvatar(user, 20),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              user.email,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Role badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: user.role == 'admin'
                                              ? const Color(0xFFEF4444).withOpacity(0.15)
                                              : const Color(0xFF64748B).withOpacity(0.15),
                                          border: Border.all(
                                            color: user.role == 'admin'
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFF64748B),
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          user.role.toUpperCase(),
                                          style: TextStyle(
                                            color: user.role == 'admin'
                                                ? const Color(0xFFF87171)
                                                : const Color(0xFFCBD5E1),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(color: Color(0xFF334155), height: 1),
                                  const SizedBox(height: 8),

                                  // Channels / Groups list
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("ប៉ុស្តិ៍វិទ្យុ៖ ", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: (user.groups == null || user.groups!.isEmpty)
                                              ? [
                                                  const Text(
                                                    "គ្មានប៉ុស្តិ៍",
                                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontStyle: FontStyle.italic),
                                                  )
                                                ]
                                              : user.groups!.map((g) {
                                                  return Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF0F172A),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFF334155)),
                                                    ),
                                                    child: Text(
                                                      "📻 ${g.displayName}",
                                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                                    ),
                                                  );
                                                }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(color: Color(0xFF334155), height: 1),

                                  // Edit & Delete actions
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _openEditUserDialog(user),
                                        icon: const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF38BDF8)),
                                        label: const Text("កែប្រែ", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _deleteUser(user),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFF87171)),
                                        label: const Text("លុប", style: TextStyle(color: Color(0xFFF87171), fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Dialog Component for Admin User Form (Create / Edit)
class UserFormDialog extends StatefulWidget {
  final bool isEditMode;
  final User? user;
  final List<Group> availableGroups;
  final Function() onSaveSuccess;

  const UserFormDialog({
    super.key,
    required this.isEditMode,
    this.user,
    required this.availableGroups,
    required this.onSaveSuccess,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _role = 'user';
  List<int> _selectedGroupIds = [];
  bool _isSaving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode && widget.user != null) {
      _nameController.text = widget.user!.name;
      _emailController.text = widget.user!.email;
      _role = widget.user!.role;
      _selectedGroupIds = widget.user!.groups?.map((g) => g.id).toList() ?? [];
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    final payload = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'role': _role,
      'groups': _selectedGroupIds,
    };

    if (_passwordController.text.isNotEmpty) {
      payload['password'] = _passwordController.text;
    }

    Map<String, dynamic> result;
    if (widget.isEditMode) {
      result = await ApiService.updateUser(widget.user!.id, payload);
    } else {
      payload['password'] = _passwordController.text.isNotEmpty ? _passwordController.text : 'password123'; // Default fallback
      result = await ApiService.createUser(payload);
    }

    setState(() {
      _isSaving = false;
    });

    if (result['success']) {
      widget.onSaveSuccess();
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
      title: Text(
        widget.isEditMode ? "✏️ កែប្រែព័ត៌មានអ្នកប្រើប្រាស់" : "👥 បង្កើតអ្នកប្រើប្រាស់ថ្មី",
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
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
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: widget.isEditMode ? "Password (ទុកទទេរបើមិនចង់ប្តូរ)" : "Password",
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF334155))),
                  ),
                  validator: (val) {
                    if (!widget.isEditMode && (val == null || val.isEmpty)) {
                      return "សូមបញ្ចូលពាក្យសម្ងាត់";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Role Dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Role:", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _role,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'user', child: Text("User")),
                            DropdownMenuItem(value: 'admin', child: Text("Admin")),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _role = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Group Selector Checkboxes
                const Text(
                  "ជ្រើសរើសប៉ុស្តិ៍វិទ្យុទាក់ទង (Groups)",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Column(
                  children: widget.availableGroups.map((g) {
                    final isChecked = _selectedGroupIds.contains(g.id);
                    return CheckboxListTile(
                      title: Text(
                        "📻 ${g.displayName}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      value: isChecked,
                      activeColor: const Color(0xFF38BDF8),
                      checkColor: Colors.white,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedGroupIds.add(g.id);
                          } else {
                            _selectedGroupIds.remove(g.id);
                          }
                        });
                      },
                    );
                  }).toList(),
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
          onPressed: _isSaving ? null : _submitForm,
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
    super.dispose();
  }
}
