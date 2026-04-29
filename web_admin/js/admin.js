const API_BASE = 'https://srishty-backend.onrender.com/api/';
const token = localStorage.getItem('studio_access');

// Auth Check
if (!token) {
    window.location.href = '../web_client/index.html';
}

const adminApi = axios.create({
    baseURL: API_BASE,
    headers: { 'Authorization': `Bearer ${token}` }
});

// DOM Elements
const statUsers = document.getElementById('stat-total-users');
const statBooks = document.getElementById('stat-total-books');
const statCoins = document.getElementById('stat-total-coins');
const pendingGrid = document.getElementById('pending-grid');
const usersTable = document.getElementById('users-table-body');

// Navigation
const navDash = document.getElementById('nav-dash');
const navUsers = document.getElementById('nav-users');
const sectionOverview = document.getElementById('section-overview');
const sectionUsers = document.getElementById('section-users');

navDash.addEventListener('click', () => {
    navDash.classList.add('active');
    navUsers.classList.remove('active');
    sectionOverview.classList.remove('hidden');
    sectionUsers.classList.add('hidden');
});

navUsers.addEventListener('click', () => {
    navUsers.classList.add('active');
    navDash.classList.remove('active');
    sectionUsers.classList.remove('hidden');
    sectionOverview.classList.add('hidden');
    loadUsers();
});

async function initAdmin() {
    try {
        // Verify staff status
        const profileRes = await adminApi.get('accounts/profile/me/');
        if (!profileRes.data.is_staff) {
            // alert('Admin Access Required.');
            // window.location.href = '../web_client/dashboard.html';
        }

        // Fetch Global Stats
        const statsRes = await adminApi.get('core/books/'); // For demo using book list
        statBooks.textContent = statsRes.data.count || 0;
        
        loadPending();
    } catch (err) {
        console.error('Admin Init Error:', err);
    }
}

async function loadPending() {
    try {
        const res = await adminApi.get('core/books/?moderation_status=pending');
        const pending = res.data.results || [];
        
        if (pending.length === 0) {
            pendingGrid.innerHTML = '<div class="loading-placeholder">All stories moderated. Great job!</div>';
            return;
        }

        pendingGrid.innerHTML = pending.map(story => `
            <div class="glass-card story-card">
                <h4>${story.title}</h4>
                <p style="font-size: 12px; color: var(--text-dim);">By ${story.author_name}</p>
                <div style="margin-top: 15px; display: flex; gap: 10px;">
                    <button class="action-btn approve" onclick="approveStory(${story.id})">Approve</button>
                    <button class="action-btn delete" onclick="deleteStory(${story.id})">Delete</button>
                </div>
            </div>
        `).join('');
    } catch (err) {
        console.error('Pending load error:', err);
    }
}

async function loadUsers() {
    try {
        // Use standard profile list endpoint (if exists) or mock for now
        usersTable.innerHTML = '<tr><td colspan="5" style="text-align:center;">Loading users...</td></tr>';
        
        // This is a placeholder since we might need a dedicated admin user list endpoint
        // For now, showing the current user as an example
        const res = await adminApi.get('accounts/profile/me/');
        const u = res.data;
        usersTable.innerHTML = `
            <tr>
                <td>${u.username}</td>
                <td><span class="badge author">${u.role}</span></td>
                <td>Recently</td>
                <td>Active</td>
                <td><button class="action-btn">Edit</button></td>
            </tr>
        `;
    } catch (err) {
        console.error('User load error:', err);
    }
}

async function approveStory(id) {
    try {
        await adminApi.patch(`core/books/${id}/`, { moderation_status: 'published' });
        loadPending();
    } catch (err) {
        alert('Failed to approve story.');
    }
}

initAdmin();
