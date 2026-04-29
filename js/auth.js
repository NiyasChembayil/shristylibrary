const API_BASE = 'https://srishty-backend.onrender.com/api/';

// DOM Elements
const loginForm = document.getElementById('login-form');
const signupForm = document.getElementById('signup-form');
const tabLogin = document.getElementById('tab-login');
const tabSignup = document.getElementById('tab-signup');
const authMessage = document.getElementById('auth-message');

// Tab Switching
tabLogin.addEventListener('click', () => {
    tabLogin.classList.add('active');
    tabSignup.classList.remove('active');
    loginForm.classList.remove('hidden');
    signupForm.classList.add('hidden');
    authMessage.textContent = '';
});

tabSignup.addEventListener('click', () => {
    tabSignup.classList.add('active');
    tabLogin.classList.remove('active');
    signupForm.classList.remove('hidden');
    loginForm.classList.add('hidden');
    authMessage.textContent = '';
});

// Helper to show message
function showMessage(msg, isError = true) {
    authMessage.textContent = msg;
    authMessage.className = isError ? 'message error' : 'message success';
}

// Login Logic
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const username = document.getElementById('login-username').value;
    const password = document.getElementById('login-password').value;

    showMessage('Entering studio...', false);

    try {
        const response = await axios.post(`${API_BASE}token/`, { username, password });
        const { access, refresh } = response.data;

        // Save tokens
        localStorage.setItem('studio_access', access);
        localStorage.setItem('studio_refresh', refresh);

        // Fetch profile to verify role
        const profileRes = await axios.get(`${API_BASE}accounts/profile/me/`, {
            headers: { 'Authorization': `Bearer ${access}` }
        });

        if (profileRes.data.role !== 'author') {
            showMessage('Access Denied. Only Author accounts can enter the Studio.');
            localStorage.clear();
            return;
        }

        showMessage('Welcome back, Author!', false);
        setTimeout(() => {
            window.location.href = 'dashboard.html';
        }, 1000);

    } catch (err) {
        console.error(err);
        const errorMsg = err.response?.data?.detail || 'Login failed. Please check your credentials.';
        showMessage(errorMsg);
    }
});

// Signup Logic
signupForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const username = document.getElementById('signup-username').value;
    const email = document.getElementById('signup-email').value;
    const password = document.getElementById('signup-password').value;
    const role = 'author';

    showMessage('Creating your legacy...', false);

    try {
        await axios.post(`${API_BASE}accounts/auth/register/`, {
            username,
            email,
            password,
            role
        });

        showMessage('Account created! You can now login.', false);
        setTimeout(() => {
            tabLogin.click();
        }, 2000);

    } catch (err) {
        console.error(err);
        let errorMsg = 'Signup failed. Please try again.';
        if (err.response?.data) {
            const data = err.response.data;
            const firstKey = Object.keys(data)[0];
            errorMsg = Array.isArray(data[firstKey]) ? data[firstKey][0] : data[firstKey];
        }
        showMessage(errorMsg);
    }
});
