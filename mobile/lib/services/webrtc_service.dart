import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

class WebRTCService {
  final WebSocketService _wsService;
  final String currentUsername;
  
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  
  // Track mute status
  bool _isMuted = true;

  WebRTCService(this._wsService, this.currentUsername);

  // Initialize local microphone stream
  Future<void> initializeLocalStream() async {
    if (_localStream != null) return;
    
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };
    
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      // Initially mute mic track until PTT is pressed
      setMute(_isMuted);
    } catch (e) {
      print("[WebRTCService] Error initializing local stream: $e");
    }
  }

  // Set local mic mute/unmute status
  void setMute(bool mute) {
    _isMuted = mute;
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = !mute;
      }
      print("[WebRTCService] Local mic track set to: ${!mute ? 'UNMUTED' : 'MUTED'}");
    }
  }

  void _setTracksEnabled(bool enabled) {
    if (_localStream != null) {
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
    }
  }

  // Update peer connections based on current online users in room
  Future<void> updatePeers(List<String> onlineUsers) async {
    final cleanOnlineUsers = onlineUsers.map((u) => u.toLowerCase()).toList();
    
    // 1. Clean up users no longer in room
    final peersToRemove = <String>[];
    _peerConnections.forEach((peer, pc) {
      if (!cleanOnlineUsers.contains(peer.toLowerCase())) {
        peersToRemove.add(peer);
      }
    });
    
    for (var peer in peersToRemove) {
      print("[WebRTCService] Peer left channel, cleaning up: $peer");
      await cleanupPeer(peer);
    }

    // 2. Initialize connection for newly online users
    for (var peer in onlineUsers) {
      if (peer.toLowerCase() == currentUsername.toLowerCase()) continue;
      
      if (!_peerConnections.containsKey(peer)) {
        // Deterministic caller: lexicographically smaller username initiates
        if (currentUsername.toLowerCase().compareTo(peer.toLowerCase()) < 0) {
          print("[WebRTCService] Initiating WebRTC offer to $peer (Lexicographically smaller: $currentUsername < $peer)");
          await _initiateOffer(peer);
        }
      }
    }
  }

  // Create PeerConnection
  Future<RTCPeerConnection> _getOrCreatePeerConnection(String peerUsername) async {
    if (_peerConnections.containsKey(peerUsername)) {
      return _peerConnections[peerUsername]!;
    }

    await initializeLocalStream();

    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
      ]
    };
    
    final Map<String, dynamic> constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    final pc = await createPeerConnection(configuration, constraints);

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (candidate) {
      _wsService.sendAction("webrtc_signal", {
        'target': peerUsername,
        'payload': {
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        }
      });
    };

    pc.onTrack = (event) {
      print("[WebRTCService] Track added from peer: $peerUsername");
      Helper.setSpeakerphoneOn(true);
    };

    pc.onAddStream = (stream) {
      print("[WebRTCService] Stream added from peer: $peerUsername");
      Helper.setSpeakerphoneOn(true);
    };

    pc.onConnectionState = (state) {
      print("[WebRTCService] Connection state with $peerUsername: $state");
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        cleanupPeer(peerUsername);
      }
    };

    _peerConnections[peerUsername] = pc;
    return pc;
  }

  // Initiate connection
  Future<void> _initiateOffer(String peerUsername) async {
    try {
      final pc = await _getOrCreatePeerConnection(peerUsername);
      
      // Temporarily enable track for active SDP generation
      _setTracksEnabled(true);
      
      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      
      // Restore actual state
      _setTracksEnabled(!_isMuted);
      
      _wsService.sendAction("webrtc_signal", {
        'target': peerUsername,
        'payload': {
          'type': 'offer',
          'sdp': offer.sdp,
        }
      });
    } catch (e) {
      print("[WebRTCService] Error creating offer for $peerUsername: $e");
    }
  }

  // Handle incoming signals from WebSocket
  Future<void> handleSignal(String sender, Map<String, dynamic> payload) async {
    try {
      final pc = await _getOrCreatePeerConnection(sender);
      final type = payload['type'];

      if (type == 'offer') {
        final sdp = payload['sdp'];
        
        // Temporarily enable track for active SDP generation
        _setTracksEnabled(true);
        
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        
        final answer = await pc.createAnswer({});
        await pc.setLocalDescription(answer);

        // Restore actual state
        _setTracksEnabled(!_isMuted);
        
        _wsService.sendAction("webrtc_signal", {
          'target': sender,
          'payload': {
            'type': 'answer',
            'sdp': answer.sdp,
          }
        });
      } else if (type == 'answer') {
        final sdp = payload['sdp'];
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      } else if (type == 'candidate') {
        final candData = payload['candidate'];
        if (candData != null) {
          final sdpMLineIndex = candData['sdpMLineIndex'] != null 
              ? (candData['sdpMLineIndex'] as num).toInt() 
              : 0;
          await pc.addCandidate(RTCIceCandidate(
            candData['candidate'],
            candData['sdpMid'],
            sdpMLineIndex,
          ));
        }
      }
    } catch (e) {
      print("[WebRTCService] Error handling signaling for $sender: $e");
    }
  }

  // Clean up single peer
  Future<void> cleanupPeer(String peerUsername) async {
    final pc = _peerConnections.remove(peerUsername);
    if (pc != null) {
      await pc.close();
    }
  }

  // Clean up all peer connections but keep local stream
  Future<void> cleanAllPeers() async {
    final keys = List<String>.from(_peerConnections.keys);
    for (var key in keys) {
      await cleanupPeer(key);
    }
  }

  // Clean up all peers and local stream
  Future<void> dispose() async {
    await cleanAllPeers();
    if (_localStream != null) {
      await _localStream!.dispose();
      _localStream = null;
    }
  }
}
