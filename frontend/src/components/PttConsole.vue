<template>
  <div class="ptt-dashboard">
    <div class="panel-left">
      <h2>CamTalk Console</h2>
      
      <div class="group-selector-box">
        <label for="group-select">🔔 ប៉ុស្តិ៍វិទ្យុទាក់ទង៖</label>
        <select id="group-select" v-model="selectedGroupId" @change="handleGroupChange" class="select-input">
          <option v-for="group in myGroups" :key="group.id" :value="group.id">
            📻 {{ group.display_name }} ({{ group.name }})
          </option>
        </select>
      </div>

      <div class="status-bar">
        <p>ស្ថានភាព៖ <span class="txt-bold" :class="systemStatus === 'Connected' ? 'txt-online' : 'txt-offline'">{{ systemStatus }}</span></p>
        <button @click="toggleMute" class="btn-unlock-audio" :class="getAudioClass" :title="getAudioTitle">
          {{ getAudioIcon }}
        </button>
        <p>Online៖ <span class="badge-online">{{ onlineUsersCount }} នាក់</span></p>
      </div>
      
      <button 
        @mousedown="startTalking" 
        @mouseup="stopTalking" 
        @mouseleave="stopTalking"
        @touchstart.prevent="unlockAudio(); startTalking();" 
        @touchend.prevent="stopTalking"
        :class="['ptt-btn', pttState]"
        :disabled="callMode === 'connected'"
      >
        {{ pttButtonText }}
      </button>

      <div class="member-box">
        <h4>បញ្ជីសមាជិកក្នុងក្រុម</h4>
        <div class="member-list">
          <div v-for="user in allRegisteredUsers" :key="user.name" class="member-item">
            <div class="member-info">
              <span v-if="isUserOnline(user.name)" class="status-dot online">🟢</span>
              <span v-else class="status-dot offline">⚫</span>
              
              <!-- Circular Avatar -->
              <div class="member-avatar" :style="getAvatarStyle(user.avatar, user.name)">
                <img v-if="parseAvatar(user.avatar, user.name).type === 'image'" :src="parseAvatar(user.avatar, user.name).value" class="avatar-img" />
                <span v-else-if="parseAvatar(user.avatar, user.name).type === 'emoji'">{{ parseAvatar(user.avatar, user.name).value }}</span>
                <span v-else>{{ parseAvatar(user.avatar, user.name).value }}</span>
              </div>

              <span class="member-name" :class="{ 'is-me': String(user.name).toLowerCase() === String(username).toLowerCase() }">
                {{ user.name }} {{ String(user.name).toLowerCase() === String(username).toLowerCase() ? '(ខ្ញុំ)' : '' }}
              </span>
            </div>
            
            <button 
              v-if="String(user.name).toLowerCase() !== String(username).toLowerCase() && isUserOnline(user.name)" 
              @click="makeCall(user.name)" 
              :disabled="callMode !== 'idle'"
              class="btn-action-call"
            >
              📞 Call
            </button>
            <span v-else-if="String(user.name).toLowerCase() !== String(username).toLowerCase()" class="offline-text">មិនស្ថិតក្នុងប្រព័ន្ធ</span>
          </div>
        </div>
      </div>

      <div v-if="callMode !== 'idle'" class="call-overlay">
        <div class="call-modal">
          <h3>{{ callStatusText }}</h3>
          <p class="call-username">{{ activeCallUser }}</p>
          <div class="call-actions">
            <button v-if="callMode === 'incoming'" @click="acceptCall" class="btn-accept">✔ ទទួល</button>
            <button v-if="callMode === 'incoming'" @click="rejectCall" class="btn-reject">❌ បដិសេធ</button>
            <button v-if="callMode === 'calling' || callMode === 'connected'" @click="hangupCall" class="btn-reject">🔴 ដាក់ចុះ</button>
          </div>
        </div>
      </div>

      <div class="logs-header-section">
        <button @click="showLogs = !showLogs" class="btn-toggle-logs" type="button">
          📋 {{ showLogs ? 'លាក់ System Logs' : 'បង្ហាញ System Logs' }}
        </button>
      </div>

      <div v-if="showLogs" class="logs-container" ref="logsRef">
        <h4>System Logs:</h4>
        <ul><li v-for="(log, i) in logs" :key="i">{{ log }}</li></ul>
      </div>
    </div>

    <div class="panel-right">
      <h4>Group Chat & File Sharing</h4>
      <div class="chat-area" ref="chatRef" @scroll="handleScroll">
        <div v-for="(msg, i) in chatMessages" :key="i" :class="['msg-line', getMessageSenderName(msg) === username ? 'msg-me' : '']">
          <div v-if="getMessageSenderName(msg) !== username && shouldShowTime(msg, i)" class="msg-sender-info">
            <div class="msg-avatar" :style="getAvatarStyle(getMessageSenderAvatar(msg), getMessageSenderName(msg))">
              <img v-if="parseAvatar(getMessageSenderAvatar(msg), getMessageSenderName(msg)).type === 'image'" :src="parseAvatar(getMessageSenderAvatar(msg), getMessageSenderName(msg)).value" class="avatar-img" />
              <span v-else-if="parseAvatar(getMessageSenderAvatar(msg), getMessageSenderName(msg)).type === 'emoji'">{{ parseAvatar(getMessageSenderAvatar(msg), getMessageSenderName(msg)).value }}</span>
              <span v-else>{{ parseAvatar(getMessageSenderAvatar(msg), getMessageSenderName(msg)).value }}</span>
            </div>
            <span class="msg-user-name">{{ getMessageSenderName(msg) }}</span>
          </div>
          <p v-if="msg.type === 'chat'" class="msg-text">
            <span>{{ msg.text }}</span>
            <span v-if="shouldShowTime(msg, i)" class="msg-time">{{ formatMessageTime(msg) }}</span>
          </p>
          <div v-else-if="msg.type === 'file'" class="msg-file">
            <img v-if="msg.file_type && msg.file_type.startsWith('image/')" :src="getFileUrl(msg)" class="preview-img" />
            <div class="file-meta">
              <a v-if="!(msg.file_type && msg.file_type.startsWith('image/'))" :href="getFileUrl(msg)" :download="msg.file_name" target="_blank" class="download-link">
                📁 ឯកសារ៖ {{ msg.file_name }}
              </a>
              <span v-else class="image-name">{{ msg.file_name }}</span>
              <span v-if="shouldShowTime(msg, i)" class="msg-time">{{ formatMessageTime(msg) }}</span>
            </div>
          </div>
          <div v-else-if="msg.type === 'voice'" class="msg-voice">
            <div class="voice-meta">
              <button @click="playVoice(getFileUrl(msg))" class="voice-btn">
                {{ playingUrl === getFileUrl(msg) ? '⏸️ កំពុងចាក់...' : '🔊 សារសំឡេង PTT' }}
              </button>
              <span v-if="shouldShowTime(msg, i)" class="msg-time">{{ formatMessageTime(msg) }}</span>
            </div>
          </div>
        </div>
      </div>
      
      <div class="chat-input">
        <input type="text" v-model="typedText" @keyup.enter="sendChat" placeholder="វាយសារ..." />
        <label class="file-btn">
          📎
          <input type="file" @change="sendFile" style="display: none;" />
        </label>
        <button @click="sendChat">ផ្ញើ</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick, computed, watch } from 'vue';

