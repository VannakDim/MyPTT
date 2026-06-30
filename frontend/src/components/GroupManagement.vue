<template>
  <div class="group-management-card">
    <div class="card-header">
      <h3>📻 គ្រប់គ្រងប៉ុស្តិ៍វិទ្យុទាក់ទង (Group Management)</h3>
      <button @click="openCreateModal" class="btn-create">+ បង្កើតប៉ុស្តិ៍ថ្មី</button>
    </div>

    <!-- Search Bar -->
    <div class="search-box">
      <input 
        type="text" 
        v-model="searchQuery" 
        placeholder="🔍 ស្វែងរកប៉ុស្តិ៍តាម ឈ្មោះ ឬ កូដ..." 
        class="search-input"
      />
    </div>

    <!-- Groups Table -->
    <div class="table-container">
      <div v-if="loading" class="state-msg">កំពុងទាញយកទិន្នន័យ...</div>
      <div v-else-if="filteredGroups.length === 0" class="state-msg">គ្មានប៉ុស្តិ៍ទាក់ទងឡើយ។</div>
      <table v-else class="groups-table">
        <thead>
          <tr>
            <th>ឈ្មោះប៉ុស្តិ៍ (Display Name)</th>
            <th>កូដសម្គាល់ប៉ុស្តិ៍ (Identifier)</th>
            <th class="txt-center">ចំនួនសមាជិក</th>
            <th class="txt-center">សកម្មភាព</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="group in filteredGroups" :key="group.id">
            <td>
              <div class="group-name-col">
                <span class="group-icon">📻</span>
                <strong>{{ group.display_name }}</strong>
              </div>
            </td>
            <td>
              <span class="code-badge">{{ group.name }}</span>
            </td>
            <td class="txt-center">
              <span class="member-count">{{ group.users_count !== undefined ? group.users_count : 0 }} នាក់</span>
            </td>
            <td class="txt-center">
              <div class="action-buttons">
                <button @click="openEditModal(group)" class="btn-edit">✏️ កែប្រែ</button>
                <button @click="deleteGroup(group)" class="btn-delete">🗑️ លុប</button>
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
          <h4>{{ isEditMode ? '✏️ កែប្រែព័ត៌មានប៉ុស្តិ៍' : '📻 បង្កើតប៉ុស្តិ៍ថ្មី' }}</h4>
          <button @click="closeModal" class="btn-close-modal">✕</button>
        </div>
        <form @submit.prevent="saveGroup">
          <div class="modal-body">
            <div class="form-group">
              <label>ឈ្មោះបង្ហាញ (Display Name)</label>
              <input type="text" v-model="form.display_name" required placeholder="ឧទាហរណ៍៖ ប៉ុស្តិ៍សន្តិសុខ" />
            </div>

            <div class="form-group">
              <label>កូដសម្គាល់ (Identifier - អក្សរឡាតាំង គ្មានចន្លោះ)</label>
              <input type="text" v-model="form.name" required placeholder="ឧទាហរណ៍៖ security" :disabled="isEditMode" />
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

const groups = ref([]);
const loading = ref(false);
const saving = ref(false);
const searchQuery = ref('');
const error = ref('');

const showModal = ref(false);
const isEditMode = ref(false);
const editingGroupId = ref(null);

