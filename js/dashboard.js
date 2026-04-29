const API_BASE = 'https://srishty-backend.onrender.com/api/';
const token = localStorage.getItem('studio_access');

// Auth Check
if (!token) {
    window.location.href = 'index.html';
}

// DOM Elements
const userNameGreet = document.getElementById('author-name-greet');
const userNamePill = document.getElementById('user-name');
const userAvatarInitial = document.getElementById('user-avatar-initial');
const storiesGrid = document.getElementById('stories-grid');
const logoutBtn = document.getElementById('logout-btn');

// Stats Elements
const statReads = document.getElementById('stat-reads');
const statLikes = document.getElementById('stat-likes');
const statFollowers = document.getElementById('stat-followers');
const statLevel = document.getElementById('stat-level');

// Axios Instance with Auth
const studioApi = axios.create({
    baseURL: API_BASE,
    headers: { 'Authorization': `Bearer ${token}` }
});

// Logout logic
logoutBtn.addEventListener('click', (e) => {
    e.preventDefault();
    localStorage.clear();
    window.location.href = 'index.html';
});

// Initialize Dashboard
async function initDashboard() {
    try {
        // 1. Fetch Profile
        const profileRes = await studioApi.get('accounts/profile/me/');
        const profile = profileRes.data;

        userNameGreet.textContent = profile.username;
        userNamePill.textContent = profile.username;
        userAvatarInitial.textContent = profile.username[0].toUpperCase();
        
        statFollowers.textContent = profile.followers_count || 0;
        statLevel.textContent = profile.level || 1;

        // 2. Fetch Stories
        const storiesRes = await studioApi.get('core/books/my_books/');
        const stories = storiesRes.data;
        
        renderStories(stories);
        calculateStats(stories);

    } catch (err) {
        console.error('Dashboard Init Error:', err);
        if (err.response?.status === 401) {
            localStorage.clear();
            window.location.href = 'index.html';
        }
    }
}

function renderStories(stories) {
    if (!stories || stories.length === 0) {
        storiesGrid.innerHTML = `
            <div class="loading-placeholder">
                <p>You haven't created any stories yet.</p>
                <button class="primary-btn" onclick="window.location.href='editor.html'" style="margin-top: 20px;">Start Your First Story</button>
            </div>
        `;
        return;
    }

    storiesGrid.innerHTML = stories.map(story => `
        <div class="glass-card story-card" onclick="window.location.href='editor.html?id=${story.id}'">
            <div class="story-cover-mini">
                ${story.cover ? `<img src="${story.cover}" alt="${story.title}">` : '<div style="width:100%; height:100%; background:rgba(255,255,255,0.1); display:flex; align-items:center; justify-content:center;">📚</div>'}
            </div>
            <h4>${story.title}</h4>
            <div class="story-meta">
                <span>${story.total_chapters || 0} Chapters</span> • 
                <span>${story.status || 'Draft'}</span>
            </div>
        </div>
    `).join('');
}

function calculateStats(stories) {
    let totalReads = 0;
    let totalLikes = 0;

    stories.forEach(story => {
        totalReads += story.total_reads || 0;
        totalLikes += story.likes_count || 0;
    });

    statReads.textContent = totalReads;
    statLikes.textContent = totalLikes;
}

initDashboard();