const props = defineProps({ userToken: { type: String, required: true } });
const username = localStorage.getItem('ptt_username') || 'admin'; 

// Helper: Parse avatar JSON string
const parseAvatar = (avatarStr, usernameVal) => {
  if (!avatarStr) return { type: 'initial', value: usernameVal ? usernameVal.charAt(0).toUpperCase() : 'U' };
  try {
    const parsed = JSON.parse(avatarStr);
    return parsed;
  } catch (e) {
    if (avatarStr.startsWith('data:image/')) {
      return { type: 'image', value: avatarStr };
    }
    return { type: 'initial', value: avatarStr.charAt(0).toUpperCase() };
  }
};

const getAvatarStyle = (avatarStr, usernameVal) => {
  const parsed = parseAvatar(avatarStr, usernameVal);
  if (parsed.type === 'emoji' && parsed.bg) {
    return { backgroundColor: parsed.bg };
  }
  if (parsed.type === 'initial') {
    const colors = ['#3498db', '#2ecc71', '#9b59b6', '#e74c3c', '#f1c40f', '#1abc9c', '#e67e22'];
    let hash = 0;
    const name = usernameVal || 'User';
    for (let i = 0; i < name.length; i++) {
      hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    const color = colors[Math.abs(hash) % colors.length];
    return { backgroundColor: color, color: 'white' };
  }
  return {};
}; 

// អថេរគ្រប់គ្រងទិន្នន័យក្រុមទាញចេញពី Laravel API
const myGroups = ref([]);
const selectedGroupId = ref(null);
const currentChannelName = ref("security"); 
const allRegisteredUsers = ref([]);

const systemStatus = ref("Connecting...");
const onlineUsersCount = ref(0);
const onlineUserList = ref([]); 
const isAudioUnlocked = ref(false);

const callMode = ref("idle"); 
const callStatusText = ref("");
const activeCallUser = ref("");

const pttState = ref("idle");
const pttButtonText = ref("ចុចជាប់ដើម្បីនិយាយ (PTT)");
const logs = ref([]);
const showLogs = ref(false);
const chatMessages = ref([]);
const typedText = ref("");
const chatRef = ref(null);
const logsRef = ref(null);

const activeAudio = ref(null);
const playingUrl = ref(null);

const getMessageSenderName = (msg) => {
  if (msg.sender && typeof msg.sender === 'object') {
    return msg.sender.name;
  }
  return msg.sender || msg.sender_name || 'User';
};

const getMessageSenderAvatar = (msg) => {
  const name = getMessageSenderName(msg);
  if (msg.sender && typeof msg.sender === 'object' && msg.sender.avatar) {
    return msg.sender.avatar;
  }
  const user = allRegisteredUsers.value.find(u => String(u.name).toLowerCase() === String(name).toLowerCase());
  return user ? user.avatar : null;
};

const formatMessageTime = (msg) => {
  const dateStr = msg.created_at;
  if (!dateStr) return '';
  
  const msgDate = new Date(dateStr);
  if (isNaN(msgDate.getTime())) return '';
  
  const now = new Date();
  const diffMs = now.getTime() - msgDate.getTime();
  const diffHours = diffMs / (1000 * 60 * 60);
  
  const timeStr = msgDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false });
  
  if (diffHours >= 24) {
    const datePart = msgDate.toLocaleDateString([], { month: 'short', day: 'numeric' });
    return `${datePart} ${timeStr}`;
  } else {
    return timeStr;
  }
};

