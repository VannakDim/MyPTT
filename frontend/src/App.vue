<template>
  <div id="app">
    <LoginCard v-if="!token" @login-success="onLoginSuccess" />

    <div v-else class="console-wrapper">
      <div class="header-bar">
        <span>អ្នកប្រើប្រាស់៖ <strong class="user-highlight">{{ username }}</strong></span>
        <button @click="handleLogout" class="logout-btn">ចាកចេញ</button>
      </div>
      
      <PttConsole :userToken="token" />
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import LoginCard from './components/LoginCard.vue';
import PttConsole from './components/PttConsole.vue';

// ទាញយកទិន្នន័យពី LocalStorage (បើមានស្រាប់)
const token = ref(localStorage.getItem('ptt_token') || '');
const username = ref(localStorage.getItem('ptt_username') || '');

// ទងចាប់ Event នៅពេល Login ជោគជ័យពី LoginCard.vue
const onLoginSuccess = (authData) => {
  token.value = authData.token;
  username.value = authData.username;
  
  localStorage.setItem('ptt_token', authData.token);
  localStorage.setItem('ptt_username', authData.username);
};

const handleLogout = () => {
  token.value = '';
  username.value = '';
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
  background: #2c3e50;
  color: white;
  padding: 15px 30px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  box-shadow: 0 2px 5px rgba(0,0,0,0.1);
}

.user-highlight {
  color: #3498db;
}

.logout-btn {
  background: #e74c3c;
  color: white;
  border: none;
  padding: 8px 15px;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
  transition: background 0.2s;
}
.logout-btn:hover { background: #c0392b; }
</style>