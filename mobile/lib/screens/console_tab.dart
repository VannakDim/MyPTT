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
import '../services/chat_cache_service.dart';
import 'login_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:math';

class ConsoleTab extends StatefulWidget {
  final String userToken;
  final Group? selectedGroup;
  final List<Group> myGroups;
  final bool showLogs;
  final bool showPttButton;
  final String pttMode;
  final double fontSize;
  final VoidCallback? onRefreshGroups;
  final Function(User)? onRefreshUser;

  const ConsoleTab({
    super.key,
    required this.userToken,
    this.selectedGroup,
    required this.myGroups,
    required this.showLogs,
    required this.showPttButton,
    required this.pttMode,
    this.fontSize = 13.0,
    this.onRefreshGroups,
    this.onRefreshUser,
  });

  @override
  State<ConsoleTab> createState() => ConsoleTabState();
}

class ConsoleTabState extends State<ConsoleTab> with WidgetsBindingObserver {
  final _wsService = WebSocketService();
  final _audioService = AudioService();
  final _notificationService = NotificationService();
  final _ringtoneService = RingtoneService();
  final _cacheService = ChatCacheService();
  WebRTCService? _webrtcService;
  final List<Color> _presetColors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal, Colors.amber, Colors.blueGrey
  ];

  List<User> _groupMembers = [];
  List<String> _onlineUserList = [];
  String _systemStatus = "Connecting...";

  // PTT State
  String _pttState = "idle"; // 'idle', 'talking', 'busy'
  String _activePttSpeaker = "";

  // Draggable PTT Position
  late final ValueNotifier<Offset> _pttPositionNotifier = ValueNotifier<Offset>(const Offset(100, 350));
  bool _positionInitialized = false;

  // State variables for in-app PTT Listener
  bool _isDraggingPtt = false;
  final ValueNotifier<bool> _isPttActiveInAppNotifier = ValueNotifier<bool>(false);
  Timer? _pttDelayTimer;
  // Touch start & initial button position for drag-threshold detection
  double _pttTouchStartX = 0;
  double _pttTouchStartY = 0;
  Offset _pttInitialPosition = Offset.zero;
  static const double _pttDragThreshold = 10.0;

  // File Uploading Progress
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatus = "";

  // Logs and Chat State
  final List<String> _logs = [];
  final List<ChatMessage> _chatMessages = [];
  final Map<String, String> _localFilePaths = {};
  String? _playingVoiceUrl;
  final _chatController = TextEditingController();

  // Reply & Select State
  ChatMessage? _replyingTo;
  bool _isSelectMode = false;
  final Set<int> _selectedMessageIds = {};
  final Set<int> _selectedIndexes = {}; // index-based for real-time msgs without id
  
  bool _showScrollToBottom = false;
  bool _hasNewIncomingMessage = false;
  
  final _chatScrollController = ScrollController();
  final _logsScrollController = ScrollController();

  String _currentUsername = "";
  bool _isMuted = false;

  // Private Calling State
  String _callMode = "idle"; // 'idle', 'incoming', 'calling', 'connected'
  String _callStatusText = "";
  String _activeCallUser = "";

  // Audio Output State (during call)
  String _callAudioOutput = 'earpiece'; // 'earpiece' | 'speaker' | 'bluetooth'
  List<Map<String, String>> _availableOutputs = [];
  int _callDurationSeconds = 0;
  Timer? _callTimer;

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
    WidgetsBinding.instance.addObserver(this);
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
    if (oldWidget.pttMode != widget.pttMode) {
      if (_isPttActiveInAppNotifier.value) {
        _handlePttStop();
        _isPttActiveInAppNotifier.value = false;
      }
    }
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
    // ១. ព្យាយាមទាញយកសារចេញពី Local Cache មុនដើម្បីបង្ហាញជូនអ្នកប្រើប្រាស់ភ្លាមៗ
    final cached = await _cacheService.getCachedMessages(groupId, _currentUsername);
    if (cached.isNotEmpty && mounted) {
      setState(() {
        _chatMessages.clear();
        _chatMessages.addAll(cached);
        _hasMoreMessages = cached.length >= 15;
      });
      _scrollToLastReadMessage(groupId);
      _markMessagesAsSeen(_chatMessages);
      _checkDownloadedFiles();
    }

    try {
      final messages = await ApiService.getGroupMessages(groupId);
      if (mounted) {
        setState(() {
          _chatMessages.clear();
          _chatMessages.addAll(messages.reversed);
          _isLoadingMore = false;
          _hasMoreMessages = messages.length >= 15;
        });
        _scrollToLastReadMessage(groupId);
        _markMessagesAsSeen(_chatMessages);
      }
      // ២. រក្សាទុកសារដែលទើបតែទាញយកបានថ្មីៗ ចូលទៅក្នុង cache
      _cacheService.cacheMessages(groupId, messages);
      _checkDownloadedFiles();
    } catch (e) {
      debugPrint("Failed loading group messages: $e");
    }
  }

  void _onChatScroll() {
    if (_chatScrollController.position.pixels >= _chatScrollController.position.maxScrollExtent - 400) {
      _loadMoreMessages();
    }

    if (_chatScrollController.position.pixels <= 50) {
      if (_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = false;
          _hasNewIncomingMessage = false;
        });
      }
      _saveLastReadMessage();
    } else if (_chatScrollController.position.pixels > 200) {
      if (!_showScrollToBottom && _hasNewIncomingMessage) {
        setState(() {
          _showScrollToBottom = true;
        });
      }
    }
  }

  Future<void> _saveLastReadMessage() async {
    if (widget.selectedGroup != null && _chatMessages.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final newestId = _chatMessages.first.id;
      if (newestId != null) {
        await prefs.setInt('last_read_msg_id_${widget.selectedGroup!.id}', newestId);
      }
    }
  }

  Future<void> _scrollToLastReadMessage(int groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final lastReadId = prefs.getInt('last_read_msg_id_$groupId');
    if (lastReadId != null && _chatMessages.isNotEmpty) {
      final index = _chatMessages.indexWhere((m) => m.id == lastReadId);
      if (index > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController.jumpTo(index * 75.0);
            setState(() {
              _showScrollToBottom = true;
            });
          }
        });
      }
    } else if (_chatMessages.isNotEmpty) {
      final newestId = _chatMessages.first.id;
      if (newestId != null) {
        await prefs.setInt('last_read_msg_id_$groupId', newestId);
      }
    }
  }

  void _markMessagesAsSeen(List<ChatMessage> messages) {
    if (!_wsService.isConnected || _currentUsername.isEmpty) return;
    final List<int> unreadIds = [];
    for (final msg in messages) {
      if (msg.id != null && !msg.isMe) {
        final alreadySeen = msg.seenBy.any((name) => name.toLowerCase() == _currentUsername.toLowerCase());
        if (!alreadySeen) {
          unreadIds.add(msg.id!);
        }
      }
    }
    if (unreadIds.isNotEmpty) {
      debugPrint("[Seen] Sending seen receipt for IDs: $unreadIds");
      _wsService.sendAction('message_seen', {'ids': unreadIds});
    }
  }

  void _showSeenByBottomSheet(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "អ្នកបានអាន (Seen by)",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${msg.seenBy.length} នាក់",
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 12),
                if (msg.seenBy.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        "មិនទាន់មានអ្នកអាននៅឡើយទេ",
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.3,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: msg.seenBy.length,
                      itemBuilder: (context, index) {
                        final username = msg.seenBy[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xFF1E293B),
                            child: Icon(Icons.person, color: Color(0xFF38BDF8), size: 14),
                          ),
                          title: Text(
                            username,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showScrollToBottom = false;
        _hasNewIncomingMessage = false;
      });
      _saveLastReadMessage();
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
      if (moreMessages.isNotEmpty) {
        _cacheService.cacheMessages(widget.selectedGroup!.id, moreMessages);
        _checkDownloadedFiles();
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
      // ពេលកំពុងហៅ private — binary ដែលទៅដល់ user នោះ server ធានាថាមកពី call partner ប៉ុណ្ណោះ
      // ដូច្នេះចាក់ play បានដោយសុវត្ថិភាព (group PTT audio មិនត្រូវបាន broadcast មកដល់យើងទេ)
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
        } else if (type == 'force_logout') {
          final message = frame['message'] ?? 'គណនីរបស់អ្នកត្រូវបានចូលប្រើប្រាស់នៅលើឧបករណ៍ផ្សេងទៀត។';
          _showForceLogoutDialog(message);
        } else if (type == 'chat' || type == 'file' || type == 'voice') {
          if (frame['created_at'] == null) {
            frame['created_at'] = DateTime.now().toUtc().toIso8601String();
          }
          final msg = ChatMessage.fromJson(frame, _currentUsername);
          setState(() {
            _chatMessages.insert(0, msg);
          });
          if (widget.selectedGroup != null) {
            _cacheService.cacheMessages(widget.selectedGroup!.id, [msg]);
          }
          // ជូនដំណឹងសំឡេងលុះត្រាតែមកពីអ្នកដទៃ និងមិនមែនកំពុងនិយាយទូរស័ព្ទ (calling)
          if (!msg.isMe) {
            if (_callMode == 'idle') {
              _ringtoneService.playMessageBeep();
            }
            final preview = msg.text ?? '';
            _notificationService.showChatNotification(
              sender: msg.sender,
              message: preview.length > 80 ? '${preview.substring(0, 80)}...' : preview,
            );
          }

          // ប្រសិនបើកំពុងអានសារប្រវត្តិខាងលើ (scrolled up) គឺត្រូវបង្ហាញប៊ូតុង និងផ្ដល់ដំណឹងសារថ្មី
          if (_chatScrollController.hasClients) {
            if (_chatScrollController.position.pixels > 100) {
              setState(() {
                _hasNewIncomingMessage = true;
                _showScrollToBottom = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("💬 សារថ្មីពី ${msg.sender}: ${msg.text ?? 'សារសំឡេង/ឯកសារ'}"),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: "មើល",
                    textColor: const Color(0xFF38BDF8),
                    onPressed: _scrollToBottom,
                  ),
                ),
              );
            } else {
              _saveLastReadMessage();
            }
            _markMessagesAsSeen([msg]);
          }
        } else if (type == 'delete_message') {
          final dynamic rawId = frame['id'];
          final int? msgId = rawId is int ? rawId : (rawId != null ? int.tryParse(rawId.toString()) : null);
          if (msgId != null) {
            setState(() {
              _chatMessages.removeWhere((m) => m.id == msgId);
            });
            if (widget.selectedGroup != null) {
              _cacheService.cacheMessages(widget.selectedGroup!.id, _chatMessages);
            }
          }
        } else if (type == 'message_seen') {
          final List<dynamic> rawIds = frame['message_ids'] ?? [];
          final String seenUser = frame['username'] ?? '';
          if (rawIds.isNotEmpty && seenUser.isNotEmpty) {
            final List<int> messageIds = rawIds.map((id) => id is int ? id : int.parse(id.toString())).toList();
            setState(() {
              for (int i = 0; i < _chatMessages.length; i++) {
                final msg = _chatMessages[i];
                if (msg.id != null && messageIds.contains(msg.id)) {
                  if (!msg.seenBy.contains(seenUser)) {
                    final updatedSeen = List<String>.from(msg.seenBy)..add(seenUser);
                    _chatMessages[i] = ChatMessage(
                      id: msg.id,
                      sender: msg.sender,
                      type: msg.type,
                      text: msg.text,
                      fileName: msg.fileName,
                      fileType: msg.fileType,
                      fileData: msg.fileData,
                      filePath: msg.filePath,
                      isMe: msg.isMe,
                      createdAt: msg.createdAt,
                      seenBy: updatedSeen,
                      replyToId: msg.replyToId,
                      replyToSender: msg.replyToSender,
                      replyToText: msg.replyToText,
                      replyToType: msg.replyToType,
                      replyToFileName: msg.replyToFileName,
                    );
                  }
                }
              }
            });
          }
        } else if (type == 'ptt_status') {
          if (_callMode != 'idle') return; // Skip PTT updates during calls!
          final status = frame['status'];
          setState(() {
            if (status == 'talking_granted') {
              _pttState = "talking";
              _activePttSpeaker = "";
              _startMicStreaming();
            } else if (status == 'line_busy') {
              _pttState = "busy";
              _activePttSpeaker = "";
            } else if (status == 'busy') {
              final speaker = frame['speaker'] ?? "User";
              if (speaker != _currentUsername) {
                _pttState = "busy";
                _activePttSpeaker = speaker;
              }
            } else {
              _pttState = "idle";
              _activePttSpeaker = "";
              _audioService.stopRecording();
            }
          });
          _broadcastPttStatus(_pttState);
        } else if (type == 'user_count') {
          final List list = frame['user_list'] ?? [];
          setState(() {
            _onlineUserList = list.map((e) => e.toString().toLowerCase()).toList();
          });
        } else if (type == 'webrtc_signal') {
          // Unused - PTT uses WebSocket PCM bytes
        } else if (type == 'call_signal') {
          _handleCallSignal(frame);
        } else if (type == 'user_update') {
          final dynamic rawUserId = frame['user_id'];
          final String action = frame['action'] ?? '';
          final prefs = await SharedPreferences.getInstance();
          final currentUserId = prefs.getInt('ptt_user_id');

          if (currentUserId != null && currentUserId.toString() == rawUserId.toString()) {
            if (action == 'deleted') {
              _showForceLogoutDialog("គណនីរបស់អ្នកត្រូវបានលុបដោយអ្នកគ្រប់គ្រង (Admin)។");
            } else if (action == 'updated') {
              final updatedUser = await ApiService.getCurrentUser();
              if (updatedUser != null) {
                await prefs.setString('ptt_username', updatedUser.name);
                await prefs.setString('ptt_email', updatedUser.email);
                await prefs.setString('ptt_avatar', updatedUser.avatar ?? '');
                await prefs.setString('ptt_role', updatedUser.role);

                if (widget.onRefreshUser != null) {
                  widget.onRefreshUser!(updatedUser);
                }

                setState(() {
                  _currentUsername = updatedUser.name;
                });
                _addLog("🔔 ព័ត៌មានគណនីរបស់អ្នកត្រូវបានកែប្រែដោយអ្នកគ្រប់គ្រង។");
              }
            }
          }

          if (widget.onRefreshGroups != null) {
            widget.onRefreshGroups!();
          }
        } else if (type == 'groups_update') {
          if (widget.onRefreshGroups != null) {
            widget.onRefreshGroups!();
          }
          final dynamic rawGroupId = frame['group_id'];
          final String action = frame['action'] ?? '';
          if (widget.selectedGroup != null && widget.selectedGroup!.id.toString() == rawGroupId.toString() && action == 'deleted') {
            _addLog("⚠️ ប៉ុស្តិ៍វិទ្យុដែលអ្នកកំពុងស្ថិតនៅត្រូវបានលុបដោយអ្នកគ្រប់គ្រង។");
          }
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
        _ringtoneService.startRinging();
        _notificationService.showCallNotification(callerName: sender);
      } else if (status == 'call_accepted') {
        _callMode = "connected";
        _callStatusText = "🟢 កំពុងនិយាយជាមួយ...";
        _callAudioOutput = 'earpiece';
        _addLog("ប្រព័ន្ធ៖ ការហៅទូរស័ព្ទជាមួយ $sender ត្រូវបានភ្ជាប់។");
        _ringtoneService.stopRinging();
        _notificationService.cancelCallNotification();
        _audioService.startPlaybackStream();
        _startMicStreaming();
        _audioService.setAudioOutput('earpiece');
        _startCallTimer();
        _loadAudioOutputs();
      } else if (status == 'call_rejected') {
        _callMode = "idle";
        _audioService.stopRecording();
        _audioService.stopPlaybackStream();
        _audioService.setAudioOutput('earpiece');
        _ringtoneService.stopRinging();
        _notificationService.cancelCallNotification();
        _stopCallTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ $sender បានបដិសេធមិនទទួលទូរស័ព្ទទេ។")),
        );
      } else if (status == 'call_hungup') {
        _callMode = "idle";
        _audioService.stopRecording();
        _audioService.stopPlaybackStream();
        _audioService.setAudioOutput('earpiece');
        _ringtoneService.stopRinging();
        _notificationService.cancelCallNotification();
        _stopCallTimer();
        _addLog("ប្រព័ន្ធ៖ $sender បានដាក់ទូរស័ព្ទចុះ។");
      }
    });
  }

  void _startMicStreaming() async {
    try {
      await _audioService.startRecording((bytes) {
        if (!_wsService.isConnected) return;
        if (_callMode == 'connected') {
          // ការហៅ Private: ផ្ញើសំឡេងចំគោលដៅប៉ុណ្ណោះ — មិន broadcast ទៅ group
          _wsService.sendPrivateAudio(bytes, _activeCallUser);
        } else if (_pttState == 'talking') {
          // PTT ធម្មតា: broadcast ទៅ group
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
          0.0,
          duration: const Duration(milliseconds: 100),
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
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handlePttStart() {
    if (_callMode != 'idle') return;
    _wsService.sendAction("ptt_start", {});
  }

  void _handlePttStop() {
    if (_callMode != 'idle') return;
    _wsService.sendAction("ptt_stop", {});
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final payload = <String, dynamic>{'text': text};
    _wsService.sendAction("chat_message", payload);
    _chatController.clear();
  }

  Future<void> _showSendFileOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "ផ្ញើឯកសារ ឬរូបភាព",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8)),
                  title: const Text("ប្រើប្រាស់កាមេរ៉ា (Camera)", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCamera();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF2ECC71)),
                  title: const Text("ជ្រើសរើសរូបភាព (Gallery)", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFFF1C40F)),
                  title: const Text("ជ្រើសរើសឯកសារ (Files)", style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromFile();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image == null) return;

      final name = image.name;
      final extension = image.path.split('.').last.toLowerCase();
      _processAndSendFile(image.path, name, extension);
    } catch (e) {
      debugPrint("Error picking from camera: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final name = image.name;
      final extension = image.path.split('.').last.toLowerCase();
      _processAndSendFile(image.path, name, extension);
    } catch (e) {
      debugPrint("Error picking from gallery: $e");
    }
  }

  Future<void> _pickFromFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path!;
    String name = result.files.first.name;
    String extension = (result.files.first.extension ?? 'bin').toLowerCase();
    _processAndSendFile(filePath, name, extension);
  }

  Future<void> _processAndSendFile(String filePath, String name, String extension) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatus = "កំពុងរៀបចំឯកសារ...";
    });

    File? tempCompressedFile;

    try {
      String fileType = 'application/octet-stream';
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
      
      String targetPath = filePath;
      if (isImage) {
        setState(() {
          _uploadStatus = "កំពុងច្របាច់ទំហំរូបភាព...";
        });
        final bytes = await File(filePath).readAsBytes();
        final compressedBytes = await ImageService.compressImage(bytes, maxDimension: 1024, quality: 80);
        if (compressedBytes != null) {
          fileType = 'image/jpeg';
          final dotIndex = name.lastIndexOf('.');
          if (dotIndex != -1) {
            name = '${name.substring(0, dotIndex)}.jpg';
          } else {
            name = '$name.jpg';
          }
          // Save compressed bytes to temp directory
          final tempDir = await getTemporaryDirectory();
          tempCompressedFile = File('${tempDir.path}/temp_upload_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tempCompressedFile.writeAsBytes(compressedBytes);
          targetPath = tempCompressedFile.path;
        } else {
          fileType = 'image/$extension';
        }
      }

      final file = File(targetPath);
      final totalBytes = await file.length();
      final totalSizeMB = (totalBytes / (1024 * 1024)).toStringAsFixed(2);

      // We use 2MB chunk size
      const int chunkSize = 2 * 1024 * 1024; // 2MB
      final int totalChunks = (totalBytes / chunkSize).ceil();
      final uploadId = "${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(100000)}";

      setState(() {
        _uploadStatus = "កំពុងផ្ញើ (ទំហំសរុប $totalSizeMB MB, ចំនួន ${totalChunks} កញ្ចប់)...";
      });

      for (int i = 0; i < totalChunks; i++) {
        if (!mounted || !_isUploading) {
          throw Exception("ការផ្ញើត្រូវបានបោះបង់ចោល");
        }

        final start = i * chunkSize;
        final end = (start + chunkSize > totalBytes) ? totalBytes : (start + chunkSize);

        final chunkStream = file.openRead(start, end);
        final Uint8List chunkBytes = Uint8List.fromList(await chunkStream.expand((chunk) => chunk).toList());

        final sentBytes = (i + 1) * chunkSize > totalBytes ? totalBytes : (i + 1) * chunkSize;
        final sentMB = (sentBytes / (1024 * 1024)).toStringAsFixed(2);
        final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(2);

        setState(() {
          _uploadProgress = (i) / totalChunks;
          _uploadStatus = "កំពុងផ្ញើកញ្ចប់ទី ${i + 1}/${totalChunks} ($sentMB MB / $totalMB MB)...";
        });

        final success = await _uploadSingleChunk(
          uploadId: uploadId,
          chunkIndex: i,
          totalChunks: totalChunks,
          fileName: name,
          fileType: fileType,
          chunkBytes: chunkBytes,
        );

        if (!success) {
          throw Exception("ការផ្ញើកញ្ចប់ទី ${i + 1} បានបរាជ័យ");
        }
      }

      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
          _uploadStatus = "បានផ្ញើជោគជ័យ!";
        });
      }

    } catch (e) {
      debugPrint("Error uploading file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ ការផ្ញើឯកសារបានបរាជ័យ៖ $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      // Clean up temp compressed file if created
      if (tempCompressedFile != null && await tempCompressedFile.exists()) {
        try {
          await tempCompressedFile.delete();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<bool> _uploadSingleChunk({
    required String uploadId,
    required int chunkIndex,
    required int totalChunks,
    required String fileName,
    required String fileType,
    required Uint8List chunkBytes,
  }) async {
    try {
      final token = await ApiService.getToken();
      final url = Uri.parse('${ApiService.baseUrl}/api/upload-chunk');
      
      final request = http.MultipartRequest('POST', url);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';
      
      request.fields['upload_id'] = uploadId;
      request.fields['chunk_index'] = chunkIndex.toString();
      request.fields['total_chunks'] = totalChunks.toString();
      request.fields['file_name'] = fileName;
      request.fields['file_type'] = fileType;
      request.fields['channel_name'] = widget.selectedGroup?.name ?? "";
      
      request.files.add(http.MultipartFile.fromBytes(
        'chunk',
        chunkBytes,
        filename: 'chunk_$chunkIndex',
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resData = jsonDecode(response.body);
        
        if (resData['status'] == 'completed') {
          final messageData = resData['message'];
          
          // Notify other clients instantly via websocket
          _wsService.sendAction("file_share_completed", {
            'id': messageData['id'],
            'file_name': messageData['file_name'] ?? fileName,
            'file_type': messageData['file_type'] ?? fileType,
            'file_path': messageData['file_path'],
            'created_at': messageData['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
          });
        }
        return true;
      }
    } catch (e) {
      debugPrint("Error sending chunk: $e");
    }
    return false;
  }

  Future<void> _downloadFile(BuildContext context, String url, String fileName, {String? msgId}) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("កំពុងទាញយកឯកសារ $fileName..."), duration: const Duration(seconds: 2)),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Server status: ${response.statusCode}");
      }

      Directory? dir;
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          dir = await getExternalStorageDirectory();
        } else {
          dir = Directory('/storage/emulated/0/Download');
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception("មិនអាចរកឃើញទីតាំងរក្សាទុកឯកសារ");
      }

      final savePath = '${dir.path}/$fileName';
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);

      if (msgId != null && mounted) {
        setState(() {
          _localFilePaths[msgId] = savePath;
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("📥 ទាញយកជោគជ័យ! រក្សាទុកនៅ៖ $savePath"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error downloading file: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⚠️ ទាញយកបរាជ័យ៖ $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<String?> _getLocalFilePath(String fileName) async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        final fileInDownload = File('${downloadDir.path}/$fileName');
        if (await fileInDownload.exists()) {
          return fileInDownload.path;
        }
        dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir != null) {
        final fileInAppDir = File('${dir.path}/$fileName');
        if (await fileInAppDir.exists()) {
          return fileInAppDir.path;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _checkDownloadedFiles() async {
    final Map<String, String> foundPaths = {};
    for (final msg in _chatMessages) {
      if (msg.type == 'file' && msg.fileName != null) {
        final path = await _getLocalFilePath(msg.fileName!);
        if (path != null) {
          foundPaths[msg.id.toString()] = path;
        }
      }
    }
    if (mounted && foundPaths.isNotEmpty) {
      setState(() {
        _localFilePaths.addAll(foundPaths);
      });
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _audioService.setMute(_isMuted);
    });
  }



  void _showForceLogoutDialog(String message) {
    if (!mounted) return;
    
    // Stop all audio immediately
    _audioService.stopPlaybackStream();
    _wsService.disconnect();

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap OK to exit
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF334155)),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                SizedBox(width: 8),
                Text(
                  "ការជូនដំណឹងពីគណនី",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (context.mounted) {
                    // Navigate back to login and discard stack
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) => false,
                    );
                  }
                },
                child: const Text(
                  "យល់ព្រម",
                  style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      _callAudioOutput = 'earpiece';
    });
    _audioService.startPlaybackStream();
    _startMicStreaming();
    _audioService.setAudioOutput('earpiece');
    _startCallTimer();
    _loadAudioOutputs();
  }

  void _rejectCall() {
    _wsService.sendAction("call_rejected", {'target': _activeCallUser});
    _ringtoneService.stopRinging();
    setState(() {
      _callMode = "idle";
    });
    _stopCallTimer();
  }

  void _hangupCall() {
    _wsService.sendAction("call_hungup", {'target': _activeCallUser});
    _audioService.stopRecording();
    _audioService.stopPlaybackStream();
    _audioService.setAudioOutput('earpiece');
    _stopCallTimer();
    setState(() {
      _callMode = "idle";
    });
  }

  void _startCallTimer() {
    _callDurationSeconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDurationSeconds = 0;
  }

  String get _callDurationText {
    final m = (_callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _loadAudioOutputs() async {
    final outputs = await _audioService.listAudioOutputs();
    if (mounted) setState(() => _availableOutputs = outputs);
  }

  void _toggleSpeaker() {
    final next = _callAudioOutput == 'speaker' ? 'earpiece' : 'speaker';
    setState(() => _callAudioOutput = next);
    _audioService.setAudioOutput(next);
  }

  void _showAudioOutputPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ជ្រើស Audio Output', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._availableOutputs.map((o) {
              final id   = o['id'] ?? '';
              final name = o['name'] ?? '';
              final type = o['type'] ?? '';
              final isSelected = _callAudioOutput == type ||
                (_callAudioOutput == 'bluetooth' && type == 'bluetooth');
              IconData icon;
              if (type == 'speaker')   icon = Icons.volume_up_rounded;
              else if (type == 'bluetooth') icon = Icons.bluetooth_audio_rounded;
              else                     icon = Icons.phone_in_talk_rounded;
              return ListTile(
                leading: Icon(icon, color: isSelected ? const Color(0xFF38BDF8) : Colors.white70),
                title: Text(name, style: TextStyle(color: isSelected ? const Color(0xFF38BDF8) : Colors.white)),
                trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF38BDF8)) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _callAudioOutput = type);
                  _audioService.setAudioOutput(id.startsWith('bluetooth') ? 'bluetooth' : type);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  List<User> get sortedGroupMembers {
    final list = List<User>.from(_groupMembers);
    list.sort((a, b) {
      final aMe = a.name.toLowerCase() == _currentUsername.toLowerCase();
      final bMe = b.name.toLowerCase() == _currentUsername.toLowerCase();
      if (aMe && !bMe) return -1;
      if (!aMe && bMe) return 1;
      
      final aOnline = _isUserOnline(a.name);
      final bOnline = _isUserOnline(b.name);
      if (aOnline && !bOnline) return -1;
      if (!aOnline && bOnline) return 1;
      
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
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
                      itemCount: sortedGroupMembers.length,
                      itemBuilder: (context, i) {
                        final member = sortedGroupMembers[i];
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
              Flexible(
                child: Text(
                  msg.fileName ?? 'File',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: widget.fontSize * 0.85 > 10 ? widget.fontSize * 0.85 : 10, 
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (msg.filePath != null) ...[
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final msgIdStr = msg.id.toString();
                    final localPath = _localFilePaths[msgIdStr];
                    final isDownloaded = localPath != null;

                    if (isDownloaded) {
                      return GestureDetector(
                        onTap: () async {
                          try {
                            final openRes = await OpenFilex.open(localPath);
                            if (openRes.type != ResultType.done && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("⚠️ មិនអាចបើកឯកសារ៖ ${openRes.message}"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint("Error opening file: $e");
                          }
                        },
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(Icons.open_in_new_rounded, color: Color(0xFF38BDF8), size: 20),
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () {
                          final url = msg.filePath!.startsWith('http') ? msg.filePath! : '${ApiService.baseUrl}${msg.filePath}';
                          _downloadFile(context, url, msg.fileName ?? 'downloaded_file', msgId: msgIdStr);
                        },
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Icon(Icons.download_for_offline_rounded, color: Color(0xFF10B981), size: 20),
                        ),
                      );
                    }
                  }
                ),
              ],
            ],
          ),
          if (_shouldShowTime(index)) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(msg.createdAt),
                  style: TextStyle(
                    color: msg.isMe ? Colors.white70 : Colors.white54, 
                    fontSize: widget.fontSize * 0.7 > 9 ? widget.fontSize * 0.7 : 9,
                  ),
                ),
                if (msg.isMe && msg.id != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: msg.seenBy.isNotEmpty ? () => _showSeenByBottomSheet(msg) : null,
                    child: Icon(
                      msg.seenBy.isNotEmpty ? Icons.done_all_rounded : Icons.check_rounded,
                      size: 12,
                      color: msg.seenBy.isNotEmpty ? const Color(0xFF38BDF8) : Colors.white54,
                    ),
                  ),
                ],
              ],
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
                "សារសំឡេង",
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: widget.fontSize, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (_shouldShowTime(index)) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(msg.createdAt),
                  style: TextStyle(
                    color: msg.isMe ? Colors.white70 : Colors.white54,
                    fontSize: widget.fontSize * 0.7 > 9 ? widget.fontSize * 0.7 : 9,
                  ),
                ),
                if (msg.isMe && msg.id != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: msg.seenBy.isNotEmpty ? () => _showSeenByBottomSheet(msg) : null,
                    child: Icon(
                      msg.seenBy.isNotEmpty ? Icons.done_all_rounded : Icons.check_rounded,
                      size: 12,
                      color: msg.seenBy.isNotEmpty ? const Color(0xFF38BDF8) : Colors.white54,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallOverlay() {
    final bool isConnected = _callMode == 'connected';
    final bool isBluetooth = _callAudioOutput == 'bluetooth';
    final bool isSpeaker   = _callAudioOutput == 'speaker';
    final hasBluetooth = _availableOutputs.any((o) => o['type'] == 'bluetooth');

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0F172A).withValues(alpha: 0.97),
              const Color(0xFF1E293B).withValues(alpha: 0.97),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ─── Avatar ───
              CircleAvatar(
                radius: 45,
                backgroundColor: const Color(0xFF334155),
                child: Text(
                  _activeCallUser.isNotEmpty ? _activeCallUser[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Name ───
              Text(
                _activeCallUser,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              // ─── Status / Timer ───
              Text(
                isConnected ? _callDurationText : _callStatusText,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
              ),
              const SizedBox(height: 40),

              // ─── Controls row (only when connected) ───
              if (isConnected) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mute button
                    _buildCallControl(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _isMuted ? ' បិទ Mic' : 'Mic',
                      active: _isMuted,
                      activeColor: const Color(0xFFEF4444),
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 24),
                    // Speaker button
                    _buildCallControl(
                      icon: isSpeaker ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      label: 'ចរន្ត',
                      active: isSpeaker,
                      activeColor: const Color(0xFF38BDF8),
                      onTap: _toggleSpeaker,
                    ),
                    if (hasBluetooth) ...[
                      const SizedBox(width: 24),
                      // Bluetooth button
                      _buildCallControl(
                        icon: Icons.bluetooth_audio_rounded,
                        label: 'Bluetooth',
                        active: isBluetooth,
                        activeColor: const Color(0xFF818CF8),
                        onTap: _showAudioOutputPicker,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 36),
              ],

              // ─── Action buttons ───
              if (_callMode == 'incoming') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reject
                    _buildCallActionBtn(
                      icon: Icons.call_end_rounded,
                      color: const Color(0xFFEF4444),
                      label: 'បដិសេធ',
                      onTap: _rejectCall,
                    ),
                    const SizedBox(width: 60),
                    // Accept
                    _buildCallActionBtn(
                      icon: Icons.call_rounded,
                      color: const Color(0xFF22C55E),
                      label: 'ទទួល',
                      onTap: _acceptCall,
                    ),
                  ],
                ),
              ] else ...[
                _buildCallActionBtn(
                  icon: Icons.call_end_rounded,
                  color: const Color(0xFFEF4444),
                  label: 'ដាក់ចុះ',
                  onTap: _hangupCall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallControl({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: active ? activeColor.withValues(alpha: 0.2) : const Color(0xFF334155),
            child: Icon(icon, color: active ? activeColor : Colors.white70, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: active ? activeColor : Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCallActionBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }


  Widget _buildUploadProgressOverlay() {
    if (!_isUploading) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "កំពុងផ្ញើឯកសារ...",
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    "${(_uploadProgress * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isUploading = false;
                      });
                    },
                    child: const Icon(
                      Icons.cancel_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _uploadStatus,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasChannel = widget.selectedGroup != null;

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

              // PTT Status Banner
              if (_pttState != "idle")
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: _pttState == "talking"
                      ? const Color(0xFF2ECC71).withOpacity(0.15)
                      : const Color(0xFFEF4444).withOpacity(0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _pttState == "talking" ? Icons.record_voice_over_rounded : Icons.mic_external_on_rounded,
                        color: _pttState == "talking" ? const Color(0xFF2ECC71) : const Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _pttState == "talking"
                            ? "🎙️ អ្នកកំពុងនិយាយ..."
                            : "🎙️ $_activePttSpeaker កំពុងនិយាយ...",
                        style: TextStyle(
                          color: _pttState == "talking" ? const Color(0xFF2ECC71) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

              // Main Chat Area
              // Selection top bar (shown when in select mode)
              if (_isSelectMode) _buildSelectionTopBar(),

              Expanded(
                child: hasChannel
                    ? Stack(
                        children: [
                          ListView.builder(
                            controller: _chatScrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        itemCount: _chatMessages.length,
                        itemBuilder: (context, i) {
                          final msg = _chatMessages[i];
                          final showHeader = !msg.isMe && _shouldShowTime(i);
                          // The actual list index (reverse: true, so index 0 = newest)
                          final isSelected = _isSelectMode && _selectedIndexes.contains(i);

                          // Bubble tap/longPress
                          void onLongPress() {
                            if (!_isSelectMode) {
                              _showMessageContextMenu(msg);
                            }
                          }

                          void onTap() {
                            if (_isSelectMode) {
                              setState(() {
                                if (_selectedIndexes.contains(i)) {
                                  _selectedIndexes.remove(i);
                                  if (msg.id != null) _selectedMessageIds.remove(msg.id);
                                  if (_selectedIndexes.isEmpty) {
                                    _isSelectMode = false;
                                  }
                                } else {
                                  _selectedIndexes.add(i);
                                  if (msg.id != null) _selectedMessageIds.add(msg.id!);
                                }
                              });
                            }
                          }

                          Widget bubble = msg.type == 'chat'
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0EA5E9).withValues(alpha: 0.4)
                                        : msg.isMe
                                            ? const Color(0xFF0EA5E9)
                                            : const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(12),
                                      topRight: const Radius.circular(12),
                                      bottomLeft: msg.isMe ? const Radius.circular(12) : const Radius.circular(0),
                                      bottomRight: msg.isMe ? const Radius.circular(0) : const Radius.circular(12),
                                    ),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF334155),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        msg.text ?? '',
                                        style: TextStyle(color: Colors.white, fontSize: widget.fontSize),
                                      ),
                                      if (_shouldShowTime(i)) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatMessageTime(msg.createdAt),
                                              style: TextStyle(
                                                color: msg.isMe ? Colors.white70 : Colors.white54,
                                                fontSize: widget.fontSize * 0.7 > 9 ? widget.fontSize * 0.7 : 9,
                                              ),
                                            ),
                                            if (msg.isMe && msg.id != null) ...[
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: msg.seenBy.isNotEmpty ? () => _showSeenByBottomSheet(msg) : null,
                                                child: Icon(
                                                  msg.seenBy.isNotEmpty ? Icons.done_all_rounded : Icons.check_rounded,
                                                  size: 12,
                                                  color: msg.seenBy.isNotEmpty ? const Color(0xFF38BDF8) : Colors.white54,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              : msg.type == 'file'
                                  ? _buildFileShareWidget(msg, i)
                                  : _buildVoiceMessageWidget(msg, i);

                          // In select mode, wrap bubble in AbsorbPointer so inner taps
                          // (images, download buttons, play buttons) don't consume the event,
                          // allowing the outer GestureDetector.onTap to toggle selection.
                          final wrappedBubble = _isSelectMode ? AbsorbPointer(child: bubble) : bubble;

                          return GestureDetector(
                            onLongPress: onLongPress,
                            onTap: onTap,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Checkbox for select mode (left side for all messages)
                                  if (_isSelectMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8, left: 4),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFF0EA5E9) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF475569),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                            : null,
                                      ),
                                    ),
                                  Flexible(
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
                                          isMe: msg.isMe && !_isSelectMode,
                                          onDelete: () {
                                            _showDeleteDialog(msg);
                                          },
                                          child: wrappedBubble,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (_showScrollToBottom)
                        Positioned(
                          bottom: 12,
                          right: 0,
                          left: 0,
                          child: Center(
                            child: InkWell(
                              onTap: _scrollToBottom,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _hasNewIncomingMessage ? Icons.mark_chat_unread_rounded : Icons.arrow_downward_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _hasNewIncomingMessage ? "សារថ្មី 👇" : "ចុះក្រោម 👇",
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                        onPressed: _showSendFileOptions,
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
                
                _pttDelayTimer?.cancel();
                if (widget.pttMode == 'push') {
                  if (_pttState != 'busy' && _callMode == 'idle') {
                    _pttDelayTimer = Timer(const Duration(milliseconds: 100), () {
                      if (!_isDraggingPtt) {
                        _isPttActiveInAppNotifier.value = true;
                        _handlePttStart();
                      }
                    });
                  }
                }
              },
              onPointerMove: (event) {
                final double dx = event.position.dx - _pttTouchStartX;
                final double dy = event.position.dy - _pttTouchStartY;
                // Once movement exceeds threshold, switch to drag and cancel PTT
                if (!_isDraggingPtt &&
                    (dx * dx + dy * dy) > (_pttDragThreshold * _pttDragThreshold)) {
                  _isDraggingPtt = true;
                  _pttDelayTimer?.cancel();
                  if (_isPttActiveInAppNotifier.value) {
                    _handlePttStop();
                    _isPttActiveInAppNotifier.value = false;
                  }
                }
                if (_isDraggingPtt) {
                  final size = MediaQuery.of(context).size;
                  final double newX = (_pttInitialPosition.dx + dx).clamp(0.0, size.width - 90);
                  final double newY = (_pttInitialPosition.dy + dy).clamp(50.0, size.height - 150);
                  _pttPositionNotifier.value = Offset(newX, newY);
                }
              },
              onPointerUp: (event) {
                _pttDelayTimer?.cancel();
                if (widget.pttMode == 'toggle') {
                  if (!_isDraggingPtt) {
                    if (_isPttActiveInAppNotifier.value) {
                      _handlePttStop();
                      _isPttActiveInAppNotifier.value = false;
                    } else {
                      if (_pttState != 'busy' && _callMode == 'idle') {
                        _isPttActiveInAppNotifier.value = true;
                        _handlePttStart();
                      }
                    }
                  }
                } else {
                  // Normal 'push' mode release
                  if (_isPttActiveInAppNotifier.value) {
                    _handlePttStop();
                  }
                  _isPttActiveInAppNotifier.value = false;
                }
                _isDraggingPtt = false;
              },
              onPointerCancel: (event) {
                _pttDelayTimer?.cancel();
                if (_isPttActiveInAppNotifier.value) {
                  _handlePttStop();
                }
                _isDraggingPtt = false;
                _isPttActiveInAppNotifier.value = false;
              },
              child: ValueListenableBuilder<bool>(
                valueListenable: _isPttActiveInAppNotifier,
                builder: (context, isPttActiveInApp, child) {
                  Color localPttBtnColor = const Color(0xFF0EA5E9);
                  if (_callMode != 'idle') {
                    localPttBtnColor = Colors.grey;
                  } else if (isPttActiveInApp) {
                    localPttBtnColor = const Color(0xFF2ECC71); // Green while we speak!
                  } else if (_pttState == "busy") {
                    localPttBtnColor = const Color(0xFFEF4444);
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOut,
                    transformAlignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(1.0, 1.0, 1.0),
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: localPttBtnColor,
                      boxShadow: [
                        BoxShadow(
                          color: localPttBtnColor.withOpacity(0.5),
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
                          _callMode != 'idle' 
                              ? "📞" 
                              : (isPttActiveInApp 
                                  ? "🎙️" 
                                  : (_pttState == "busy" ? "🛑" : "PTT")),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (_callMode == 'idle' && _pttState != "busy" && !isPttActiveInApp)
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
                },
              ),
            ),
          ),

        if (_callMode != "idle") _buildCallOverlay(),

        if (_isUploading)
          Positioned(
            bottom: 80, // Float above the input field
            left: 0,
            right: 0,
            child: _buildUploadProgressOverlay(),
          ),
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

  void _showMessageContextMenu(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Reply
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF0EA5E9),
                    child: Icon(Icons.reply_rounded, color: Colors.white, size: 18),
                  ),
                  title: const Text("ឆ្លើយ (Reply)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text("ឆ្លើយតបលើសារនេះ", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingTo = msg;
                    });
                  },
                ),
                const Divider(color: Color(0xFF334155), height: 1),
                // Select
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF334155),
                    child: Icon(Icons.check_circle_outline_rounded, color: Colors.white70, size: 18),
                  ),
                  title: const Text("ជ្រើសរើស (Select)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text("ជ្រើសសារដើម្បីលុបបន្ថែម", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Find the index of this message in the list
                    final idx = _chatMessages.indexOf(msg);
                    setState(() {
                      _isSelectMode = true;
                      _selectedIndexes.add(idx < 0 ? 0 : idx);
                      if (msg.id != null) _selectedMessageIds.add(msg.id!);
                    });
                  },
                ),
                // Delete (only own messages)
                if (msg.isMe && msg.id != null) ...[
                  const Divider(color: Color(0xFF334155), height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF7F1D1D),
                      child: Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    ),
                    title: const Text("លុប (Delete)", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                    subtitle: const Text("លុបសារនេះចោល", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showDeleteDialog(msg);
                    },
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteSelectedMessages() async {
    // Collect IDs of own messages that have a DB id
    final ids = _selectedMessageIds.where((id) {
      final msg = _chatMessages.firstWhere((m) => m.id == id, orElse: () => ChatMessage(sender: '', type: 'chat', isMe: false));
      return msg.isMe;
    }).toList();

    // Also collect index-selected own messages that might not have id yet
    // (real-time messages) — just remove them locally
    final indexesWithoutId = _selectedIndexes.where((idx) {
      if (idx < 0 || idx >= _chatMessages.length) return false;
      final m = _chatMessages[idx];
      return m.isMe && m.id == null;
    }).toList();

    if (ids.isEmpty && indexesWithoutId.isEmpty) {
      setState(() {
        _isSelectMode = false;
        _selectedMessageIds.clear();
        _selectedIndexes.clear();
      });
      return;
    }

    final deletedIds = await ApiService.deleteMessages(ids);

    if (deletedIds.isNotEmpty) {
      setState(() {
        _chatMessages.removeWhere((m) => m.id != null && deletedIds.contains(m.id));
        _isSelectMode = false;
        _selectedMessageIds.clear();
        _selectedIndexes.clear();
      });
      for (final id in deletedIds) {
        if (_wsService.isConnected) {
          _wsService.sendAction("delete_message", {"id": id});
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ បានលុប ${deletedIds.length} សារ"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } else {
      // Fallback: delete one by one
      int successCount = 0;
      for (final id in ids) {
        final ok = await ApiService.deleteMessage(id);
        if (ok) {
          successCount++;
          setState(() {
            _chatMessages.removeWhere((m) => m.id == id);
          });
          if (_wsService.isConnected) {
            _wsService.sendAction("delete_message", {"id": id});
          }
        }
      }
      setState(() {
        _isSelectMode = false;
        _selectedMessageIds.clear();
        _selectedIndexes.clear();
      });
      if (mounted && successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ បានលុប $successCount សារ"),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }



  Widget _buildSelectionTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0F172A),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _isSelectMode = false;
              _selectedMessageIds.clear();
              _selectedIndexes.clear();
            }),
            child: const Icon(Icons.close_rounded, color: Colors.white70),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'បានជ្រើស ${_selectedIndexes.length} សារ',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          if (_selectedIndexes.isNotEmpty)
            GestureDetector(
              onTap: _deleteSelectedMessages,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('លុប', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }



  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("[AppLifecycle] App resumed. Waiting to check connection...");
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        debugPrint("[AppLifecycle] App resumed checking: isConnected=${_wsService.isConnected}, selectedGroup=${widget.selectedGroup?.name}");
        if (!_wsService.isConnected && widget.selectedGroup != null) {
          debugPrint("[AppLifecycle] WebSocket not connected on resume. Reconnecting to ${widget.selectedGroup!.name}...");
          _connectWebSocket(widget.selectedGroup!.name);
          _fetchGroupMembers(widget.selectedGroup!.id);
          _fetchGroupMessages(widget.selectedGroup!.id);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsService.disconnect();
    _webrtcService?.dispose();
    _audioService.dispose();
    _ringtoneService.dispose();
    _chatController.dispose();
    _chatScrollController.removeListener(_onChatScroll);
    _chatScrollController.dispose();
    _logsScrollController.dispose();
    _pttPositionNotifier.dispose();
    _isPttActiveInAppNotifier.dispose();
    _pttDelayTimer?.cancel();
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
      // Animate back to closed and show the delete confirmation dialog directly
      _controller.animateTo(0.0, curve: Curves.easeOut).then((_) {
        widget.onDelete();
      });
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

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Transform.translate(
        offset: Offset(_dragOffset, 0.0),
        child: widget.child,
      ),
    );
  }
}

// Top-level function for compute Isolate to encode Base64 without freezing the main thread
String _encodeBase64Isolate(Uint8List bytes) {
  return base64Encode(bytes);
}