const shouldShowTime = (msg, index) => {
  if (index === 0) return true;
  const prevMsg = chatMessages.value[index - 1];
  if (!prevMsg) return true;
  
  // Check if same sender and same formatted time
  const sameSender = getMessageSenderName(msg) === getMessageSenderName(prevMsg);
  const sameTime = formatMessageTime(msg) === formatMessageTime(prevMsg);
  
  return !(sameSender && sameTime);
};

const getFileUrl = (msg) => {
  if (msg.file_data) return msg.file_data;
  if (msg.file_path) {
    const apiBase = import.meta.env.VITE_LARAVEL_API_URL || 'https://api-ptt.stpmtelecom.com';
    return `${apiBase}${msg.file_path}`;
  }
  return '';
};

const playVoice = (url) => {
  if (activeAudio.value) {
    activeAudio.value.pause();
    if (playingUrl.value === url) {
      playingUrl.value = null;
      activeAudio.value = null;
      return;
    }
  }

  playingUrl.value = url;
  const audio = new Audio(url);
  activeAudio.value = audio;
  audio.play();
  audio.onended = () => {
    playingUrl.value = null;
    activeAudio.value = null;
  };
};

const scrollToBottomLogs = () => {
  nextTick(() => {
    if (logsRef.value) {
      logsRef.value.scrollTop = logsRef.value.scrollHeight;
    }
  });
};

watch(logs, () => {
  scrollToBottomLogs();
}, { deep: true });

watch(showLogs, (newVal) => {
  if (newVal) {
    scrollToBottomLogs();
  }
});

let ws = null;
let recordCtx = null; let sourceNode = null; let processorNode = null;
let playCtx = null;

const peerConnections = new Map();
let localStream = null;
let localTrack = null;

