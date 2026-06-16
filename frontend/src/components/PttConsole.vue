<template>
  <div class="ptt-dashboard">
    <div class="panel-left">
      <h2>FlashPTT Console</h2>
      <div class="status-bar">
        <p>ស្ថានភាព៖ <span class="txt-bold">{{ systemStatus }}</span></p>
        <p>អនឡាញ៖ <span class="badge-online">{{ onlineUsers }} នាក់</span></p>
      </div>
      
      <button 
        @mousedown="startTalking" @mouseup="stopTalking" @mouseleave="stopTalking"
        :class="['ptt-btn', pttState]"
        :disabled="callMode === 'connected'"
      >
        {{ pttButtonText }}
      </button>

      <div class="call-section">
        <h4>Private Call (ទូរស័ព្ទ)</h4>
        <select v-model="selectedUser">
          <option value="">-- ជ្រើសរើសអ្នកត្រូវ Call --</option>
          <option v-for="user in userList" :key="user" v-show="user !== username" :value="user">
            📞 Call ទៅ {{ user }}
          </option>
        </select>
        <button @click="makeCall" :disabled="!selectedUser || callMode !== 'idle'" class="btn-call">Call</button>
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

      <div class="logs-container">
        <h4>System Logs:</h4>
        <ul><li v-for="(log, i) in logs" :key="i">{{ log }}</li></ul>
      </div>
    </div>

    <div class="panel-right">
      <h4>Group Chat & File Sharing</h4>
      <div class="chat-area" ref="chatRef">
        <div v-for="(msg, i) in chatMessages" :key="i" :class="['msg-line', msg.sender === username ? 'msg-me' : '']">
          <span class="msg-user">{{ msg.sender }}</span>
          
          <p v-if="msg.type === 'chat'" class="msg-text">{{ msg.text }}</p>
          
          <div v-else-if="msg.type === 'file'" class="msg-file">
            <img v-if="msg.file_type.startsWith('image/')" :src="msg.file_data" class="preview-img" />
            <a v-else :href="msg.file_data" :download="msg.file_name" class="download-link">
              📁 ឯកសារ៖ {{ msg.file_name }} (ទាញយក)
            </a>
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
import { ref, onMounted, onUnmounted, nextTick } from 'vue';

const props = defineProps({ userToken: { type: String, required: true } });
const username = localStorage.getItem('ptt_username') || 'Me';
const channel = "security";

const systemStatus = ref("Connecting...");
const onlineUsers = ref(0);
const userList = ref([]);
const selectedUser = ref("");

// ស្ថានភាព Call: idle, calling, incoming, connected
const callMode = ref("idle"); 
const callStatusText = ref("");
const activeCallUser = ref("");

const pttState = ref("idle");
const pttButtonText = ref("ចុចជាប់ដើម្បីនិយាយ (PTT)");
const logs = ref([]);
const chatMessages = ref([]);
const typedText = ref("");
const chatRef = ref(null);

let ws = null;
let recordCtx = null; let sourceNode = null; let processorNode = null;
let playCtx = null;

const connectWS = () => {
  ws = new WebSocket(`ws://192.168.100.11:9000/ws/${channel}?token=${props.userToken}`);
  ws.onopen = () => { systemStatus.value = "Connected"; };
  
  ws.onmessage = async (event) => {
    if (event.data instanceof Blob) {
      playAudio(event.data);
    } else {
      const data = JSON.parse(event.data);
      
      if (data.type === 'user_count') {
        onlineUsers.value = data.count;
        userList.value = data.user_list; 
      } else if (data.type === 'chat' || data.type === 'file') {
        chatMessages.value.push(data);
        await nextTick(); chatRef.value.scrollTop = chatRef.value.scrollHeight;
      } 
      else if (data.type === 'call_signal') {
        handleCallSignal(data);
      }
      else if (data.type === 'ptt_status') {
        if (data.status === 'talking_granted') {
          pttState.value = 'talking'; pttButtonText.value = '🎙️ អ្នកកំពុងនិយាយ...'; startRecording();
        } else if (data.status === 'line_busy') {
          pttState.value = 'busy'; pttButtonText.value = '❌ ខ្សែរវល់';
        } else if (data.status === 'idle') {
          pttState.value = 'idle'; pttButtonText.value = 'ចុចជាប់ដើម្បីនិយាយ (PTT)';
        }
      } else if (data.type === 'system') {
        logs.value.push(data.message);
      }
    }
  };
  ws.onclose = () => { systemStatus.value = "Disconnected"; stopCallAudio(); };
};

// --- 🎯 ប្រព័ន្ធគ្រប់គ្រងការ Call ឮសំឡេងទាំងសងខាង ---
const makeCall = () => {
  callMode.value = "calling";
  callStatusText.value = "📞 កំពុងហៅទៅកាន់...";
  activeCallUser.value = selectedUser.value;
  ws.send(JSON.stringify({ action: "call_user", target: selectedUser.value }));
};