const form = ref({
  name: '',
  display_name: ''
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

const fetchGroups = async () => {
  loading.value = true;
  try {
    const response = await api.get('/api/all-groups');
    groups.value = response.data;
  } catch (err) {
    console.error("Failed fetching groups:", err);
  } finally {
    loading.value = false;
  }
};

const filteredGroups = computed(() => {
  if (!searchQuery.value.trim()) return groups.value;
  const query = searchQuery.value.toLowerCase();
  return groups.value.filter(g => 
    g.name.toLowerCase().includes(query) || 
    g.display_name.toLowerCase().includes(query)
  );
});

const openCreateModal = () => {
  isEditMode.value = false;
  editingGroupId.value = null;
  error.value = '';
  form.value = {
    name: '',
    display_name: ''
  };
  showModal.value = true;
};

const openEditModal = (group) => {
  isEditMode.value = true;
  editingGroupId.value = group.id;
  error.value = '';
  form.value = {
    name: group.name,
    display_name: group.display_name
  };
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const saveGroup = async () => {
  saving.value = true;
  error.value = '';
  
  // Client-side simple validation for name (slug-like)
  const nameRegex = /^[a-zA-Z0-9_-]+$/;
  if (!nameRegex.test(form.value.name)) {
    error.value = "កូដសម្គាល់អាចមានតែអក្សរឡាតាំង លេខ សញ្ញា (-) និង (_) ប៉ុណ្ណោះ គ្មានចន្លោះដកឃ្លាឡើយ។";
    saving.value = false;
    return;
  }

  try {
    if (isEditMode.value) {
      await api.put(`/api/groups/${editingGroupId.value}`, form.value);
    } else {
      await api.post('/api/groups', form.value);
    }
    await fetchGroups();
    showModal.value = false;
  } catch (err) {
    if (err.response && err.response.data && err.response.data.message) {
      error.value = err.response.data.message;
    } else if (err.response && err.response.data && err.response.data.errors) {
      const errs = err.response.data.errors;
      error.value = Object.values(errs).flat().join(', ');
    } else {
      error.value = "ប្រតិបត្តិការបរាជ័យ! សូមព្យាយាមម្ដងទៀត។";
    }
  } finally {
    saving.value = false;
  }
};

const deleteGroup = async (group) => {
  if (confirm(`តើអ្នកពិតជាចង់លុបប៉ុស្តិ៍ "${group.display_name}" នេះមែនទេ? សារ និងការភ្ជាប់ទាំងអស់នឹងត្រូវលុបចោល!`)) {
    try {
      await api.delete(`/api/groups/${group.id}`);
      await fetchGroups();
    } catch (err) {
      console.error("Failed deleting group:", err);
      alert(err.response?.data?.message || "មិនអាចលុបប៉ុស្តិ៍នេះបានទេ។");
    }
  }
};

onMounted(() => {
  fetchGroups();
});
</script>

<style scoped>
.group-management-card {
  width: 100%;
  max-width: 1024px;
  background: white;
  padding: 30px;
  border-radius: 8px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.05);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  border-bottom: 2px solid #edf2f7;
  padding-bottom: 15px;
}

.card-header h3 {
  margin: 0;
  color: #2d3748;
  font-size: 18px;
}

.btn-create {
  background: #2ecc71;
  color: white;
  border: none;
  padding: 8px 16px;
  border-radius: 5px;
  font-weight: bold;
  cursor: pointer;
  transition: background 0.2s;
}
.btn-create:hover {
  background: #27ae60;
}

.search-box {
  margin-bottom: 20px;
}

.search-input {
  width: 100%;
  padding: 12px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-size: 14px;
  outline: none;
  box-sizing: border-box;
}
.search-input:focus {
  border-color: #3182ce;
  box-shadow: 0 0 0 1px #3182ce;
}

.table-container {
  overflow-x: auto;
}

.state-msg {
  text-align: center;
  padding: 30px;
  color: #718096;
  font-style: italic;
}

.groups-table {
  width: 100%;
  border-collapse: collapse;
  text-align: left;
}

.groups-table th {
  background: #f7fafc;
  color: #4a5568;
  font-weight: 700;
  padding: 12px 15px;
  border-bottom: 2px solid #edf2f7;
  font-size: 13px;
}

.groups-table td {
  padding: 12px 15px;
  border-bottom: 1px solid #edf2f7;
  color: #2d3748;
  font-size: 14px;
}

.group-name-col {
  display: flex;
  align-items: center;
  gap: 10px;
}

.group-icon {
  font-size: 18px;
}

.code-badge {
  background: #edf2f7;
  color: #4a5568;
  padding: 3px 8px;
  border-radius: 4px;
  font-family: monospace;
  font-size: 12px;
  font-weight: bold;
}

.member-count {
  font-weight: bold;
  color: #3182ce;
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
  box-shadow: 0 10px 25 rgba(0,0,0,0.25);
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

@media (max-width: 1024px) {
  .group-management-card {
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
  .groups-table th, .groups-table td {
    padding: 8px 10px;
    font-size: 12px;
  }
  .action-buttons {
    flex-direction: column;
    gap: 4px;
  }
}
</style>