// ========================================================
// 🟢 មុខងារទាញយកក្រុមចេញពី LARAVEL BACKEND + DEBUG LOGS
// ========================================================
const fetchUserGroups = async () => {
  try {
    const cleanToken = props.userToken ? props.userToken.trim() : '';
    console.log("🔄 [FRONTEND] កំពុងហៅទៅ Laravel ជាមួយ Token:", `Bearer ${cleanToken}`);

    const response = await fetch(`${import.meta.env.VITE_LARAVEL_API_URL}/api/my-groups`, {
      method: 'GET',
      headers: { 
        'Authorization': `Bearer ${cleanToken}`,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    });
    
    console.log("📊 [LARAVEL STATUS CODE]:", response.status);

    if (response.ok) {
      const data = await response.json();
      console.log("✅ [LARAVEL DATA RECEIVED]:", data);
      
      if (data && data.length > 0) {
        myGroups.value = data;
        selectedGroupId.value = data[0].id;
        currentChannelName.value = data[0].name;
        await fetchGroupMembers(data[0].id);
        const history = await fetchGroupMessages(data[0].id);
        chatMessages.value = history;
        hasMoreMessages.value = history.length >= 15;
        await nextTick();
        if (chatRef.value) chatRef.value.scrollTop = chatRef.value.scrollHeight;
        return; // ចាកចេញដោយជោគជ័យ
      } else {
        console.warn("⚠️ Laravel បោះអារេទទេមកវិញ [] (គណនីនេះមិនទាន់មានក្រុមក្នុង Database)");
      }
    } else {
      const errorText = await response.text();
      console.error("❌ Laravel API Error Text:", errorText);
    }
  } catch (error) {
    console.error("💥 បរាជ័យក្នុងការតភ្ជាប់ទៅ Laravel (Network Error):", error);
  }

  // ⚠️ ប្លុក Fallback បង្ហាញប៉ុស្តិ៍គំរូបើ API ហៅមិនទៅ
  logs.value.push("ប្រព័ន្ធ៖ មិនអាចទាញទិន្នន័យពី Backend បានទេ! កំពុងប្រើទិន្នន័យបណ្តោះអាសន្ន។");
  myGroups.value = [
    { id: 1, name: 'security', display_name: 'ក្រុមសន្តិសុខទូទៅ (គំរូ)' },
    { id: 2, name: 'control_room', display_name: 'បន្ទប់បញ្ជាការ (គំរូ)' }
  ];
  selectedGroupId.value = 1;
  currentChannelName.value = 'security';
  allRegisteredUsers.value = [
    { name: 'admin', avatar: '' },
    { name: 'security_01', avatar: '' },
    { name: 'security_02', avatar: '' }
  ];
};

// ========================================================
// 🟢 មុខងារទាញយកសមាជិកក្នុងក្រុមពី LARAVEL BACKEND
// ========================================================
const fetchGroupMembers = async (groupId) => {
  try {
    const cleanToken = props.userToken ? props.userToken.trim() : '';
    const response = await fetch(`${import.meta.env.VITE_LARAVEL_API_URL}/api/groups/${groupId}/members`, {
      method: 'GET',
      headers: { 
        'Authorization': `Bearer ${cleanToken}`,
        'Accept': 'application/json'
      }
    });
    if (response.ok) {
      const data = await response.json();
      console.log(`✅ សមាជិកក្នុងក្រុម ID ${groupId}:`, data);
      allRegisteredUsers.value = Array.isArray(data) ? data : (data.members || []);
    }
  } catch (error) {
    console.error("Error fetching group members:", error);
  }
};

const hasMoreMessages = ref(true);
const isLoadingMore = ref(false);

const fetchGroupMessages = async (groupId, beforeId = null) => {
  try {
    const cleanToken = props.userToken ? props.userToken.trim() : '';
    let url = `${import.meta.env.VITE_LARAVEL_API_URL}/api/groups/${groupId}/messages`;
    if (beforeId) {
      url += `?before_id=${beforeId}`;
    }
    const response = await fetch(url, {
      method: 'GET',
      headers: { 
        'Authorization': `Bearer ${cleanToken}`,
        'Accept': 'application/json'
      }
    });
    if (response.ok) {
      const data = await response.json();
      console.log(`✅ Message history for group ID ${groupId}:`, data);
      return data;
    }
  } catch (error) {
    console.error("Error fetching group messages:", error);
  }
  return [];
};

const handleScroll = async () => {
  if (!chatRef.value || isLoadingMore.value || !hasMoreMessages.value) return;
  if (chatRef.value.scrollTop === 0) {
    await loadMoreMessages();
  }
};

const loadMoreMessages = async () => {
  if (chatMessages.value.length === 0 || !selectedGroupId.value) return;
  
  isLoadingMore.value = true;
  try {
    const oldestMsg = chatMessages.value[0];
    if (!oldestMsg || !oldestMsg.id) return;
    
    const previousHeight = chatRef.value.scrollHeight;
    
    const olderMessages = await fetchGroupMessages(selectedGroupId.value, oldestMsg.id);
    
    if (olderMessages.length === 0) {
      hasMoreMessages.value = false;
    } else {
      chatMessages.value.unshift(...olderMessages);
      hasMoreMessages.value = olderMessages.length >= 15;
      
      await nextTick();
      chatRef.value.scrollTop = chatRef.value.scrollHeight - previousHeight;
    }
  } catch (error) {
    console.error("Error loading older messages:", error);
  } finally {
    isLoadingMore.value = false;
  }
};

// ========================================================
// 🟢 មុខងារប្តូរក្រុមវិទ្យុទាក់ទង (Switch Room)
// ========================================================
const handleGroupChange = async () => {
  const targetGroup = myGroups.value.find(g => g.id === selectedGroupId.value);
  if (!targetGroup) return;

  logs.value.push(`ប្រព័ន្ធ៖ កំពុងប្តូរទៅកាន់ក្រុម ${targetGroup.display_name}...`);
  currentChannelName.value = targetGroup.name;
  
  chatMessages.value = [];
  onlineUserList.value = [];
  onlineUsersCount.value = 0;
  hasMoreMessages.value = true;
  isLoadingMore.value = false;

  await fetchGroupMembers(targetGroup.id);
  const history = await fetchGroupMessages(targetGroup.id);
  chatMessages.value = history;
  hasMoreMessages.value = history.length >= 15;
  await nextTick();
  if (chatRef.value) chatRef.value.scrollTop = chatRef.value.scrollHeight;

  cleanupAllPeers();
  if (ws) ws.close();
  connectWS();
};

const isUserOnline = (user) => {
  if (!user) return false;
  return onlineUserList.value.includes(String(user).toLowerCase());
};

const isMuted = ref(false);

const toggleMute = async () => {
  if (!isAudioUnlocked.value) {
    await unlockAudio();
  }
  isMuted.value = !isMuted.value;
};

const getAudioIcon = computed(() => {
  return isMuted.value ? '🔇' : '🔊';
});

const getAudioClass = computed(() => {
  return isMuted.value ? 'audio-muted' : 'audio-active';
});

const getAudioTitle = computed(() => {
  return isMuted.value ? 'បើកសំឡេងវិញ (Muted)' : 'បិទសំឡេង (Unmuted)';
});

const unlockAudio = async () => {
  if (isAudioUnlocked.value) return;
  try {
    if (!playCtx) playCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });
    if (playCtx.state === 'suspended') await playCtx.resume();
    isAudioUnlocked.value = true;
  } catch (err) { console.error(err); }
};

