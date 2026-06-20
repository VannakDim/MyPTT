<template>
  <div id="app">
    <LoginCard v-if="!token" @login-success="onLoginSuccess" />

    <div v-else class="console-wrapper">
      <div class="header-bar">
        <div class="header-container">
          <div class="brand">
            <span class="logo-icon">📻</span>
            <span class="logo-text">RealPTT Clone</span>
          </div>
          
          <!-- Navigation Tabs for Admin -->
          <div v-if="role === 'admin'" class="nav-tabs">
            <button 
              @click="currentTab = 'console'" 
              :class="['tab-btn', currentTab === 'console' ? 'active' : '']"
            >
              📻 ប៉ុស្តិ៍វិទ្យុទាក់ទង
            </button>
            <button 
              @click="currentTab = 'users'" 
              :class="['tab-btn', currentTab === 'users' ? 'active' : '']"
            >
              👥 គ្រប់គ្រងអ្នកប្រើប្រាស់
            </button>
          </div>

          <!-- User Clickable Profile Avatar Dropdown -->
          <div class="user-actions">
            <div class="profile-dropdown-container">
              <div @click="toggleDropdown" class="avatar-circle" :style="getAvatarStyle(avatar)" title="គណនីរបស់អ្នក">
                <img v-if="parsedAvatar.type === 'image'" :src="parsedAvatar.value" class="avatar-img" />
                <span v-else-if="parsedAvatar.type === 'emoji'">{{ parsedAvatar.value }}</span>
                <span v-else>{{ parsedAvatar.value }}</span>
              </div>
              
              <div v-if="showDropdown" class="dropdown-menu">
                <div class="dropdown-header">
                  <strong>{{ username }}</strong>
                  <span class="dropdown-role" :class="role">{{ role }}</span>
                </div>
                <div class="dropdown-divider"></div>
                <button @click="openProfileModal" class="dropdown-item">✏️ កែប្រែព័ត៌មាន</button>
                <button @click="handleLogout" class="dropdown-item danger">🚪 ចាកចេញ</button>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <div class="content-body">
        <PttConsole v-if="currentTab === 'console'" :userToken="token" />
        <UserManagement v-else-if="currentTab === 'users' && role === 'admin'" :userToken="token" />
      </div>
    </div>

    <!-- Personal Profile Edit Modal -->
    <div v-if="showProfileModal" class="modal-overlay">
      <div class="modal-content">
        <div class="modal-header">
          <h4>✏️ កែប្រែព័ត៌មានផ្ទាល់ខ្លួន</h4>
          <button @click="closeProfileModal" class="btn-close-modal">✕</button>
        </div>
        <form @submit.prevent="saveProfile">
          <div class="modal-body" style="max-height: 65vh; overflow-y: auto;">
            <div class="form-group">
              <label>ឈ្មោះ</label>
              <input type="text" v-model="profileForm.name" required placeholder="ឈ្មោះរបស់អ្នក" />
            </div>

            <div class="form-group">
              <label>អ៊ីមែល</label>
              <input type="email" v-model="profileForm.email" required placeholder="អ៊ីមែលរបស់អ្នក" />
            </div>

            <div class="form-group">
              <label>Password ថ្មី (ទុកទទេរ បើមិនចង់ប្តូរ)</label>
              <input type="password" v-model="profileForm.password" placeholder="••••••••" />
            </div>

            <!-- Avatar Custom Picker -->
            <div class="form-group">
              <label>រូបសញ្ញាគណនី (Avatar)</label>
              <div class="avatar-picker-tabs">
                <button type="button" @click="pickerTab = 'emoji'" :class="{ active: pickerTab === 'emoji' }">🤩 Emoji</button>
                <button type="button" @click="pickerTab = 'image'" :class="{ active: pickerTab === 'image' }">🖼️ បង្ហោះរូបភាព</button>
              </div>

              <!-- Emoji and Background Color Picker -->
              <div v-if="pickerTab === 'emoji'" class="emoji-picker-container">
                <div class="avatar-preview-box">
                  <div class="avatar-circle-preview" :style="{ backgroundColor: profileForm.avatarBg }">
                    <span class="preview-emoji">{{ profileForm.avatarEmoji }}</span>
                  </div>
                </div>
                
                <div class="picker-section">
                  <label class="sub-label">ជ្រើសរើស Emoji៖</label>
                  <div class="presets-grid">
                    <span 
                      v-for="em in presetEmojis" 
                      :key="em" 
                      @click="profileForm.avatarEmoji = em"
                      :class="{ selected: profileForm.avatarEmoji === em }"
                      class="emoji-item"
                    >
                      {{ em }}
                    </span>
                  </div>
                </div>

                <div class="picker-section">
                  <label class="sub-label">ជ្រើសរើសពណ៌ផ្ទៃខាងក្រោយ៖</label>
                  <div class="presets-grid colors">
                    <span 
                      v-for="col in presetColors" 
                      :key="col" 
                      @click="profileForm.avatarBg = col"
                      :class="{ selected: profileForm.avatarBg === col }"
                      :style="{ backgroundColor: col }"
                      class="color-item"
                    ></span>
                  </div>
                </div>
              </div>

              <!-- Image Uploader -->
              <div v-if="pickerTab === 'image'" class="image-picker-container">
                <div class="avatar-preview-box">
                  <div class="avatar-circle-preview">
                    <img v-if="profileForm.avatarImage" :src="profileForm.avatarImage" class="avatar-img" />
                    <span v-else class="preview-initial">{{ profileForm.name.charAt(0).toUpperCase() }}</span>
                  </div>
                </div>
                
                <div class="upload-controls">
                  <input type="file" ref="fileInput" @change="onAvatarFileChange" accept="image/*" class="file-input-hidden" id="avatar-upload-file" />
                  <label for="avatar-upload-file" class="btn-upload-file">📁 ជ្រើសរើសរូបភាព</label>
                  <button type="button" v-if="profileForm.avatarImage" @click="profileForm.avatarImage = ''" class="btn-remove-image">លុបរូបភាព</button>
                </div>
              </div>
            </div>
            
            <p v-if="profileError" class="error-msg">⚠️ {{ profileError }}</p>
          </div>
          
          <div class="modal-footer">
            <button type="button" @click="closeProfileModal" class="btn-cancel">បោះបង់</button>
            <button type="submit" :disabled="profileSaving" class="btn-submit">
              {{ profileSaving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import axios from 'axios';
import LoginCard from './components/LoginCard.vue';
import PttConsole from './components/PttConsole.vue';
import UserManagement from './components/UserManagement.vue';

// ទាញយកទិន្នន័យពី LocalStorage (បើមានស្រាប់)
const token = ref(localStorage.getItem('ptt_token') || '');
const username = ref(localStorage.getItem('ptt_username') || '');
const email = ref(localStorage.getItem('ptt_email') || '');
const role = ref(localStorage.getItem('ptt_role') || 'user');
const avatar = ref(localStorage.getItem('ptt_avatar') || '');
const currentTab = ref('console');

// Dropdown & Profile Modal State
const showDropdown = ref(false);
const showProfileModal = ref(false);
const profileSaving = ref(false);
const profileError = ref('');
const pickerTab = ref('emoji');

const presetEmojis = ['👨‍✈️', '👩‍✈️', '👮', '🕵️', '👷', '🧑‍⚕️', '🧑‍💻', '🦊', '🦁', '🐯', '🐼', '🐨', '🚀', '🔥', '💎', '🎯'];
const presetColors = ['#3498db', '#2ecc71', '#e67e22', '#e74c3c', '#9b59b6', '#1abc9c', '#f1c40f', '#34495e', '#7f8c8d'];

const profileForm = ref({
  name: '',
  email: '',
  password: '',
  avatarEmoji: '🦊',
  avatarBg: '#3498db',
  avatarImage: ''
});

// Helper: Parse avatar JSON string
const parseAvatar = (avatarStr) => {
  if (!avatarStr) return { type: 'initial', value: username.value ? username.value.charAt(0).toUpperCase() : 'U' };
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

const parsedAvatar = computed(() => {
  return parseAvatar(avatar.value);
});

// Dynamic avatar style generator (e.g. background color for emojis or fallback)
const getAvatarStyle = (avatarStr) => {
  const parsed = parseAvatar(avatarStr);
  if (parsed.type === 'emoji' && parsed.bg) {
    return { backgroundColor: parsed.bg };
  }
  if (parsed.type === 'initial') {
    const colors = ['#3498db', '#2ecc71', '#9b59b6', '#e74c3c', '#f1c40f', '#1abc9c', '#e67e22'];
    let hash = 0;
    const name = username.value || 'User';
    for (let i = 0; i < name.length; i++) {
      hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    const color = colors[Math.abs(hash) % colors.length];
    return { backgroundColor: color };
  }
  return {};
};

const toggleDropdown = () => {
  showDropdown.value = !showDropdown.value;
};

// Close dropdown when clicking outside
const closeDropdownOnOutsideClick = (event) => {
  const container = document.querySelector('.profile-dropdown-container');
  if (container && !container.contains(event.target)) {
    showDropdown.value = false;
  }
};

onMounted(() => {
  window.addEventListener('click', closeDropdownOnOutsideClick);
});

onUnmounted(() => {
  window.removeEventListener('click', closeDropdownOnOutsideClick);
});

const openProfileModal = () => {
  showDropdown.value = false;
  profileError.value = '';
  
  const parsed = parseAvatar(avatar.value);
  profileForm.value = {
    name: username.value,
    email: email.value,
    password: '',
    avatarEmoji: parsed.type === 'emoji' ? parsed.value : '🦊',
    avatarBg: parsed.type === 'emoji' ? parsed.bg : '#3498db',
    avatarImage: parsed.type === 'image' ? parsed.value : ''
  };
  
  pickerTab.value = parsed.type === 'image' ? 'image' : 'emoji';
  showProfileModal.value = true;
};

const closeProfileModal = () => {
  showProfileModal.value = false;
};

const onAvatarFileChange = (e) => {
  const file = e.target.files[0];
  if (!file) return;
  
  if (file.size > 2 * 1024 * 1024) {
    alert("⚠️ ទំហំរូបភាពត្រូវតែតូចជាង 2MB!");
    return;
  }

  const reader = new FileReader();
  reader.onload = (event) => {
    profileForm.value.avatarImage = event.target.result;
  };
  reader.readAsDataURL(file);
};

const saveProfile = async () => {
  profileSaving.value = true;
  profileError.value = '';
  
  try {
    let avatarJson = '';
    if (pickerTab.value === 'image' && profileForm.value.avatarImage) {
      avatarJson = JSON.stringify({ type: 'image', value: profileForm.value.avatarImage });
    } else if (pickerTab.value === 'emoji') {
      avatarJson = JSON.stringify({
        type: 'emoji',
        value: profileForm.value.avatarEmoji,
        bg: profileForm.value.avatarBg
      });
    }

    const payload = {
      name: profileForm.value.name,
      email: profileForm.value.email,
      avatar: avatarJson
    };

    if (profileForm.value.password) {
      payload.password = profileForm.value.password;
    }

    const response = await axios.put(`${import.meta.env.VITE_LARAVEL_API_URL}/api/profile`, payload, {
      headers: {
        'Authorization': `Bearer ${token.value}`,
        'Accept': 'application/json'
      }
    });

    if (response.data.status === 'success') {
      username.value = response.data.user.name;
      email.value = response.data.user.email;
      avatar.value = response.data.user.avatar || '';
      
      localStorage.setItem('ptt_username', response.data.user.name);
      localStorage.setItem('ptt_email', response.data.user.email);
      localStorage.setItem('ptt_avatar', response.data.user.avatar || '');
      
      closeProfileModal();
      alert("✅ រក្សាទុកព័ត៌មានផ្ទាល់ខ្លួនដោយជោគជ័យ!");
    }
  } catch (err) {
    if (err.response && err.response.data.message) {
      profileError.value = err.response.data.message;
    } else {
      profileError.value = "មិនអាចរក្សាទុកព័ត៌មានបានឡើយ! សូមព្យាយាមម្តងទៀត។";
    }
  } finally {
    profileSaving.value = false;
  }
};

// ទងចាប់ Event នៅពេល Login ជោគជ័យពី LoginCard.vue
const onLoginSuccess = (authData) => {
  token.value = authData.token;
  username.value = authData.username;
  email.value = authData.email;
  role.value = authData.role;
  avatar.value = authData.avatar || '';
  currentTab.value = 'console';
  
  localStorage.setItem('ptt_token', authData.token);
  localStorage.setItem('ptt_username', authData.username);
  localStorage.setItem('ptt_email', authData.email);
  localStorage.setItem('ptt_role', authData.role);
  localStorage.setItem('ptt_avatar', authData.avatar || '');
};

const handleLogout = () => {
  token.value = '';
  username.value = '';
  email.value = '';
  role.value = 'user';
  avatar.value = '';
  currentTab.value = 'console';
  showDropdown.value = false;
  localStorage.clear();
};
</script>

<style>
body {
  margin: 0;
  padding: 0;
  background-color: #f0f2f5;
  font-family: 'Segoe UI', Roboto, sans-serif;
}

.header-bar {
  margin: 20px auto;
  max-width: 1024px;
  width: 100%;
  background: #2c3e50;
  color: white;
  padding: 10px 20px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.1);
  border-radius: 12px;
  box-sizing: border-box;
}

.header-container {
  width: 100%;
  max-width: 1024px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.brand {
  display: flex;
  align-items: center;
  gap: 8px;
}

.logo-icon {
  font-size: 24px;
}

.logo-text {
  font-size: 18px;
  font-weight: bold;
  letter-spacing: 0.5px;
}

.nav-tabs {
  display: flex;
  gap: 10px;
}

.tab-btn {
  background: rgba(255,255,255,0.1);
  color: #bdc3c7;
  border: none;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s ease;
}

.tab-btn:hover {
  background: rgba(255,255,255,0.2);
  color: white;
}

.tab-btn.active {
  background: #3498db;
  color: white;
  box-shadow: 0 2px 8px rgba(52, 152, 219, 0.4);
}

.user-actions {
  display: flex;
  align-items: center;
  gap: 20px;
}

/* Avatar and dropdown menu styling */
.profile-dropdown-container {
  position: relative;
}

.avatar-circle {
  width: 40px;
  height: 40px;
  background: #3498db;
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  box-shadow: 0 2px 5px rgba(0,0,0,0.2);
  transition: all 0.3s ease;
  user-select: none;
  overflow: hidden;
}

.avatar-circle .avatar-img {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
}

.avatar-circle:hover {
  transform: scale(1.05);
  box-shadow: 0 4px 8px rgba(52, 152, 219, 0.4);
}

.dropdown-menu {
  position: absolute;
  top: 50px;
  right: 0;
  background: white;
  min-width: 200px;
  border-radius: 8px;
  box-shadow: 0 4px 15px rgba(0,0,0,0.15);
  border: 1px solid #edf2f7;
  overflow: hidden;
  z-index: 100;
  animation: slideDown 0.2s ease-out;
}

@keyframes slideDown {
  from { opacity: 0; transform: translateY(-10px); }
  to { opacity: 1; transform: translateY(0); }
}

.dropdown-header {
  padding: 12px 16px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.dropdown-header strong {
  color: #2c3e50;
  font-size: 14px;
}

.dropdown-role {
  font-size: 10px;
  text-transform: uppercase;
  font-weight: bold;
  padding: 1px 6px;
  border-radius: 4px;
  width: max-content;
}
.dropdown-role.admin { background: #e74c3c; color: white; }
.dropdown-role.user { background: #7f8c8d; color: white; }

.dropdown-divider {
  height: 1px;
  background: #edf2f7;
}

.dropdown-item {
  width: 100%;
  background: none;
  border: none;
  padding: 12px 16px;
  text-align: left;
  font-size: 13px;
  font-weight: 600;
  color: #4a5568;
  cursor: pointer;
  transition: background 0.2s;
  display: flex;
  align-items: center;
}

.dropdown-item:hover {
  background: #f7fafc;
  color: #2b6cb0;
}

.dropdown-item.danger {
  color: #e74c3c;
}
.dropdown-item.danger:hover {
  background: #fff5f5;
  color: #c53030;
}

/* Avatar Custom Picker */
.avatar-picker-tabs {
  display: flex;
  gap: 10px;
  margin-bottom: 15px;
}
.avatar-picker-tabs button {
  flex: 1;
  padding: 8px;
  background: #edf2f7;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  font-size: 13px;
  font-weight: bold;
  cursor: pointer;
  color: #4a5568;
  transition: all 0.2s;
}
.avatar-picker-tabs button.active {
  background: #3498db;
  color: white;
  border-color: #3498db;
}

.avatar-preview-box {
  display: flex;
  justify-content: center;
  margin-bottom: 15px;
}

.avatar-circle-preview {
  width: 70px;
  height: 70px;
  border-radius: 50%;
  background: #3498db;
  color: white;
  border: 2px solid #cbd5e0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32px;
  overflow: hidden;
  box-shadow: 0 4px 10px rgba(0,0,0,0.1);
}
.avatar-circle-preview .avatar-img {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
}

.picker-section {
  margin-bottom: 15px;
}
.sub-label {
  font-size: 12px;
  color: #718096;
  margin-bottom: 5px;
  display: block;
}

.presets-grid {
  display: grid;
  grid-template-columns: repeat(8, 1fr);
  gap: 8px;
  background: #f7fafc;
  padding: 10px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
}
.emoji-item {
  font-size: 24px;
  text-align: center;
  cursor: pointer;
  padding: 4px;
  border-radius: 6px;
  transition: transform 0.1s;
  user-select: none;
}
.emoji-item:hover {
  transform: scale(1.2);
  background: #edf2f7;
}
.emoji-item.selected {
  background: #ebf8ff;
  border: 2px solid #3182ce;
  box-sizing: border-box;
}

.presets-grid.colors {
  grid-template-columns: repeat(9, 1fr);
}
.color-item {
  height: 25px;
  border-radius: 50%;
  cursor: pointer;
  transition: transform 0.1s;
  border: 2px solid transparent;
}
.color-item:hover {
  transform: scale(1.15);
}
.color-item.selected {
  border-color: #2d3748;
  box-shadow: 0 0 4px rgba(0,0,0,0.4);
}

.image-picker-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  background: #f7fafc;
  padding: 15px;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
}
.upload-controls {
  display: flex;
  gap: 10px;
  align-items: center;
}
.file-input-hidden {
  display: none;
}
.btn-upload-file {
  background: #3182ce;
  color: white;
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: bold;
  cursor: pointer;
  transition: background 0.2s;
}
.btn-upload-file:hover {
  background: #2b6cb0;
}
.btn-remove-image {
  background: #e53e3e;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: bold;
  cursor: pointer;
  transition: background 0.2s;
}
.btn-remove-image:hover {
  background: #c53030;
}

/* Modal overlay styling */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0,0,0,0.5);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 999;
}

.modal-content {
  background: white;
  width: 100%;
  max-width: 450px;
  border-radius: 8px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.25);
  overflow: hidden;
  color: #2d3748;
}

.modal-header {
  background: #2c3e50;
  color: white;
  padding: 15px 20px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h4 {
  margin: 0;
  font-size: 15px;
}

.btn-close-modal {
  background: transparent;
  color: white;
  border: none;
  font-size: 18px;
  cursor: pointer;
}

.modal-body {
  padding: 20px;
  text-align: left;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  font-weight: bold;
  margin-bottom: 6px;
  font-size: 13px;
  color: #4a5568;
}

.form-group input {
  width: 100%;
  padding: 10px;
  border: 1px solid #cbd5e0;
  border-radius: 5px;
  font-size: 14px;
  box-sizing: border-box;
  outline: none;
}
.form-group input:focus {
  border-color: #3498db;
}

.modal-footer {
  background: #f8f9fa;
  padding: 15px 20px;
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  border-top: 1px solid #e2e8f0;
}

.btn-cancel {
  background: #a0aec0;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  font-weight: bold;
  cursor: pointer;
}
.btn-cancel:hover { background: #718096; }

.btn-submit {
  background: #2ecc71;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 4px;
  font-weight: bold;
  cursor: pointer;
}
.btn-submit:hover { background: #27ae60; }
.btn-submit:disabled { background: #cbd5e0; }

.error-msg {
  color: #e74c3c;
  font-size: 13px;
  font-weight: bold;
  margin-top: 10px;
}

.content-body {
  padding: 0 0px 40px 0px;
  display: flex;
  justify-content: center;
}

@media (max-width: 768px) {
  .header-bar {
    padding: 15px;
    width: 100%;
    margin: 0 0 15px 0;
    border-radius: 0;
    box-shadow: none;
  }
  .header-container {
    flex-direction: column;
    gap: 15px;
    align-items: center;
    text-align: center;
  }
  .nav-tabs {
    width: 100%;
    justify-content: center;
  }
  .user-actions {
    flex-direction: column;
    gap: 10px;
    width: 100%;
    justify-content: center;
    align-items: center;
  }
  .content-body {
    padding: 0;
  }
}
</style>