const handleCallSignal = (data) => {
  if (data.status === "call_user") {
    callMode.value = "incoming";
    callStatusText.value = "🔔 មានការហៅចូលពី...";
    activeCallUser.value = data.sender;
  } else if (data.status === "call_accepted") {
    callMode.value = "connected";
    callStatusText.value = "🟢 កំពុងនិយាយទូរស័ព្ទជាមួយ...";
    logs.value.push(`ប្រព័ន្ធ៖ ការហៅទូរស័ព្ទជាមួយ ${data.sender} ត្រូវបានភ្ជាប់។`);
    startCallAudio(); // បើក Mic និយាយរកគ្នាស្វ័យប្រវត្តិតែម្តង
  } else if (data.status === "call_rejected") {
    callMode.value = "idle";
    alert(`${data.sender} បានបដិសេធមិនទទួលទូរស័ព្ទទេ។`);
  } else if (data.status === "call_hungup") {
    callMode.value = "idle";
    logs.value.push(`ប្រព័ន្ធ៖ ${data.sender} បានដាក់ទូរស័ព្ទចុះ។`);
    stopCallAudio(); // បិទ Mic ឈប់ Stream សំឡេង
  }
};

const acceptCall = () => {
  callMode.value = "connected";
  callStatusText.value = "🟢 កំពុងនិយាយទូរស័ព្ទជាមួយ...";
  ws.send(JSON.stringify({ action: "call_accepted", target: activeCallUser.value }));
  startCallAudio(); // អ្នកទទួលចុចយល់ព្រម ក៏បើក Mic ផ្ញើសំឡេងទៅវិញដែរ
};

const rejectCall = () => {
  callMode.value = "idle";
  ws.send(JSON.stringify({ action: "call_rejected", target: activeCallUser.value }));
};

const hangupCall = () => {
  callMode.value = "idle";
  ws.send(JSON.stringify({ action: "call_hungup", target: activeCallUser.value }));
  stopCallAudio();
};

const startCallAudio = async () => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    recordCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });
    sourceNode = recordCtx.createMediaStreamSource(stream);
    processorNode = recordCtx.createScriptProcessor(4096, 1, 1);
    
    processorNode.onaudioprocess = (e) => {
      if (callMode.value !== 'connected') return; // បើមិនមែនកំពុង Call ទេ មិនឱ្យ Stream ឡើយ
      const input = e.inputBuffer.getChannelData(0);
      const buffer = new Int16Array(input.length);
      for (let i = 0; i < input.length; i++) buffer[i] = Math.min(1, Math.max(-1, input[i])) * 0x7FFF;
      if (ws?.readyState === WebSocket.OPEN) ws.send(buffer.buffer);
    };
    sourceNode.connect(processorNode); processorNode.connect(recordCtx.destination);
  } catch (err) { console.error("មិនអាចបើក Mic សម្រាប់ Call៖", err); }
};

const stopCallAudio = () => {
  stopRecording();
};

// --- ប្រព័ន្ធ PTT Walkie-Talkie ---
const startTalking = () => { 
  if (callMode.value === 'connected') return;
  if (ws?.readyState === WebSocket.OPEN && pttState.value === 'idle') ws.send(JSON.stringify({ action: "ptt_start" })); 
};
const stopTalking = () => { 
  if (pttState.value === 'talking') { stopRecording(); ws.send(JSON.stringify({ action: "ptt_stop" })); } 
};

const startRecording = async () => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    recordCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });
    sourceNode = recordCtx.createMediaStreamSource(stream);
    processorNode = recordCtx.createScriptProcessor(4096, 1, 1);
    processorNode.onaudioprocess = (e) => {
      if (pttState.value !== 'talking') return;
      const input = e.inputBuffer.getChannelData(0); const buffer = new Int16Array(input.length);
      for (let i = 0; i < input.length; i++) buffer[i] = Math.min(1, Math.max(-1, input[i])) * 0x7FFF;
      if (ws?.readyState === WebSocket.OPEN) ws.send(buffer.buffer);
    };
    sourceNode.connect(processorNode); processorNode.connect(recordCtx.destination);
  } catch (err) { console.error(err); }
};

const stopRecording = () => { 
  if (processorNode) { processorNode.disconnect(); processorNode = null; } 
  if (sourceNode) { sourceNode.disconnect(); sourceNode = null; } 
  if (recordCtx && recordCtx.state !== 'closed') { recordCtx.close(); recordCtx = null; } 
};

const playAudio = async (blob) => {
  try {
    if (!playCtx) playCtx = new (window.AudioContext || window.webkitAudioContext)({ sampleRate: 16000 });
    const arrayBuffer = await blob.arrayBuffer(); const int16 = new Int16Array(arrayBuffer); const float32 = new Float32Array(int16.length);
    for (let i = 0; i < int16.length; i++) float32[i] = int16[i] / 0x7FFF;
    const audioBuffer = playCtx.createBuffer(1, float32.length, 16000); audioBuffer.getChannelData(0).set(float32);
    const source = playCtx.createBufferSource(); source.buffer = audioBuffer; source.connect(playCtx.destination); source.start();
  } catch (e) {}
};