const connectWS = () => {
  systemStatus.value = "Connecting...";
  ws = new WebSocket(`${import.meta.env.VITE_FASTAPI_WS_URL}/ws/${currentChannelName.value}?token=${props.userToken}`);
  
  ws.onopen = () => { systemStatus.value = "Connected"; };
  ws.onmessage = async (event) => {
    if (event.data instanceof Blob) {
      playAudio(event.data);
    } else {
      try {
        const data = JSON.parse(event.data);
        if (data && data.type === 'user_count') {
          onlineUsersCount.value = Number(data.count) || 0;
          if (Array.isArray(data.user_list)) {
            const newOnlineList = data.user_list.map(name => String(name).toLowerCase());
            
            // Clean up users that are no longer online
            for (const peerUsername of peerConnections.keys()) {
              if (!newOnlineList.includes(peerUsername.toLowerCase())) {
                cleanupPeer(peerUsername);
              }
            }
            
            onlineUserList.value = newOnlineList;
            
            // Initiate connections for newly online users
            for (const name of data.user_list) {
              if (String(name).toLowerCase() === String(username).toLowerCase()) continue;
              
              if (!peerConnections.has(name)) {
                // If I am lexicographically smaller, I initiate the offer
                if (String(username).toLowerCase() < String(name).toLowerCase()) {
                  initiateOffer(name);
                }
              }
            }
          }
        } 
        else if (data && (data.type === 'chat' || data.type === 'file')) {
          if (!data.created_at) {
            data.created_at = new Date().toISOString();
          }
          chatMessages.value.push(data);
          await nextTick(); 
          if (chatRef.value) chatRef.value.scrollTop = chatRef.value.scrollHeight;
        } 
        else if (data && data.type === 'webrtc_signal') {
          handleWebrtcSignal(data);
        }
        else if (data && data.type === 'call_signal') {
          handleCallSignal(data);
        }
        else if (data && data.type === 'ptt_status') {
          if (data.status === 'talking_granted') {
            pttState.value = 'talking'; 
            pttButtonText.value = '🎙️ អ្នកកំពុងនិយាយ...'; 
            if (localTrack) localTrack.enabled = true;
            startRecording();
          } else if (data.status === 'line_busy') {
            pttState.value = 'busy'; 
            pttButtonText.value = '❌ ខ្សែរវល់';
            if (localTrack) localTrack.enabled = false;
          } else if (data.status === 'idle') {
            pttState.value = 'idle'; 
            pttButtonText.value = 'ចុចជាប់ដើម្បីនិយាយ (PTT)';
            if (localTrack) localTrack.enabled = false;
            stopRecording();
          }
        } else if (data && data.type === 'system') {
          logs.value.push(data.message);
        }
      } catch (err) { console.error(err); }
    }
  };
  ws.onclose = () => { systemStatus.value = "Disconnected"; cleanupAllPeers(); stopCallAudio(); };
};

// --- WebRTC P2P Mesh group PTT helper functions ---
const getOrCreatePeerConnection = async (peerUsername) => {
  if (peerConnections.has(peerUsername)) {
    return peerConnections.get(peerUsername);
  }

  if (!localStream) {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });
      localTrack = localStream.getAudioTracks()[0];
      localTrack.enabled = pttState.value === 'talking';
    } catch (err) {
      console.error("Failed to get local user media", err);
      logs.value.push(`កំហុស៖ មិនអាចបើក Microphone បានទេ៖ ${err.message}`);
    }
  }

  const pc = new RTCPeerConnection({
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
      { urls: 'stun:stun2.l.google.com:19302' }
    ]
  });

  if (localStream) {
    localStream.getTracks().forEach(track => {
      pc.addTrack(track, localStream);
    });
  }

  pc.onicecandidate = (event) => {
    if (event.candidate && ws?.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        action: "webrtc_signal",
        target: peerUsername,
        payload: {
          type: "candidate",
          candidate: event.candidate
        }
      }));
    }
  };

  pc.ontrack = (event) => {
    console.log(`Received remote track from ${peerUsername}`);
    logs.value.push(`ប្រព័ន្ធ៖ ទទួលបានសំឡេងពី ${peerUsername}`);
    
    const remoteStream = event.streams[0] || new MediaStream([event.track]);
    
    let audioEl = document.getElementById(`audio-${peerUsername}`);
    if (!audioEl) {
      audioEl = document.createElement('audio');
      audioEl.id = `audio-${peerUsername}`;
      audioEl.autoplay = true;
      document.body.appendChild(audioEl);
    }
    audioEl.srcObject = remoteStream;
    audioEl.play().catch(e => console.error("Playback error", e));
  };

  pc.onconnectionstatechange = () => {
    console.log(`Connection state with ${peerUsername}: ${pc.connectionState}`);
    logs.value.push(`ប្រព័ន្ធ៖ ស្ថានភាពតភ្ជាប់ជាមួយ ${peerUsername} គឺ ${pc.connectionState}`);
    if (pc.connectionState === 'failed' || pc.connectionState === 'closed') {
      cleanupPeer(peerUsername);
    }
  };

  peerConnections.set(peerUsername, pc);
  return pc;
};

const initiateOffer = async (peerUsername) => {
  try {
    const pc = await getOrCreatePeerConnection(peerUsername);
    
    // Temporarily enable track for active SDP generation
    if (localTrack) localTrack.enabled = true;
    
    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    
    // Restore actual state
    if (localTrack) localTrack.enabled = pttState.value === 'talking';
    
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({
        action: "webrtc_signal",
        target: peerUsername,
        payload: {
          type: "offer",
          sdp: pc.localDescription.sdp
        }
      }));
    }
  } catch (err) {
    console.error(`Failed to create offer for ${peerUsername}`, err);
  }
};

const handleWebrtcSignal = async (data) => {
  const peerUsername = data.sender;
  const payload = data.payload;

  try {
    const pc = await getOrCreatePeerConnection(peerUsername);

    if (payload.type === "offer") {
      // Temporarily enable track for active SDP generation
      if (localTrack) localTrack.enabled = true;
      
      await pc.setRemoteDescription(new RTCSessionDescription({
        type: "offer",
        sdp: payload.sdp
      }));
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      
      // Restore actual state
      if (localTrack) localTrack.enabled = pttState.value === 'talking';
      
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
          action: "webrtc_signal",
          target: peerUsername,
          payload: {
            type: "answer",
            sdp: pc.localDescription.sdp
          }
        }));
      }
    } else if (payload.type === "answer") {
      await pc.setRemoteDescription(new RTCSessionDescription({
        type: "answer",
        sdp: payload.sdp
      }));
    } else if (payload.type === "candidate") {
      if (payload.candidate) {
        await pc.addIceCandidate(new RTCIceCandidate(payload.candidate));
      }
    }
  } catch (err) {
    console.error(`Error processing WebRTC signal from ${peerUsername}`, err);
  }
};

