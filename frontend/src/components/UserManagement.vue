<template>
  <div class="user-management-card">
    <div class="card-header">
      <h3>👥 គ្រប់គ្រងអ្នកប្រើប្រាស់ (User Management)</h3>
      <button @click="openCreateModal" class="btn-create">+ បង្កើតអ្នកប្រើប្រាស់ថ្មី</button>
    </div>

    <!-- Search Bar -->
    <div class="search-box">
      <input 
        type="text" 
        v-model="searchQuery" 
        placeholder="🔍 ស្វែងរកតាម ឈ្មោះ ឬ អ៊ីមែល..." 
        class="search-input"
      />
    </div>

    <!-- Users Table -->
    <div class="table-container">
      <div v-if="loading" class="state-msg">កំពុងទាញយកទិន្នន័យ...</div>
      <div v-else-if="filteredUsers.length === 0" class="state-msg">គ្មានអ្នកប្រើប្រាស់ឡើយ។</div>
      <table v-else class="users-table">
        <thead>
          <tr>
            <th>ឈ្មោះ</th>
            <th>អ៊ីមែល</th>
            <th>Role</th>
            <th>ប៉ុស្តិ៍វិទ្យុទាក់ទង (Groups)</th>
            <th class="txt-center">សកម្មភាព</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="user in filteredUsers" :key="user.id">
            <td>
              <div class="user-name-col">
                <div class="user-avatar" :style="getAvatarStyle(user.avatar, user.name)">
                  <img v-if="parseAvatar(user.avatar, user.name).type === 'image'" :src="parseAvatar(user.avatar, user.name).value" class="avatar-img" />
                  <span v-else-if="parseAvatar(user.avatar, user.name).type === 'emoji'">{{ parseAvatar(user.avatar, user.name).value }}</span>
                  <span v-else>{{ parseAvatar(user.avatar, user.name).value }}</span>
                </div>
                <strong>{{ user.name }}</strong>
              </div>
            </td>
            <td>{{ user.email }}</td>
            <td>
              <span class="role-badge" :class="user.role">{{ user.role }}</span>
            </td>
            <td>
              <div class="group-badges">
                <span 
                  v-for="group in user.groups" 
                  :key="group.id" 
                  class="group-badge"
                >
                  📻 {{ group.display_name }}
                </span>
                <span v-if="!user.groups || user.groups.length === 0" class="no-groups">គ្មានក្រុម</span>
              </div>
            </td>
            <td class="txt-center">
              <div class="action-buttons">
                <button @click="openEditModal(user)" class="btn-edit">✏️ កែប្រែ</button>
                <button @click="deleteUser(user)" class="btn-delete">🗑️ លុប</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Create/Edit Modal Dialog -->
    <div v-if="showModal" class="modal-overlay">
      <div class="modal-content">
        <div class="modal-header">
          <h4>{{ isEditMode ? '✏️ កែប្រែព័ត៌មានអ្នកប្រើប្រាស់' : '👥 បង្កើតអ្នកប្រើប្រាស់ថ្មី' }}</h4>
          <button @click="closeModal" class="btn-close-modal">✕</button>
        </div>
        <form @submit.prevent="saveUser">
          <div class="modal-body">
            <div class="form-group">
              <label>ឈ្មោះ</label>
              <input type="text" v-model="form.name" required placeholder="ឧទាហរណ៍៖ សុខ ជាតិ" />
            </div>

            <div class="form-group">
              <label>អ៊ីមែល</label>
              <input type="email" v-model="form.email" required placeholder="example@realptt.com" />
            </div>

            <div class="form-group">
              <label>Password {{ isEditMode ? '(ទុកទទេរ បើមិនចង់ប្តូរ)' : '' }}</label>
              <input type="password" v-model="form.password" :required="!isEditMode" placeholder="••••••••" />
            </div>

            <div class="form-group">
              <label>Role</label>
              <select v-model="form.role" class="select-role">
                <option value="user">User</option>
                <option value="admin">Admin</option>
              </select>
            </div>

            <div class="form-group">
              <label>ជ្រើសរើសប៉ុស្តិ៍វិទ្យុទាក់ទង (Groups)</label>
              <div class="groups-checkbox-list">
                <label v-for="group in availableGroups" :key="group.id" class="checkbox-label">
                  <input 
                    type="checkbox" 
                    :value="group.id" 
                    v-model="form.groups"
                  />
                  <span>📻 {{ group.display_name }} ({{ group.name }})</span>
                </label>
              </div>
            </div>
            
            <p v-if="error" class="error-msg">⚠️ {{ error }}</p>
          </div>
          
          <div class="modal-footer">
            <button type="button" @click="closeModal" class="btn-cancel">បោះបង់</button>
            <button type="submit" :disabled="saving" class="btn-submit">
              {{ saving ? 'កំពុងរក្សាទុក...' : 'រក្សាទុក' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import axios from 'axios';

const props = defineProps({
  userToken: { type: String, required: true }
});

// Helper: Parse avatar JSON string
const parseAvatar = (avatarStr, username) => {
  if (!avatarStr) return { type: 'initial', value: username ? username.charAt(0).toUpperCase() : 'U' };
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

const getAvatarStyle = (avatarStr, username) => {
  const parsed = parseAvatar(avatarStr, username);
  if (parsed.type === 'emoji' && parsed.bg) {
    return { backgroundColor: parsed.bg };
  }
  if (parsed.type === 'initial') {
    const colors = ['#3498db', '#2ecc71', '#9b59b6', '#e74c3c', '#f1c40f', '#1abc9c', '#e67e22'];
    let hash = 0;
    const name = username || 'User';
    for (let i = 0; i < name.length; i++) {
      hash = name.charCodeAt(i) + ((hash << 5) - hash);
    }
    const color = colors[Math.abs(hash) % colors.length];
    return { backgroundColor: color, color: 'white' };
  }
  return {};
};

const users = ref([]);
const availableGroups = ref([]);
const loading = ref(false);
const saving = ref(false);
const searchQuery = ref('');
const error = ref('');

const showModal = ref(false);
const isEditMode = ref(false);
const editingUserId = ref(null);

const form = ref({
  name: '',
  email: '',
  password: '',
  role: 'user',
  groups: []
});

// Configure Axios with Authorization Header
const api = axios.create({
  baseURL: import.meta.env.VITE_LARAVEL_API_URL,
  headers: {
    'Authorization': `Bearer ${props.userToken}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  }
});

const fetchUsers = async () => {
  loading.value = true;
  try {
    const response = await api.get('/api/users');
    users.value = response.data;
  } catch (err) {
    console.error("Failed fetching users:", err);
  } finally {
    loading.value = false;
  }
};

const fetchGroups = async () => {
  try {
    const response = await api.get('/api/all-groups');
    availableGroups.value = response.data;
  } catch (err) {
    console.error("Failed fetching groups:", err);
  }
};

const filteredUsers = computed(() => {
  if (!searchQuery.value.trim()) return users.value;
  const query = searchQuery.value.toLowerCase();
  return users.value.filter(u => 
    u.name.toLowerCase().includes(query) || 
    u.email.toLowerCase().includes(query)
  );
});

const openCreateModal = () => {
  isEditMode.value = false;
  editingUserId.value = null;
  error.value = '';
  form.value = {
    name: '',
    email: '',
    password: '',
    role: 'user',
    groups: []
  };
  showModal.value = true;
};

const openEditModal = (user) => {
  isEditMode.value = true;
  editingUserId.value = user.id;
  error.value = '';
  form.value = {
    name: user.name,
    email: user.email,
    password: '',
    role: user.role,
    groups: user.groups.map(g => g.id)
  };
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const saveUser = async () => {
  saving.value = true;
  error.value = '';
  
  try {
    if (isEditMode.value) {
      await api.put(`/api/users/${editingUserId.value}`, form.value);
    } else {
      await api.post('/api/users', form.value);
    }
    await fetchUsers();
    closeModal();
  } catch (err) {
    if (err.response && err.response.data.message) {
      error.value = err.response.data.message;
    } else {
      error.value = "ប្រតិបត្តិការមិនបានសម្រេចឡើយ! សូមព្យាយាមម្តងទៀត។";
    }
  } finally {
    saving.value = false;
  }
};

const deleteUser = async (user) => {
  if (confirm(`តើអ្នកពិតជាចង់លុបគណនី "${user.name}" មែនទេ?`)) {
    try {
      await api.delete(`/api/users/${user.id}`);
      await fetchUsers();
    } catch (err) {
      if (err.response && err.response.data.message) {
        alert(`⚠️ ${err.response.data.message}`);
      } else {
        alert("មិនអាចលុបគណនីនេះបានឡើយ!");
      }
    }
  }
};

onMounted(() => {
  fetchUsers();
  fetchGroups();
});
</script>

<style scoped>
.user-management-card {
  width: 100%;
  max-width: 1024px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.15);
  font-family: sans-serif;
  overflow: hidden;
  padding: 20px;
  box-sizing: border-box;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 2px solid #f0f2f5;
  padding-bottom: 15px;
  margin-bottom: 15px;
}

.card-header h3 {
  margin: 0;
  color: #2c3e50;
  font-size: 18px;
}

.btn-create {
  background: #2ecc71;
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 6px;
  font-weight: bold;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}
.btn-create:hover {
  background: #27ae60;
  transform: translateY(-1px);
}

.search-box {
  margin-bottom: 15px;
}

.search-input {
  width: 100%;
  padding: 12px;
  border: 1px solid #cbd5e0;
  border-radius: 6px;
  font-size: 14px;
  box-sizing: border-box;
  outline: none;
}
.search-input:focus {
  border-color: #3498db;
}

.table-container {
  overflow-x: auto;
  min-height: 200px;
}

.state-msg {
  text-align: center;
  padding: 40px;
  color: #7f8c8d;
  font-size: 16px;
}

.users-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
}

.users-table th {
  background: #f8f9fa;
  color: #7f8c8d;
  font-weight: 600;
  padding: 12px 15px;
  font-size: 13px;
  border-bottom: 1px solid #edf2f7;
}

.users-table td {
  padding: 12px 15px;
  border-bottom: 1px solid #edf2f7;
  font-size: 14px;
}

.user-name-col {
  display: flex;
  align-items: center;
  gap: 10px;
}

.user-avatar {
  width: 32px;
  height: 32px;
  background: #e2e8f0;
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  font-weight: bold;
  font-size: 14px;
  overflow: hidden;
}

.user-avatar .avatar-img {
  width: 100%;
  height: 100%;
  border-radius: 50%;
  object-fit: cover;
}

.role-badge {
  font-size: 11px;
  font-weight: bold;
  text-transform: uppercase;
  padding: 3px 8px;
  border-radius: 12px;
}
.role-badge.admin {
  background: #fde8e8;
  color: #e74c3c;
}
.role-badge.user {
  background: #edf2f7;
  color: #4a5568;
}

.group-badges {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.group-badge {
  background: #ebf8ff;
  color: #2b6cb0;
  border: 1px solid #bee3f8;
  font-size: 12px;
  padding: 3px 8px;
  border-radius: 4px;
}

.no-groups {
  color: #a0aec0;
  font-style: italic;
  font-size: 12px;
}

.txt-center {
  text-align: center;
}

.action-buttons {
  display: flex;
  gap: 8px;
  justify-content: center;
}

.btn-edit {
  background: #3498db;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: bold;
  cursor: pointer;
}
.btn-edit:hover { background: #2980b9; }

.btn-delete {
  background: #e74c3c;
  color: white;
  border: none;
  padding: 6px 12px;
  border-radius: 4px;
  font-size: 12px;
  font-weight: bold;
  cursor: pointer;
}
.btn-delete:hover { background: #c0392b; }

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
  max-width: 500px;
  border-radius: 8px;
  box-shadow: 0 10px 25px rgba(0,0,0,0.25);
  overflow: hidden;
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
  font-size: 16px;
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
  max-height: 400px;
  overflow-y: auto;
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

.form-group input, .select-role {
  width: 100%;
  padding: 10px;
  border: 1px solid #cbd5e0;
  border-radius: 5px;
  font-size: 14px;
  box-sizing: border-box;
  outline: none;
}
.form-group input:focus, .select-role:focus {
  border-color: #3498db;
}

.groups-checkbox-list {
  background: #f8f9fa;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  padding: 10px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  font-size: 13px;
  font-weight: 500 !important;
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

@media (max-width: 1024px) {
  .user-management-card {
    border-radius: 0;
    padding: 15px;
    box-shadow: none;
  }
  .card-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 10px;
  }
  .btn-create {
    width: 100%;
  }
  .users-table th, .users-table td {
    padding: 8px 10px;
    font-size: 12px;
  }
  .action-buttons {
    flex-direction: column;
    gap: 4px;
  }
}
</style>