// --- ប្រព័ន្ធ Chat & ផ្ញើ File ---
const sendChat = () => { if (!typedText.value.trim()) return; ws.send(JSON.stringify({ action: "chat_message", text: typedText.value })); typedText.value = ""; };

const sendFile = (event) => {
  const file = event.target.files[0];
  if (!file) return;
  if (file.size > 5 * 1024 * 1024) { alert("File ត្រូវតែមានទំហំតូចជាង 5MB"); return; }

  const reader = new FileReader();
  reader.onload = () => {
    ws.send(JSON.stringify({
      action: "file_share",
      file_name: file.name,
      file_type: file.type,
      file_data: reader.result
    }));
  };
  reader.readAsDataURL(file);
};

const handleBeforeUnload = () => { closeConnection(); };
const closeConnection = () => { if (ws) ws.close(); stopCallAudio(); console.log("បិទ WebSocket រួចរាល់។"); };

defineExpose({ closeConnection });
onMounted(() => { connectWS(); window.addEventListener('beforeunload', handleBeforeUnload); });
onUnmounted(() => { closeConnection(); window.removeEventListener('beforeunload', handleBeforeUnload); });
</script>

<style scoped>
.ptt-dashboard { display: flex; max-width: 900px; margin: 30px auto; background: white; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.1); height: 530px; font-family: sans-serif; overflow: hidden; }
.panel-left { width: 45%; padding: 20px; border-right: 1px solid #eee; display: flex; flex-direction: column; align-items: center; justify-content: space-between; position: relative; }
.panel-right { width: 55%; padding: 20px; display: flex; flex-direction: column; background: #fafafa; }

.badge-online { background: #2ecc71; color: white; padding: 2px 8px; border-radius: 10px; font-weight: bold; font-size: 13px; }
.ptt-btn { width: 140px; height: 140px; border-radius: 50%; border: none; font-size: 13px; font-weight: bold; color: white; cursor: pointer; transition: 0.2s; box-shadow: 0 4px 10px rgba(0,0,0,0.15); }
.idle { background: #3498db; } .talking { background: #2ecc71; } .busy { background: #e74c3c; }

.call-section { width: 100%; text-align: left; margin: 10px 0; }
.call-section select { width: 70%; padding: 6px; border-radius: 4px; border: 1px solid #ccc; }
.btn-call { width: 25%; padding: 6px; background: #e67e22; color: white; border: none; border-radius: 4px; margin-left: 5px; cursor: pointer; font-weight: bold; }

/* ផ្ទាំងលោត Overlay Call */
.call-overlay { position: absolute; top:0; left:0; width:100%; height:100%; background: rgba(0,0,0,0.7); display:flex; align-items:center; justify-content:center; border-radius: 12px 0 0 12px; z-index: 99; }
.call-modal { background: white; padding: 20px; border-radius: 8px; text-align: center; box-shadow: 0 4px 10px rgba(0,0,0,0.3); width: 80%; }
.call-username { font-size: 18px; font-weight: bold; color: #2c3e50; margin: 10px 0; }
.call-actions { display: flex; gap: 10px; justify-content: center; margin-top: 15px; }
.btn-accept { background: #2ecc71; color: white; border: none; padding: 8px 15px; border-radius: 4px; cursor: pointer; font-weight: bold; }
.btn-reject { background: #e74c3c; color: white; border: none; padding: 8px 15px; border-radius: 4px; cursor: pointer; font-weight: bold; }

.logs-container { width: 100%; text-align: left; background: #fff; max-height: 100px; overflow-y: auto; border: 1px solid #ddd; border-radius: 6px; padding: 8px; }
.logs-container ul { list-style: none; padding: 0; margin: 0; }
.logs-container li { padding: 4px; margin-bottom: 2px; background: #f9f9f9; border-left: 3px solid #7f8c8d; color: #111; font-size: 11px; }

.chat-area { flex-grow: 1; background: white; border: 1px solid #ddd; border-radius: 6px; padding: 10px; overflow-y: auto; margin-bottom: 10px; display: flex; flex-direction: column; gap: 8px; }
.msg-line { display: flex; flex-direction: column; align-items: flex-start; max-width: 80%; }
.msg-me { align-self: flex-end; align-items: flex-end; }
.msg-user { font-size: 10px; color: #888; }
.msg-text { background: #eee; padding: 6px 10px; border-radius: 10px; font-size: 13px; margin: 0; color: #111; }
.msg-me .msg-text { background: #3498db; color: white; }

.preview-img { max-width: 140px; max-height: 140px; border-radius: 6px; margin-top: 4px; }
.download-link { background: #f1f2f6; color: #2f3542; padding: 6px 10px; border-radius: 6px; font-size: 12px; text-decoration: none; display: inline-block; border: 1px solid #ddd; margin-top: 4px; }

.chat-input { display: flex; gap: 5px; align-items: center; }
.chat-input input { flex-grow: 1; padding: 8px; border: 1px solid #ccc; border-radius: 4px; }
.file-btn { font-size: 20px; cursor: pointer; padding: 0 5px; user-select: none; }
.chat-input button { padding: 8px 15px; background: #2c3e50; color: white; border: none; border-radius: 4px; cursor: pointer; }
</style>