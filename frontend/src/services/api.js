import axios from 'axios';

const API_URL = 'http://localhost:8000/api';

export const login = async (email, password) => {
    try {
        const response = await axios.post(`${API_URL}/login`, {
            email,
            password,
            device_name: 'WebDashboard'
        });
        return response.data; // នឹងទទួលបាន { status, user, token }
    } catch (error) {
        throw error.response ? error.response.data : new Error('Network Error');
    }
};