const cleanupPeer = (peerUsername) => {
  const pc = peerConnections.get(peerUsername);
  if (pc) {
    pc.close();
    peerConnections.delete(peerUsername);
  }
  const audioEl = document.getElementById(`audio-${peerUsername}`);
  if (audioEl) {
    audioEl.srcObject = null;
    audioEl.remove();
  }
};

const cleanupAllPeers = () => {
  for (const peerUsername of peerConnections.keys()) {
    cleanupPeer(peerUsername);
  }
  if (localStream) {
    localStream.getTracks().forEach(track => track.stop());
    localStream = null;
    localTrack = null;
  }
};

// --- WebRTC Call, PTT Recording & Audio Playback ---
const makeCall = (targetUser) => { unlockAudio(); callMode.value = "calling"; callStatusText.value = "📞 កំពុងហៅទៅកាន់..."; activeCallUser.value = targetUser; ws.send(JSON.stringify({ action: "call_user", target: targetUser })); };
const handleCallSignal = (data) => { if (data.status === "call_user") { callMode.value = "incoming"; callStatusText.value = "🔔 មានការហៅចូលពី..."; activeCallUser.value = data.sender; } else if (data.status === "call_accepted") { callMode.value = "connected"; callStatusText.value = "🟢 កំពុងនិយាយទូរស័ព្ទជាមួយ..."; logs.value.push(`ប្រព័ន្ធ៖ ការហៅទូរស័ព្ទជាមួយ ${data.sender} ត្រូវបានភ្ជាប់។`); startCallAudio(); } else if (data.status === "call_rejected") { callMode.value = "idle"; alert(`${data.sender} បានបដិសេធមិនទទួលទូរស័ព្ទទេ។`); } else if (data.status === "call_hungup") { callMode.value = "idle"; logs.value.push(`ប្រព័ន្ធ៖ ${data.sender} បានដាក់ទូរស័ព្ទចុះ។`); stopCallAudio(); } };
const acceptCall = () => { unlockAudio(); callMode.value = "connected"; callStatusText.value = "🟢 កំពុងនិយាយទូរស័ព្ទជាមួយ..."; ws.send(JSON.stringify({ action: "call_accepted", target: activeCallUser.value })); startCallAudio(); };
const rejectCall = () => { callMode.value = "idle"; ws.send(JSON.stringify({ action: "call_rejected", target: activeCallUser.value })); };
const hangupCall = () => { callMode.value = "idle"; ws.send(JSON.stringify({ action: "call_hungup", target: activeCallUser.value })); stopCallAudio(); };
const startCallAudio = async () => { try { const stream = await navigator.mediaDevices.getUserMedia({ audio: true }); recordCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 }); sourceNode = recordCtx.createMediaStreamSource(stream); processorNode = recordCtx.createScriptProcessor(4096, 1, 1); processorNode.onaudioprocess = (e) => { if (callMode.value !== 'connected') return; const input = e.inputBuffer.getChannelData(0); const buffer = new Int16Array(input.length); for (let i = 0; i < input.length; i++) buffer[i] = Math.min(1, Math.max(-1, input[i])) * 0x7FFF; if (ws?.readyState === WebSocket.OPEN) ws.send(buffer.buffer); }; sourceNode.connect(processorNode); processorNode.connect(recordCtx.destination); } catch (err) { console.error(err); } };
const stopCallAudio = () => { stopRecording(); };
const startTalking = () => { if (callMode.value === 'connected') return; if (ws?.readyState === WebSocket.OPEN && pttState.value === 'idle') ws.send(JSON.stringify({ action: "ptt_start" })); };
const stopTalking = () => { if (pttState.value === 'talking') { stopRecording(); ws.send(JSON.stringify({ action: "ptt_stop" })); } };
const startRecording = async () => { try { const stream = await navigator.mediaDevices.getUserMedia({ audio: true }); recordCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 }); sourceNode = recordCtx.createMediaStreamSource(stream); processorNode = recordCtx.createScriptProcessor(4096, 1, 1); processorNode.onaudioprocess = (e) => { if (pttState.value !== 'talking') return; const input = e.inputBuffer.getChannelData(0); const buffer = new Int16Array(input.length); for (let i = 0; i < input.length; i++) buffer[i] = Math.min(1, Math.max(-1, input[i])) * 0x7FFF; if (ws?.readyState === WebSocket.OPEN) ws.send(buffer.buffer); }; sourceNode.connect(processorNode); processorNode.connect(recordCtx.destination); } catch (err) { console.error(err); } };
const stopRecording = () => { if (processorNode) { processorNode.disconnect(); processorNode = null; } if (sourceNode) { sourceNode.disconnect(); sourceNode = null; } if (recordCtx && recordCtx.state !== 'closed') { recordCtx.close(); recordCtx = null; } };
const playAudio = async (blob) => { if (isMuted.value) return; try { if (!playCtx) playCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 }); if (playCtx.state === 'suspended') await playCtx.resume(); const arrayBuffer = await blob.arrayBuffer(); const int16 = new Int16Array(arrayBuffer); const float32 = new Float32Array(int16.length); for (let i = 0; i < int16.length; i++) float32[i] = int16[i] / 0x7FFF; const audioBuffer = playCtx.createBuffer(1, float32.length, 16000); audioBuffer.getChannelData(0).set(float32); const source = playCtx.createBufferSource(); source.buffer = audioBuffer; source.connect(playCtx.destination); source.start(); } catch (e) { console.error(e); } };
const sendChat = () => { if (!typedText.value.trim()) return; ws.send(JSON.stringify({ action: "chat_message", text: typedText.value })); typedText.value = ""; };
const sendFile = (event) => { const file = event.target.files[0]; if (!file) return; if (file.size > 5 * 1024 * 1024) { alert("File ត្រូវតែមានទំហំតូចជាង 5MB"); return; } const reader = new FileReader(); reader.onload = () => { ws.send(JSON.stringify({ action: "file_share", file_name: file.name, file_type: file.type, file_data: reader.result })); }; reader.readAsDataURL(file); };
const handleBeforeUnload = () => { closeConnection(); };
const closeConnection = () => { if (ws) ws.close(); stopCallAudio(); };

