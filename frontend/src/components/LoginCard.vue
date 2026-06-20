<template>
  <div class="login-wrapper">
    <div class="login-card">
      <h2>CamboCom Platform Login</h2>
      <p class="subtitle">សូមបញ្ចូលគណនីរបស់អ្នកដើម្បីភ្ជាប់ទៅកាន់ Voice Server</p>
      
      <form @submit.prevent="handleSubmit">
        <div class="form-group">
          <label>Email Address</label>
          <input 
            type="email" 
            v-model="email" 
            placeholder="example@realptt.com" 
            required
          />
        </div>
        
        <div class="form-group">
          <label>Password</label>
          <input 
            type="password" 
            v-model="password" 
            placeholder="••••••••" 
            required
          />
        </div>

        <p v-if="error" class="error-msg">⚠️ {{ error }}</p>
        
        <button type="submit" :disabled="loading" class="login-btn">
          {{ loading ? 'កំពុងផ្ទៀងផ្ទាត់...' : 'ចូលប្រើប្រាស់ប្រព័ន្ធ' }}
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import axios from 'axios';

// បង្កើត Event ដើម្បីប្រាប់ទៅ App.vue ពេល Login ជោគជ័យ
const emit = defineEmits(['login-success']);

const email = ref('');
const password = ref('');
const error = ref('');
const loading = ref(false);

const handleSubmit = async () => {
  loading.value = true;
  error.value = '';
  
  try {
    const response = await axios.post(`${import.meta.env.VITE_LARAVEL_API_URL}/api/login`, {
      email: email.value,
      password: password.value,
      device_name: 'WebDashboard'
    });

    if (response.data.status === 'success') {
      // ផ្ញើទិន្នន័យ Token, User, Email និង Role ទៅកាន់ App.vue
      emit('login-success', {
        token: response.data.token,
        username: response.data.user.name,
        email: response.data.user.email,
        role: response.data.user.role || 'user'
      });
    }
  } catch (err) {
    if (err.response && err.response.data.message) {
      error.value = err.response.data.message;
    } else {
      error.value = "មិនអាចភ្ជាប់ទៅកាន់ Laravel API ឡើយ! សូមពិនិត្យមើល Server។";
    }
  } finally {
    loading.value = false;
  }
};
</script>

<style scoped>
.login-wrapper {
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 90vh;
}
.login-card {
  background: white;
  padding: 40px;
  border-radius: 10px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  width: 100%;
  max-width: 400px;
}
.login-card h2 { margin-top: 0; color: #2c3e50; text-align: center; }
.subtitle { font-size: 14px; color: #7f8c8d; text-align: center; margin-bottom: 25px; }
.form-group { margin-bottom: 20px; }
.form-group label { display: block; margin-bottom: 8px; font-weight: 600; color: #34495e; }
.form-group input { width: 100%; padding: 10px; box-sizing: border-box; border: 1px solid #ccc; border-radius: 5px; font-size: 16px; }
.login-btn { width: 100%; padding: 12px; background: #3498db; color: white; border: none; border-radius: 5px; font-size: 16px; font-weight: bold; cursor: pointer; margin-top: 10px; }
.login-btn:hover { background: #2980b9; }
.login-btn:disabled { background: #bdc3c7; }
.error-msg { color: #e74c3c; font-size: 14px; font-weight: 500; }
</style>