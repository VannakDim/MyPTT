import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/ringtone_service.dart';
import '../services/webrtc_service.dart';
import '../services/image_service.dart';
import '../widgets/image_viewer.dart';
import '../models/user.model.dart';
import '../models/chat_message.model.dart';

class ConsoleTab extends StatefulWidget {
  final String userToken;
  final Group? selectedGroup;
  final List<Group> myGroups;
  final bool showLogs;
  final bool showPttButton;

  const ConsoleTab({
    super.key,
    required this.userToken,
    this.selectedGroup,
    required this.myGroups,
    required this.showLogs,
    this.showPttButton = true,
  });

  @override
  State<ConsoleTab> createState() => ConsoleTabState();
}

class ConsoleTabState extends State<ConsoleTab> {
  final _wsService = WebSocketService();
  final _audioService = AudioService();
  final _notificationService = NotificationService();
  final _ringtoneService = RingtoneService();
  WebRTCService? _webrtcService;
  final List<Color> _presetColors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal, Colors.amber, Colors.blueGrey
  ];

  List<User> _groupMembers = [];
  List<String> _onlineUserList = [];
  String _systemStatus = "Connecting...";

  // PTT State
  String _pttState = "idle"; // 'idle', 'talking', 'busy'

  // Draggable PTT Position
  late final ValueNotifier<Offset> _pttPositionNotifier = ValueNotifier<Offset>(const Offset(200, 350));
  bool _positionInitialized = false;

  // State variables for in-app PTT Listener
  bool _isDraggingPtt = false;
  bool _isPttActiveInApp = false;
  // Touch start & initial button position for drag-threshold detection
  double _pttTouchStartX = 0;
  double _pttTouchStartY = 0;
  Offset _pttInitialPosition = Offset.zero;
  static const double _pttDragThreshold = 10.0;

  // Logs and Chat State
  final List<String> _logs = [];
  final List<ChatMessage> _chatMessages = [];
  String? _playingVoiceUrl;
  final _chatController = TextEditingController();
  
  final _chatScrollController = ScrollController();
  final _logsScrollController = ScrollController();

  String _currentUsername = "";
  bool _isMuted = false;

  // Private Calling State
  String _callMode = "idle"; // 'idle', 'incoming', 'calling', 'connected'
  String _callStatusText = "";
  String _activeCallUser = "";

  String get pttState => _pttState;

  void disconnectWebSocket() {
    _wsService.disconnect();
    if (mounted) {
      setState(() {
        _systemStatus = "Disconnected";
      });
    }
  }

  void reconnectWebSocket() {
    if (widget.selectedGroup != null) {
      _connectWebSocket(widget.selectedGroup!.name);
    }
  }

  @override
  void initState() {
    super.initState();
    _chatScrollController.addListener(_onChatScroll);
    _initUsername().then((_) async {
      await _initAudio();
      if (widget.selectedGroup != null) {
        _connectWebSocket(widget.selectedGroup!.name);
        _fetchGroupMembers(widget.selectedGroup!.id);
        _fetchGroupMessages(widget.selectedGroup!.id);
      } else {
        setState(() {
          _systemStatus = "No Channels";
        });
        _addLog("ប្រព័ន្ធ៖ គណនីរបស់អ្នកមិនមានសិទ្ធិចូលក្នុង ប៉ុស្តិ៍ ណាមួយឡើយ");
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_positionInitialized) {
      final size = MediaQuery.of(context).size;
      if (size.width > 0 && size.height > 0) {
        _pttPositionNotifier.value = Offset(size.width - 120, size.height - 240);
        _positionInitialized = true;
      }
    }
  }

  @override
  void didUpdateWidget(covariant ConsoleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedGroup?.id != oldWidget.selectedGroup?.id) {
      setState(() {
        _chatMessages.clear();
        _logs.clear();
        _isLoadingMore = false;
        _hasMoreMessages = true;
      });
      if (widget.selectedGroup != null) {
        _connectWebSocket(widget.selectedGroup!.name);
        _fetchGroupMembers(widget.selectedGroup!.id);
        _fetchGroupMessages(widget.selectedGroup!.id);
      } else {
        _wsService.disconnect();
        setState(() {
          _systemStatus = "No Channels";
          _groupMembers = [];
        });
      }
    }
  }

  Future<void> _initUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUsername = prefs.getString('ptt_username') ?? 'admin';
      _webrtcService = WebRTCService(_wsService, _currentUsername);
    });
  }

  Future<void> _initAudio() async {
    try {
      await _audioService.initialize();
    } catch (e) {
      _addLog("កំហុសសំឡេង៖ មិនអាចផ្ដើមឧបករណ៍សំឡេងបានទេ ($e)");
    }
    // Initialize notification and ringtone services
    try {
      await _notificationService.initialize();
      await _ringtoneService.initialize();
    } catch (e) {
      debugPrint('[ConsoleTab] Notification/Ringtone init error: $e');
    }
  }

  Future<void> _fetchGroupMembers(int groupId) async {
    try {
      final members = await ApiService.getGroupMembers(groupId);
      if (mounted) {
        setState(() {
          _groupMembers = members;
        });
      }
    } catch (e) {
      debugPrint("Failed loading group members: $e");
    }
  }

  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;

  Future<void> _fetchGroupMessages(int groupId) async {
    try {
      final messages = await ApiService.getGroupMessages(groupId);
      if (mounted) {
        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(messages.reversed);
          _isLoadingMore = false;
          _hasMoreMessages = messages.length >= 15;
        });
      }
    } catch (e) {
      debugPrint("Failed loading group messages: $e");
    }
  }

  void _onChatScroll() {
    if (_chatScrollController.position.pixels >= _chatScrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || widget.selectedGroup == null || _chatMessages.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final oldestMsg = _chatMessages.last;
      if (oldestMsg.id == null) return;

      final moreMessages = await ApiService.getGroupMessages(widget.selectedGroup!.id, beforeId: oldestMsg.id);
      if (mounted) {
        setState(() {
          if (moreMessages.isEmpty) {
            _hasMoreMessages = false;
          } else {
            _chatMessages.addAll(moreMessages.reversed);
            _hasMoreMessages = moreMessages.length >= 15;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading more messages: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _connectWebSocket(String channelName) {
    setState(() {
      _systemStatus = "Connecting...";
    });
    _wsService.disconnect();

    _wsService.connect(
      channelName: channelName,
      token: widget.userToken,
      onDataReceived: _handleIncomingData,
      onDisconnected: () {
        if (mounted) {
          setState(() {
            _systemStatus = "Disconnected";
          });
        }
      },
      onConnected: () {
        if (mounted) {
          setState(() {
            _systemStatus = "Connected";
          });
        }
      },
    );
  }

  void _handleIncomingData(dynamic data) async {
    if (data is List<int>) {
      debugPrint("[IncomingData] Binary chunk received: ${data.length} bytes, type: ${data.runtimeType}");
      final chunk = data is Uint8List ? data : Uint8List.fromList(data);
      _audioService.playChunk(chunk);
      return;
    }

    if (data is String) {
      debugPrint("[IncomingData] JSON string received: $data");
      try {
        final Map<String, dynamic> frame = jsonDecode(data);
        final type = frame['type'];

        if (type == 'system') {
          _addLog(frame['message'] ?? '');
        } else if (type == 'chat' || type == 'file' || type == 'voice') {
          if (frame['created_at'] == null) {
            frame['created_at'] = DateTime.now().toUtc().toIso8601String();
          }
          final msg = ChatMessage.fromJson(frame, _currentUsername);
          setState(() {
            _chatMessages.insert(0, msg);
          });
          // Notify only for messages from others
          if (!msg.isMe) {
            _ringtoneService.playMessageBeep();
            final preview = msg.text ?? '';
            _notificationService.showChatNotification(
              sender: msg.sender,
              message: preview.length > 80 ? '${preview.substring(0, 80)}...' : preview,
            );
          }
        } else if (type == 'delete_message') {
          final dynamic rawId = frame['id'];
          final int? msgId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);
          if (msgId != null) {
            setState(() {
              _chatMessages.removeWhere((m) => m.id == msgId);
            });
          }
        } else if (type == 'ptt_status') {
          final status = frame['status'];
          setState(() {
            if (status == 'talking_granted') {
              _pttState = "talking";
              _startMicStreaming();
            } else if (status == 'line_busy') {
              _pttState = "busy";
            } else {
              _pttState = "idle";
              _audioService.stopRecording();
            }
          });
          _broadcastPttStatus(status == 'talking_granted' ? 'talking' : (status == 'line_busy' ? 'busy' : 'idle'));
        } else if (type == 'user_count') {
          final List list = frame['user_list'] ?? [];
          setState(() {
            _onlineUserList = list.map((e) => e.toString().toLowerCase()).toList();
          });
        } else if (type == 'webrtc_signal') {
          // Unused - PTT uses WebSocket PCM bytes
        } else if (type == 'call_signal') {
          _handleCallSignal(frame);
        }
      } catch (e) {
        debugPrint("WS JSON Decode error: $e");
      }
    }
  }

  void _broadcastPttStatus(String status) {
    final overlayPort = IsolateNameServer.lookupPortByName('overlay_port');
    if (overlayPort != null) {
      overlayPort.send({
        'type': 'ptt_status',
        'status': status,
      });
    }
  }

  void handleOverlayMessage(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'request_status') {
      _broadcastPttStatus(_pttState);
    } else if (type == 'action') {
      final action = data['action'];
      if (action == 'ptt_start') {
        _handlePttStart();
      } else if (action == 'ptt_stop') {
        _handlePttStop();
      }
    }
  }

  void _handleCallSignal(Map<String, dynamic> frame) {
    final status = frame['status'];
    final sender = frame['sender'];

    setState(() {
      if (status == 'call_user') {
        _callMode = "incoming";
        _callStatusText = "🔔 មានការហៅចូលពី...";
        _activeCallUser = sender;
        // Play ring tone + notification for incoming call
        _ringtoneService.startRinging();
        _notificationService.showCallNotification(callerName: sender);
      } else if (status == 'call_accepted') {
        _callMode = "connected";
        _callStatusText = "🟢 កំពុងនិយាយជាមួយ...";
        _addLog("ប្រព័ន្ធ៖ ការហៅទូរស័ព្ទជាមួយ $sender ត្រូវបានភ្ជាប់។");
        // Stop ringing when connected
        _ringtoneService.stopRinging();
        _notificationService.cancelCallNotification();
        _audioService.startPlaybackStream();
        _startMicStreaming();
      } else if (status == 'call_rejected') {
        _callMode = "idle";
        _audioService.stopRecording();
        _audioService.stopPlaybackStream();
        _ringtoneService.stopRinging();
        _notificationService.cancelCallNotification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $sender បានបដិសេធមិនទទួលទូរស័ព្ទទេ។")),
        );
      } else if (status == 'call_hungup') {
        _callMode = "idle";
        _audioService.stopRecording();
        _audioService.stopPlaybackStream();
        _ringtoneService.stopRinging();
        _notificationService.cancelCallNotification();
        _addLog("ប្រព័ន្ធ៖ $sender បានដាក់ទូរស័ព្ទចុះ។");
      }
    });
  }

  void _startMicStreaming() async {
    try {
      await _audioService.startRecording((bytes) {
        final bool canTransmit = (_pttState == 'talking') || (_callMode == 'connected');
        if (_wsService.isConnected && canTransmit) {
          _wsService.sendAudio(bytes);
        }
      });
    } catch (e) {
      _addLog("កំហុស Recording: $e");
    }
  }

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.add(msg);
    });
    _scrollToBottomLogs();
  }

  void _scrollToBottomChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomLogs() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logsScrollController.hasClients && widget.showLogs) {
        _logsScrollController.animateTo(
          _logsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handlePttStart() {
    if (_callMode == 'connected') return;
    _wsService.sendAction("ptt_start", {});
  }

  void _handlePttStop() {
    if (_callMode == 'connected') return;
    _wsService.sendAction("ptt_stop", {});
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _wsService.sendAction("chat_message", {'text': text});
    _chatController.clear();
  }

  Future<void> _sendFileShare() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path!;
    final file = File(filePath);
    Uint8List bytes = await file.readAsBytes();
    String name = result.files.first.name;
    String extension = (result.files.first.extension ?? 'bin').toLowerCase();
    String fileType = 'application/octet-stream';

    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
    if (isImage) {
      // Compress the image to JPEG
      final compressedBytes = await ImageService.compressImage(bytes, maxDimension: 1024, quality: 80);
      if (compressedBytes != null) {
        bytes = compressedBytes;
        fileType = 'image/jpeg';
        final dotIndex = name.lastIndexOf('.');
        if (dotIndex != -1) {
          name = '${name.substring(0, dotIndex)}.jpg';
        } else {
          name = '$name.jpg';
        }
      } else {
        fileType = 'image/$extension';
      }
    }

    final base64Val = 'data:$fileType;base64,${base64Encode(bytes)}';

    _wsService.sendAction("file_share", {
      'file_name': name,
      'file_type': fileType,
      'file_data': base64Val,
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _audioService.setMute(_isMuted);
    });
  }

  void makeCall(String targetUser) {
    setState(() {
      _callMode = "calling";
      _callStatusText = "📞 កំពុងហៅទៅ...";
      _activeCallUser = targetUser;
    });
    _wsService.sendAction("call_user", {'target': targetUser});
  }

  void _acceptCall() {
    _wsService.sendAction("call_accepted", {'target': _activeCallUser});
    setState(() {
      _callMode = "connected";
      _callStatusText = "🟢 កំពុងនិយាយជាមួយ...";
    });
    _audioService.startPlaybackStream();
    _startMicStreaming();
  }

  void _rejectCall() {
    _wsService.sendAction("call_rejected", {'target': _activeCallUser});
    setState(() {
      _callMode = "idle";
    });
  }

  void _hangupCall() {
    _wsService.sendAction("call_hungup", {'target': _activeCallUser});
    _audioService.stopRecording();
    _audioService.stopPlaybackStream();
    setState(() {
      _callMode = "idle";
    });
  }

  bool _isUserOnline(String name) {
    return _onlineUserList.contains(name.toLowerCase());
  }

  Color _getAvatarColor(String? avatarStr, String username) {
    if (avatarStr != null && avatarStr.isNotEmpty) {
      try {
        final parsed = jsonDecode(avatarStr);
        if (parsed['type'] == 'emoji' && parsed['bg'] != null) {
          return Color(int.parse(parsed['bg'].toString().replaceFirst('#', '0xFF')));
        }
      } catch (e) {}
    }
    final colors = _presetColors;
    int hash = 0;
    for (int i = 0; i < username.length; i++) {
      hash = username.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  void _showMembersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "សមាជិកក្នុងប៉ុស្តិ៍ (${_groupMembers.length})",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _groupMembers.length,
                      itemBuilder: (context, i) {
                        final member = _groupMembers[i];
                        final isOnline = _isUserOnline(member.name);
                        final isMe = member.name.toLowerCase() == _currentUsername.toLowerCase();

                        return Card(
                          color: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF334155)),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(isOnline ? "🟢" : "⚫", style: const TextStyle(fontSize: 10)),
                                const SizedBox(width: 8),
                                _buildMemberAvatar(member),
                              ],
                            ),
                            title: Text(
                              member.name + (isMe ? " (ខ្ញុំ)" : ""),
                              style: TextStyle(
                                color: isMe ? const Color(0xFF38BDF8) : Colors.white,
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            trailing: (!isMe && isOnline)
                                ? IconButton(
                                    icon: const Icon(Icons.call_rounded, color: Color(0xFF2ECC71)),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      makeCall(member.name);
                                    },
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  User? _findMemberByName(String name) {
    try {
      return _groupMembers.firstWhere(
        (u) => u.name.toLowerCase() == name.toLowerCase()
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildSenderAvatar(String senderName) {
    final user = _findMemberByName(senderName) ?? User(
      id: 0,
      name: senderName,
      email: '',
      role: 'user',
    );
    return _buildMemberAvatar(user);
  }

  String _formatMessageTime(DateTime? date) {
    if (date == null) return '';
    
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);
    
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minute";
    
    if (diff.inHours >= 24) {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final monthStr = months[localDate.month - 1];
      final day = localDate.day;
      return "$monthStr $day $timeStr";
    } else {
      return timeStr;
    }
  }

  bool _shouldShowTime(int index) {
    if (index == _chatMessages.length - 1) return true;
    final msg = _chatMessages[index];
    final olderMsg = _chatMessages[index + 1];
    
    final sameSender = msg.sender.toLowerCase() == olderMsg.sender.toLowerCase();
    final sameTime = _formatMessageTime(msg.createdAt) == _formatMessageTime(olderMsg.createdAt);
    
    return !(sameSender && sameTime);
  }

  Widget _buildMemberAvatar(User user) {
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      try {
        final parsed = jsonDecode(user.avatar!);
        if (parsed['type'] == 'image') {
          final cleanBase64 = (parsed['value'] as String).split(',').last;
          return CircleAvatar(
            radius: 11,
            backgroundImage: MemoryImage(base64Decode(cleanBase64)),
          );
        } else if (parsed['type'] == 'emoji') {
          return CircleAvatar(
            radius: 11,
            backgroundColor: _getAvatarColor(user.avatar, user.name),
            child: Text(parsed['value'] ?? '🦊', style: const TextStyle(fontSize: 10)),
          );
        }
      } catch (e) {}
    }
    return CircleAvatar(
      radius: 11,
      backgroundColor: _getAvatarColor(user.avatar, user.name),
      child: Text(user.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFileShareWidget(ChatMessage msg, int index) {
    final isImage = msg.fileType?.startsWith('image/') ?? false;

    if (isImage) {
      if (msg.fileData != null) {
        try {
          final base64Val = msg.fileData!.split(',').last;
          final bytes = base64Decode(base64Val);
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullScreenImageViewer(base64Data: msg.fileData),
                ),
              );
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes, height: 120, fit: BoxFit.cover),
              ),
            ),
          );
        } catch (e) {
          return const Text("⚠️ [កំហុសរូបភាព]", style: TextStyle(color: Colors.redAccent));
        }
      } else if (msg.filePath != null) {
        final url = msg.filePath!.startsWith('http') ? msg.filePath! : '${ApiService.baseUrl}${msg.filePath}';
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenImageViewer(imageUrl: url),
              ),
            );
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 120,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Text("⚠️ [កំហុសទាញយករូបភាព]", style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF38BDF8), size: 16),
              const SizedBox(width: 6),
              Text(
                msg.fileName ?? 'File',
                style: const TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.underline),
              ),
            ],
          ),
          if (_shouldShowTime(index)) ...[
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(msg.createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceMessageWidget(ChatMessage msg, int index) {
    final fileUrl = msg.filePath != null
        ? (msg.filePath!.startsWith('http') ? msg.filePath! : '${ApiService.baseUrl}${msg.filePath}')
        : null;

    final isPlaying = _playingVoiceUrl == fileUrl && fileUrl != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: msg.isMe ? const Color(0xFF0EA5E9).withOpacity(0.9) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isPlaying ? Icons.stop_circle_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (fileUrl != null) {
                    if (isPlaying) {
                      _audioService.stopUrlPlayer();
                      setState(() {
                        _playingVoiceUrl = null;
                      });
                    } else {
                      setState(() {
                        _playingVoiceUrl = fileUrl;
                      });
                      _audioService.playUrl(fileUrl, onFinished: () {
                        if (mounted) {
                          setState(() {
                            if (_playingVoiceUrl == fileUrl) {
                              _playingVoiceUrl = null;
                            }
                          });
                        }
                      });
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                "សារសំឡេង PTT",
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_shouldShowTime(index)) ...[
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(msg.createdAt),
              style: TextStyle(
                color: msg.isMe ? Colors.white70 : Colors.white54,
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _callStatusText,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  _activeCallUser,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_callMode == "incoming") ...[
                      ElevatedButton(
                        onPressed: _acceptCall,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
                        child: const Text("✔ ទទួល", style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: _rejectCall,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        child: const Text("❌ បដិសេធ", style: TextStyle(color: Colors.white)),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _hangupCall,
                        icon: const Icon(Icons.call_end_rounded, color: Colors.white),
                        label: const Text("🔴 ដាក់ចុះ", style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasChannel = widget.selectedGroup != null;

    Color pttBtnColor = const Color(0xFF0EA5E9);
    if (_pttState == "talking") {
      pttBtnColor = const Color(0xFF2ECC71);
    } else if (_pttState == "busy") {
      pttBtnColor = const Color(0xFFEF4444);
    } else if (_isPttActiveInApp) {
      pttBtnColor = const Color(0xFFF59E0B);
    }

    return Stack(
      children: [
        Container(
          color: const Color(0xFF0F172A),
          child: Column(
            children: [
              // Header Status Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF334155), width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _systemStatus == "Connected"
                                ? const Color(0xFF2ECC71)
                                : _systemStatus == "Connecting..."
                                    ? const Color(0xFFF1C40F)
                                    : const Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _systemStatus == "Connected"
                              ? "ភ្ជាប់រួច"
                              : _systemStatus == "Connecting..."
                                  ? "កំពុងភ្ជាប់..."
                                  : "មិនមានការតភ្ជាប់",
                          style: TextStyle(
                            color: _systemStatus == "Connected"
                                ? const Color(0xFF2ECC71)
                                : _systemStatus == "Connecting..."
                                    ? const Color(0xFFF1C40F)
                                    : const Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    
                    if (hasChannel)
                      InkWell(
                        onTap: _showMembersSheet,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, color: Color(0xFF38BDF8), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "🟢 ${_onlineUserList.length}/${_groupMembers.length}",
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: _isMuted ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _toggleMute,
                    ),
                  ],
                ),
              ),

              // Main Chat Area
                  Expanded(
                child: hasChannel
                    ? ListView.builder(
                        controller: _chatScrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, i) {
                          final msg = _chatMessages[i];
                          final showHeader = !msg.isMe && _shouldShowTime(i);
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (showHeader) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildSenderAvatar(msg.sender),
                                      const SizedBox(width: 6),
                                      Text(
                                        msg.sender,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                SwipeToReveal(
                                  isMe: msg.isMe && msg.id != null,
                                  onDelete: () {
                                    _showDeleteDialog(msg);
                                  },
                                  child: msg.type == 'chat'
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: msg.isMe ? const Color(0xFF0EA5E9) : const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(12),
                                              topRight: const Radius.circular(12),
                                              bottomLeft: msg.isMe ? const Radius.circular(12) : const Radius.circular(0),
                                              bottomRight: msg.isMe ? const Radius.circular(0) : const Radius.circular(12),
                                            ),
                                            border: Border.all(color: const Color(0xFF334155)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                msg.text ?? '',
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                              ),
                                              if (_shouldShowTime(i)) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatMessageTime(msg.createdAt),
                                                  style: TextStyle(
                                                    color: msg.isMe ? Colors.white70 : Colors.white54,
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        )
                                      : msg.type == 'file'
                                          ? _buildFileShareWidget(msg, i)
                                          : _buildVoiceMessageWidget(msg, i),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          "សូមជ្រើសរើសប៉ុស្តិ៍វិទ្យុដើម្បីចាប់ផ្ដើមការជជែក",
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                        ),
                      ),
              ),

              if (widget.showLogs) ...[
                Container(
                  height: 100,
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: ListView.builder(
                    controller: _logsScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[i],
                          style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 10, fontFamily: 'monospace'),
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (hasChannel)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file_rounded, color: Color(0xFF38BDF8)),
                        onPressed: _sendFileShare,
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: "វាយសារ...",
                              hintStyle: TextStyle(color: Color(0xFF64748B)),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendChatMessage(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: const Color(0xFF0EA5E9),
                        radius: 22,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: _sendChatMessage,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Draggable Floating PTT Button Card
        if (hasChannel && widget.showPttButton)
          ValueListenableBuilder<Offset>(
            valueListenable: _pttPositionNotifier,
            builder: (context, position, child) {
              return Positioned(
                left: position.dx,
                top: position.dy,
                child: child!,
              );
            },
            child: Listener(
              onPointerDown: (event) {
                // Record start position
                _pttTouchStartX = event.position.dx;
                _pttTouchStartY = event.position.dy;
                _pttInitialPosition = _pttPositionNotifier.value;
                _isDraggingPtt = false;
                if (mounted) setState(() { _isPttActiveInApp = true; });
                _handlePttStart();
              },
              onPointerMove: (event) {
                final double dx = event.position.dx - _pttTouchStartX;
                final double dy = event.position.dy - _pttTouchStartY;
                // Once movement exceeds threshold, switch to drag and stop PTT
                if (!_isDraggingPtt &&
                    (dx * dx + dy * dy) > (_pttDragThreshold * _pttDragThreshold)) {
                  if (_isPttActiveInApp) {
                    _handlePttStop();
                    if (mounted) setState(() { _isPttActiveInApp = false; });
                  }
                  _isDraggingPtt = true;
                }
                if (_isDraggingPtt) {
                  final size = MediaQuery.of(context).size;
                  final double newX = (_pttInitialPosition.dx + dx).clamp(0.0, size.width - 90);
                  final double newY = (_pttInitialPosition.dy + dy).clamp(50.0, size.height - 150);
                  _pttPositionNotifier.value = Offset(newX, newY);
                }
              },
              onPointerUp: (event) {
                if (_isPttActiveInApp) {
                  _handlePttStop();
                }
                _isDraggingPtt = false;
                if (mounted) setState(() { _isPttActiveInApp = false; });
              },
              onPointerCancel: (event) {
                if (_isPttActiveInApp) {
                  _handlePttStop();
                }
                _isDraggingPtt = false;
                if (mounted) setState(() { _isPttActiveInApp = false; });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                transformAlignment: Alignment.center,
                transform: Matrix4.diagonal3Values(
                  _isPttActiveInApp ? 0.92 : 1.0,
                  _isPttActiveInApp ? 0.92 : 1.0,
                  1.0,
                ),
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pttBtnColor,
                  boxShadow: [
                    BoxShadow(
                      color: pttBtnColor.withOpacity(0.5),
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
                      _pttState == "talking"
                          ? "\ud83d\udde3\ufe0f"
                          : _pttState == "busy"
                              ? "\ud83d\uded1"
                              : (_isPttActiveInApp ? "\ud83d\udde3\ufe0f" : "PTT"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (_pttState == "idle" && !_isPttActiveInApp)
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
              ),
            ),
          ),

        if (_callMode != "idle") _buildCallOverlay(),
      ],
    );
  }

  void _showDeleteDialog(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("លុបសារ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("តើអ្នកពិតជាចង់លុបសារនេះមែនទេ?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("បោះបង់", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteMessage(msg);
            },
            child: const Text("លុប", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    if (msg.id == null) return;
    try {
      final success = await ApiService.deleteMessage(msg.id!);
      if (success) {
        setState(() {
          _chatMessages.removeWhere((m) => m.id == msg.id);
        });
        if (_wsService.isConnected) {
          _wsService.sendAction("delete_message", {"id": msg.id});
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("លុបសារមិនបានជោគជ័យ")),
        );
      }
    } catch (e) {
      debugPrint("Error deleting message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("មានបញ្ហាក្នុងការលុបសារ")),
      );
    }
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _webrtcService?.dispose();
    _audioService.dispose();
    _ringtoneService.dispose();
    _chatController.dispose();
    _chatScrollController.removeListener(_onChatScroll);
    _chatScrollController.dispose();
    _logsScrollController.dispose();
    _pttPositionNotifier.dispose();
    super.dispose();
  }
}

class SwipeToReveal extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final bool isMe;

  const SwipeToReveal({
    Key? key,
    required this.child,
    required this.onDelete,
    required this.isMe,
  }) : super(key: key);

  @override
  State<SwipeToReveal> createState() => _SwipeToRevealState();
}

class _SwipeToRevealState extends State<SwipeToReveal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  final double _maxRevealWidth = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _controller.addListener(() {
      if (_controller.isAnimating) {
        setState(() {
          _dragOffset = _controller.value * -_maxRevealWidth;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.isMe) return;
    _controller.stop();
    setState(() {
      _dragOffset += details.primaryDelta!;
      if (_dragOffset > 0.0) _dragOffset = 0.0;
      if (_dragOffset < -_maxRevealWidth * 1.5) {
        _dragOffset = -_maxRevealWidth * 1.5;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.isMe) return;
    double currentRatio = _dragOffset / -_maxRevealWidth;
    if (currentRatio < 0.0) currentRatio = 0.0;
    if (currentRatio > 1.0) currentRatio = 1.0;
    _controller.value = currentRatio;

    if (_dragOffset < -_maxRevealWidth / 2) {
      _controller.animateTo(1.0, curve: Curves.easeOut);
    } else {
      _controller.animateTo(0.0, curve: Curves.easeOut);
    }
  }

  void close() {
    _controller.animateTo(0.0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMe) return widget.child;

    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          right: 10,
          child: Center(
            child: GestureDetector(
              onTap: () {
                close();
                widget.onDelete();
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: Transform.translate(
            offset: Offset(_dragOffset, 0.0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