onMounted(async () => { 
  await fetchUserGroups(); 
  connectWS(); 
  
  // Auto-unlock audio context on first user interaction anywhere
  const unlockOnFirstClick = async () => {
    await unlockAudio();
    document.removeEventListener('click', unlockOnFirstClick);
    document.removeEventListener('touchstart', unlockOnFirstClick);
  };
  document.addEventListener('click', unlockOnFirstClick);
  document.addEventListener('touchstart', unlockOnFirstClick);

  window.addEventListener('beforeunload', handleBeforeUnload); 
});
onUnmounted(() => { closeConnection(); window.removeEventListener('beforeunload', handleBeforeUnload); });
</script>

<style scoped>
.ptt-dashboard { display: flex; width: 100%; max-width: 1024px; height: 680px; background: white; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.15); font-family: sans-serif; overflow: hidden; margin: 0 auto; }
.panel-left { width: 45%; padding: 15px; border-right: 1px solid #eee; display: flex; flex-direction: column; align-items: center; justify-content: space-between; position: relative; gap: 10px; box-sizing: border-box; }
.panel-right { width: 55%; padding: 20px; display: flex; flex-direction: column; background: #fafafa; box-sizing: border-box; }

/* ស្ទីល Dropdown ជ្រើសរើសក្រុម */
.group-selector-box { width: 100%; text-align: left; display: flex; flex-direction: column; gap: 5px; }
.group-selector-box label { font-size: 13px; font-weight: bold; color: #34495e; }
.select-input { width: 100%; padding: 8px 12px; border-radius: 6px; border: 1px solid #cbd5e0; background: #fff; font-size: 14px; color: #2d3748; cursor: pointer; outline: none; }
.select-input:focus { border-color: #3498db; }

.status-bar { width: 100%; display: flex; justify-content: space-between; align-items: center; font-size: 13px; border-bottom: 1px solid #f0f0f0; padding-bottom: 5px; }
.txt-online { color: #2ecc71; font-weight: bold; }
.txt-offline { color: #e74c3c; font-weight: bold; }
.badge-online { background: #2ecc71; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold; }
.btn-unlock-audio {
  border: none;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  font-size: 14px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
  transition: all 0.2s ease;
}
.btn-unlock-audio.audio-locked {
  background: #f1c40f;
  color: #2c3e50;
  animation: pulse 1.5s infinite;
}
.btn-unlock-audio.audio-active {
  background: #2ecc71;
  color: white;
}
.btn-unlock-audio.audio-muted {
  background: #e74c3c;
  color: white;
}
@keyframes pulse { 0% { transform: scale(1); } 50% { transform: scale(1.05); } 100% { transform: scale(1); } }
.ptt-btn { width: 110px; height: 110px; border-radius: 50%; border: none; font-size: 11px; font-weight: bold; color: white; cursor: pointer; transition: 0.2s; box-shadow: 0 4px 8px rgba(0,0,0,0.1); user-select: none; -webkit-user-select: none; }
.idle { background: #3498db; } .talking { background: #2ecc71; } .busy { background: #e74c3c; }
.member-box { width: 100%; flex-grow: 1; display: flex; flex-direction: column; text-align: left; background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 8px; padding: 10px; overflow: hidden; }
.member-box h4 { margin: 0 0 8px 0; color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 4px; font-size: 14px; }
.member-list { flex-grow: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 6px; }
.member-item { display: flex; justify-content: space-between; align-items: center; background: white; padding: 8px 10px; border-radius: 6px; border: 1px solid #edf2f7; }
.member-info { display: flex; align-items: center; gap: 8px; }
.member-avatar {
  width: 24px;
  height: 24px;
  background: #edf2f7;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  font-weight: bold;
  font-size: 11px;
  overflow: hidden;
}
.member-avatar .avatar-img {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
}
.status-dot { font-size: 11px; }
.member-name { font-size: 13px; font-weight: 500; color: #2d3748; }
.is-me { color: #3182ce; font-weight: bold; }
.btn-action-call { background: #e67e22; color: white; border: none; padding: 4px 10px; border-radius: 4px; font-size: 12px; font-weight: bold; cursor: pointer; }
.offline-text { font-size: 11px; color: #a0aec0; font-style: italic; }
.call-overlay { position: absolute; top:0; left:0; width:100%; height:100%; background: rgba(0,0,0,0.7); display:flex; align-items:center; justify-content:center; z-index: 99; }
.call-modal { background: white; padding: 20px; border-radius: 8px; text-align: center; width: 85%; }
.call-username { font-size: 18px; font-weight: bold; color: #2c3e50; margin: 10px 0; }
.call-actions { display: flex; gap: 10px; justify-content: center; margin-top: 15px; }
.btn-accept { background: #2ecc71; color: white; border: none; padding: 8px 15px; border-radius: 4px; font-weight: bold; }
.btn-reject { background: #e74c3c; color: white; border: none; padding: 8px 15px; border-radius: 4px; font-weight: bold; }
.logs-header-section {
  width: 100%;
  display: flex;
  justify-content: center;
  margin-top: 10px;
  margin-bottom: 5px;
}
.btn-toggle-logs {
  background: #f1f2f6;
  color: #57606f;
  border: 1px solid #ced6e0;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: bold;
  cursor: pointer;
  transition: all 0.2s;
  width: 100%;
  text-align: center;
  box-sizing: border-box;
}
.btn-toggle-logs:hover {
  background: #e4e7eb;
  color: #2f3542;
}
.logs-container { width: 100%; text-align: left; background: #fff; max-height: 80px; overflow-y: auto; border: 1px solid #ddd; border-radius: 6px; padding: 6px; box-sizing: border-box; margin-top: 5px; }
.logs-container ul { list-style: none; padding: 0; margin: 0; }
.logs-container li { padding: 2px 4px; margin-bottom: 2px; background: #f9f9f9; border-left: 3px solid #7f8c8d; color: #111; font-size: 11px; }
.chat-area {
  flex-grow: 1;
  background: #eef2f5;
  background-image: radial-gradient(#d5dde3 1px, transparent 0);
  background-size: 16px 16px;
  border: 1px solid #ced4da;
  border-radius: 10px;
  padding: 15px;
  overflow-y: auto;
  margin-bottom: 10px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.msg-line {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  max-width: 75%;
  margin-bottom: 2px;
}
.msg-me {
  align-self: flex-end;
  align-items: flex-end;
}
.msg-sender-info {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}
.msg-avatar {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
  font-size: 9px;
  font-weight: bold;
  color: white;
  user-select: none;
}
.msg-avatar .avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.msg-user-name {
  font-size: 11px;
  font-weight: bold;
  color: #555;
}
.msg-text {
  background: #ffffff;
  padding: 8px 14px;
  border-radius: 12px 12px 12px 4px;
  font-size: 13.5px;
  margin: 0;
  color: #212529;
  box-shadow: 0 1.5px 2px rgba(0,0,0,0.06);
  line-height: 1.4;
  word-break: break-word;
  display: flex;
  flex-direction: column;
}
.msg-me .msg-text {
  background: #d9fdd3;
  color: #111;
  border-radius: 12px 12px 4px 12px;
  box-shadow: 0 1.5px 2px rgba(0,0,0,0.08);
}
.msg-time {
  font-size: 9px;
  color: #8c9094;
  align-self: flex-end;
  margin-top: 4px;
  margin-left: 8px;
  user-select: none;
}
.msg-me .msg-time {
  color: #638253;
}
.file-meta, .voice-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  margin-top: 4px;
}
.image-name {
  font-size: 11px;
  color: #718096;
}
.preview-img { max-width: 140px; max-height: 140px; border-radius: 6px; margin-top: 4px; }
.download-link { background: #f1f2f6; color: #2f3542; padding: 6px 10px; border-radius: 6px; font-size: 12px; text-decoration: none; display: inline-block; border: 1px solid #ddd; margin-top: 4px; }
.msg-file {
  background: #ffffff;
  padding: 8px 8px;
  border-radius: 12px 12px 12px 4px;
  box-shadow: 0 1.5px 2px rgba(0,0,0,0.06);
}
.msg-me .msg-file {
  background: #d9fdd3;
  border-radius: 12px 12px 4px 12px;
}
.msg-voice {
  background: #ffffff;
  padding: 8px 8px;
  border-radius: 12px 12px 12px 4px;
  box-shadow: 0 1.5px 2px rgba(0,0,0,0.06);
}
.msg-me .msg-voice {
  background: #d9fdd3;
  border-radius: 12px 12px 4px 12px;
}
.voice-btn {
  background: #3498db;
  color: white;
  border: none;
  padding: 6px 14px;
  border-radius: 8px;
  font-size: 12px;
  font-weight: bold;
  cursor: pointer;
  transition: background 0.2s;
}
.voice-btn:hover {
  background: #2980b9;
}
.msg-me .voice-btn {
  background: #2ecc71;
}
.msg-me .voice-btn:hover {
  background: #27ae60;
}
.chat-input { display: flex; gap: 5px; align-items: center; }
.chat-input input { flex-grow: 1; padding: 8px; border: 1px solid #ccc; border-radius: 4px; }
.file-btn { font-size: 20px; cursor: pointer; padding: 0 5px; }
.chat-input button { padding: 8px 15px; background: #2c3e50; color: white; border: none; border-radius: 4px; }

@media (max-width: 1024px) {
  .ptt-dashboard { flex-direction: column; height: auto; border-radius: 0; margin: 0; box-shadow: none; }
  .panel-left, .panel-right { width: 100%; border-right: none; }
  .panel-left { border-bottom: 1px solid #eee; padding: 15px; }
  .panel-right { height: 480px; padding: 15px; }
  .member-box { max-height: 220px; }
}
</style>