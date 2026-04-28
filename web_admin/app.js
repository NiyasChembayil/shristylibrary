const API_BASE_URL = window.location.origin.includes('localhost') ? 'http://127.0.0.1:8000/api' : 'https://srishty-backend.onrender.com/api';

function escapeHTML(str) {
    if (!str) return '';
    return String(str).replace(/[&<>"']/g, function (m) {
        return {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        }[m];
    });
}

class AdminApp {
    constructor() {
        this.token = localStorage.getItem('srishty_admin_token');
        this.user = JSON.parse(localStorage.getItem('srishty_admin_user'));
        this.currentView = 'dashboard';

        this.init();
    }

    init() {
        this.checkAuth();
        this.bindEvents();
        if (this.token) {
            this.loadDashboard();
        }
    }

    checkAuth() {
        if (!this.token) {
            document.getElementById('login-overlay').classList.remove('hidden');
            document.getElementById('app').classList.add('blurred');
        } else {
            document.getElementById('login-overlay').classList.add('hidden');
            document.getElementById('app').classList.remove('blurred');
            document.getElementById('admin-name').textContent = this.user.username;
        }
    }

    bindEvents() {
        // Login Form
        document.getElementById('login-form').addEventListener('submit', (e) => this.login(e));

        // Navigation
        const navItems = document.querySelectorAll('.nav-item');
        navItems.forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                const view = item.id.replace('nav-', '');
                this.switchView(view);

                // Update UI state
                navItems.forEach(nav => nav.classList.remove('active'));
                item.classList.add('active');
            });
        });

        // Theme Toggle
        document.getElementById('theme-toggle').addEventListener('click', () => this.toggleTheme());
    }

    toggleTheme() {
        const currentTheme = document.body.getAttribute('data-theme') || 'dark';
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        document.body.setAttribute('data-theme', newTheme);
        localStorage.setItem('srishty_admin_theme', newTheme);
    }

    showSuccess(msg = "Action Successful!") {
        const overlay = document.getElementById('success-overlay');
        const text = document.getElementById('success-msg');
        text.textContent = msg;
        overlay.classList.remove('hidden');
        setTimeout(() => {
            overlay.classList.add('hidden');
        }, 2000);
    }

    async login(e) {
        e.preventDefault();
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;

        try {
            const response = await fetch(`${API_BASE_URL}/token/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
            });

            if (response.ok) {
                const data = await response.json();
                this.token = data.access;

                // Validate if user is admin
                const profileRes = await this.fetchWithAuth(`${API_BASE_URL}/accounts/profile/me/`);
                if (profileRes.role !== 'admin') {
                    alert('Access denied: You do not have administrative privileges.');
                    this.logout();
                    return;
                }

                this.user = profileRes;
                localStorage.setItem('srishty_admin_token', this.token);
                localStorage.setItem('srishty_admin_user', JSON.stringify(this.user));

                this.checkAuth();
                this.loadDashboard();
            } else {
                alert('Authentication failed. Please check your credentials.');
            }
        } catch (error) {
            console.error('Login error:', error);
            alert('A connection error occurred.');
        }
    }

    logout() {
        localStorage.removeItem('srishty_admin_token');
        localStorage.removeItem('srishty_admin_user');
        window.location.reload();
    }

    async fetchWithAuth(url, options = {}) {
        const headers = {
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json',
            ...options.headers
        };

        const response = await fetch(url, { ...options, headers });
        if (response.status === 401) {
            this.logout();
            return;
        }
        return response.json();
    }

    switchView(view) {
        this.currentView = view;
        const container = document.getElementById('view-container');
        const title = document.getElementById('page-title');

        switch (view) {
            case 'dashboard':
                title.textContent = 'Dashboard Overview';
                this.loadDashboard();
                break;
            case 'users_verified':
                title.textContent = 'Verified Users';
                this.loadUsersView(true);
                break;
            case 'users_unverified':
                title.textContent = 'Unverified Users';
                this.loadUsersView(false);
                break;
            case 'books':
                title.textContent = 'Content Moderation';
                this.loadBooksView();
                break;
            case 'broadcast':
                title.textContent = 'Global System Broadcast';
                this.loadBroadcastView();
                break;
            case 'security':
                title.textContent = 'Platform Security Audit';
                this.loadSecurityView();
                break;
            case 'analytics':
                title.textContent = 'Platform Analytics';
                this.loadAnalyticsView();
                break;
            case 'settings':
                title.textContent = 'System Settings';
                this.loadSettingsView();
                break;
            case 'moderation':
                title.textContent = 'Content Moderation Hub';
                this.loadModerationView();
                break;
            case 'reports':
                title.textContent = 'User Report Management';
                this.loadReportsView();
                break;
            case 'finance':
                title.textContent = 'Financial Oversight';
                this.loadFinanceView();
                break;
            case 'support':
                title.textContent = 'Help & Support Tickets';
                this.loadSupportView();
                break;
            case 'banners':
                title.textContent = 'Banner & Promo Manager';
                this.loadBannersView();
                break;
            case 'emails':
                title.textContent = 'Email Communications';
                this.loadEmailsView();
                break;
            default:
                container.innerHTML = '<div class="glass section-card"><h3>Coming Soon</h3><p>This module is currently in development.</p></div>';
        }
    }

    async loadDashboard() {
        try {
            const stats = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/stats/`);
            const activity = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/recent_activity/`);

            // Update stats cards
            document.getElementById('count-users').textContent = stats.users.total.toLocaleString();
            document.getElementById('count-authors').textContent = stats.users.authors.toLocaleString();
            document.getElementById('count-books').textContent = stats.users.live.toLocaleString(); // Use live users here for the "Live" pulse
            document.querySelector('#nav-dashboard + .stat-card .stat-label').textContent = 'Live Readers'; // Adjust label
            document.getElementById('count-revenue').textContent = `$${stats.revenue.total.toFixed(2)}`;

            // Render recent books
            const list = document.getElementById('recent-books-list');
            list.innerHTML = activity.books.map(book => `
                <tr class="animate-slide-up">
                    <td>${escapeHTML(book.title)}</td>
                    <td>${escapeHTML(book.author)}</td>
                    <td>Fiction</td>
                    <td><span class="status-badge active">Published</span></td>
                    <td><button class="btn-action">Manage</button></td>
                </tr>
            `).join('');

        } catch (error) {
            console.error('Failed to load dashboard data:', error);
        }
    }

    async searchUsers(event, isVerified) {
        if (event.key === 'Enter' || event.target.value.length >= 3 || event.target.value.length === 0) {
            this.loadUsersView(isVerified, event.target.value);
        }
    }

    async loadUsersView(isVerified = null, searchQuery = '') {
        const titleText = isVerified === true ? 'Verified Platform Users' : (isVerified === false ? 'Unverified Platform Users' : 'Registered Platform Users');
        const container = document.getElementById('view-container');

        // If we already have the search bar, don't re-render the whole container to avoid losing focus
        let target = document.getElementById('users-list-target');
        if (!target) {
            container.innerHTML = `<div class="glass section-card animate-slide-up">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                    <h3 style="margin: 0;">${titleText}</h3>
                    <div class="search-box" style="position: relative;">
                        <input type="text" id="user-search-input" placeholder="Search by username..." 
                            style="padding: 10px 15px; border-radius: 20px; border: 1px solid rgba(255,255,255,0.1); background: rgba(0,0,0,0.2); color: white; width: 250px;"
                            onkeyup="adminApp.searchUsers(event, ${isVerified})"
                            value="${searchQuery}">
                        <span style="position: absolute; right: 15px; top: 10px; opacity: 0.5;">🔍</span>
                    </div>
                </div>
                <div class="table-container">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th style="width: 40px;"><input type="checkbox" onchange="adminApp.toggleAllUsers(this)"></th>
                                <th>User ID</th>
                                <th>Username</th>
                                <th>Role</th>
                                <th>Status</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody id="users-list-target">
                            <tr><td colspan="5">Loading user data...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>`;
            target = document.getElementById('users-list-target');
        }

        try {
            let url = `${API_BASE_URL}/accounts/profile/?`;
            if (isVerified !== null) url += `is_verified=${isVerified}&`;
            if (searchQuery) url += `search=${searchQuery}`;

            const data = await this.fetchWithAuth(url);

            let profiles = data.results || data;

            if (profiles.length === 0) {
                target.innerHTML = `<tr><td colspan="5">No users found.</td></tr>`;
                return;
            }

            target.innerHTML = profiles.map(profile => `
                <tr class="animate-slide-up" onclick="adminApp.showUserProfile(${profile.id})" style="cursor: pointer;">
                    <td onclick="event.stopPropagation()"><input type="checkbox" class="user-checkbox" value="${profile.id}"></td>
                    <td>#${profile.id}</td>
                    <td style="display: flex; align-items: center; gap: 10px;">
                        <img src="${profile.avatar || 'https://via.placeholder.com/30'}" style="width: 30px; height: 30px; border-radius: 50%;">
                        <span>${escapeHTML(profile.username)}</span>
                    </td>
                    <td><span class="status-badge" style="background: rgba(108, 99, 255, 0.1); color: var(--accent-primary);">${profile.role.toUpperCase()}</span></td>
                    <td>
                        <span class="status-badge ${profile.is_verified ? 'active' : (profile.verification_status === 'pending' ? 'pending' : '')}">
                            ${profile.is_verified ? 'Verified' : (profile.verification_status === 'pending' ? 'Review' : 'Standard')}
                        </span>
                    </td>
                    <td>
                        <button class="btn-action" onclick="event.stopPropagation(); adminApp.showUserProfile(${profile.id})">View History</button>
                    </td>
                </tr>
            `).join('');

            // Add Bulk Action bar if not present
            if (!document.getElementById('bulk-actions-bar')) {
                const actionBar = document.createElement('div');
                actionBar.id = 'bulk-actions-bar';
                actionBar.className = 'glass';
                actionBar.style = "margin-top: 20px; padding: 15px; border-radius: 15px; display: flex; gap: 15px; align-items: center;";
                actionBar.innerHTML = `
                    <span style="font-size: 13px; opacity: 0.7;">Bulk Actions:</span>
                    <button class="btn-action green" onclick="adminApp.bulkVerifyUsers()">Verify Selected</button>
                `;
                target.parentElement.parentElement.appendChild(actionBar);
            }
        } catch (e) {
            console.error(e);
            if (target) target.innerHTML = `<tr><td colspan="5">Error loading users.</td></tr>`;
        }
    }

    async toggleVerify(id, currentStatus) {
        if (!confirm(`Are you sure you want to ${currentStatus ? 'remove verification from' : 'verify'} this user?`)) return;
        try {
            const response = await fetch(`${API_BASE_URL}/accounts/profile/${id}/toggle_verify/`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${this.token}`,
                    'Content-Type': 'application/json'
                }
            });
            if (response.ok) {
                this.loadUsersView(this.currentView === 'users_verified' ? true : (this.currentView === 'users_unverified' ? false : null));
            } else {
                alert('Failed to update verification status.');
            }
        } catch (e) {
            console.error('Toggle verify error:', e);
            alert('A connection error occurred.');
        }
    }

    async loadBooksView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `<div class="glass section-card animate-slide-up">
            <h3>Book Catalog & Moderation</h3>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Book ID</th>
                            <th>Title</th>
                            <th>Author</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody id="books-list-target">
                        <tr><td colspan="5">Loading book data...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>`;

        try {
            const data = await this.fetchWithAuth(`${API_BASE_URL}/core/books/`);
            const target = document.getElementById('books-list-target');
            target.innerHTML = data.results.map(book => `
                <tr>
                    <td>#${book.id}</td>
                    <td>${escapeHTML(book.title)}</td>
                    <td>${escapeHTML(book.author_name)}</td>
                    <td><span class="status-badge active">Live</span></td>
                    <td>
                        <button class="btn-action blue" onclick="adminApp.loadDropOffView(${book.id}, '${escapeHTML(book.title)}')">📈 Drop-off</button>
                        <button class="btn-action red">Remove</button>
                    </td>
                </tr>
            `).join('');
        } catch (e) {
            console.error(e);
        }
    }
    async loadAnalyticsView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `
            <div class="chart-grid">
                <div class="glass section-card animate-slide-up">
                    <h3>24-Hour Activity Heatmap</h3>
                    <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 15px;">Peak platform usage times (last 7 days)</p>
                    <div class="chart-container" style="height: 300px;">
                        <canvas id="heatmapChart"></canvas>
                    </div>
                </div>
                <div class="glass section-card animate-slide-up" style="animation-delay: 0.1s">
                    <h3>Regional Performance</h3>
                    <div class="chart-container" style="height: 300px;">
                        <canvas id="regionChart"></canvas>
                    </div>
                </div>
            </div>
            <div class="chart-grid" style="margin-top: 24px;">
                <div class="glass section-card animate-slide-up" style="animation-delay: 0.2s">
                    <h3>Category Popularity</h3>
                    <div class="chart-container" style="height: 300px;">
                        <canvas id="categoryChart"></canvas>
                    </div>
                </div>
                <div class="glass section-card animate-slide-up" style="animation-delay: 0.3s">
                    <h3>User Distribution</h3>
                    <div class="chart-container" style="height: 300px;">
                        <canvas id="userChart"></canvas>
                    </div>
                </div>
            </div>
        `;

        try {
            const stats = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/stats/`);

            // 1. Heatmap Chart
            const ctxHeat = document.getElementById('heatmapChart').getContext('2d');
            new Chart(ctxHeat, {
                type: 'bar',
                data: {
                    labels: Object.keys(stats.heatmap).map(h => `${h}:00`),
                    datasets: [{
                        label: 'Active Reads',
                        data: Object.values(stats.heatmap),
                        backgroundColor: 'rgba(108, 99, 255, 0.6)',
                        borderColor: '#6C63FF',
                        borderWidth: 1,
                        borderRadius: 4
                    }]
                },
                options: this.getChartOptions()
            });

            // 2. Region Chart
            const ctxRegion = document.getElementById('regionChart').getContext('2d');
            new Chart(ctxRegion, {
                type: 'bar',
                data: {
                    labels: stats.breakdowns.regions.map(r => r.region),
                    datasets: [{
                        label: 'Total Reads by Region',
                        data: stats.breakdowns.regions.map(r => r.total_reads),
                        backgroundColor: '#00D2FF'
                    }]
                },
                options: this.getChartOptions(true)
            });

            // 3. Category Chart
            const ctxCat = document.getElementById('categoryChart').getContext('2d');
            new Chart(ctxCat, {
                type: 'doughnut',
                data: {
                    labels: stats.breakdowns.categories.map(c => c.name),
                    datasets: [{
                        data: stats.breakdowns.categories.map(c => c.total_reads),
                        backgroundColor: ['#6C63FF', '#00D2FF', '#FF6584', '#FFD700', '#4CAF50'],
                        borderWidth: 0
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'bottom', labels: { color: '#fff' } } }
                }
            });

            // 4. User Distribution
            const ctxUser = document.getElementById('userChart').getContext('2d');
            new Chart(ctxUser, {
                type: 'pie',
                data: {
                    labels: ['Readers', 'Authors'],
                    datasets: [{
                        data: [stats.users.readers, stats.users.authors],
                        backgroundColor: ['#6C63FF', '#00D2FF'],
                        borderWidth: 0
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: { legend: { position: 'bottom', labels: { color: '#fff' } } }
                }
            });

        } catch (e) {
            console.error('Failed to load analytics:', e);
        }
    }

    getChartOptions(horizontal = false) {
        return {
            indexAxis: horizontal ? 'y' : 'x',
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false }, tooltip: { backgroundColor: '#1E1E2E' } },
            scales: {
                y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: 'rgba(255,255,255,0.5)' } },
                x: { grid: { display: false }, ticks: { color: 'rgba(255,255,255,0.5)' } }
            }
        };
    }

    loadSettingsView() {
        const container = document.getElementById('view-container');

        // Load mock settings from local storage or set defaults
        const settings = JSON.parse(localStorage.getItem('srishty_settings')) || {
            platformName: 'Srishty',
            maintenanceMode: false,
            allowNewRegistrations: true,
            authorCommission: '70'
        };

        container.innerHTML = `
            <div class="glass section-card animate-slide-up" style="max-width: 800px;">
                <h3>Platform Configuration</h3>
                <form id="settings-form">
                    
                    <div class="settings-group">
                        <h4>General Options</h4>
                        <div class="form-group">
                            <label>Platform Name</label>
                            <input type="text" id="set-name" value="${settings.platformName}" required>
                        </div>
                        <div class="form-group">
                            <label>Author Commission Rate (%)</label>
                            <input type="number" id="set-commission" min="10" max="90" value="${settings.authorCommission}" required>
                        </div>
                    </div>

                    <div class="settings-group">
                        <h4>System State</h4>
                        
                        <div class="toggle-row">
                            <div class="toggle-info">
                                <span>Maintenance Mode</span>
                                <small>Disables public access and displays an under-maintenance screen.</small>
                            </div>
                            <label class="switch">
                                <input type="checkbox" id="set-maintenance" ${settings.maintenanceMode ? 'checked' : ''}>
                                <span class="slider"></span>
                            </label>
                        </div>

                        <div class="toggle-row" style="margin-top: 15px;">
                            <div class="toggle-info">
                                <span>Allow New Registrations</span>
                                <small>Toggle whether new users can create accounts.</small>
                            </div>
                            <label class="switch">
                                <input type="checkbox" id="set-register" ${settings.allowNewRegistrations ? 'checked' : ''}>
                                <span class="slider"></span>
                            </label>
                        </div>
                    </div>

                    <button type="submit" class="btn-save">Save Settings</button>
                </form>
            </div>
        `;

        // Handle settings save
        document.getElementById('settings-form').addEventListener('submit', (e) => {
            e.preventDefault();
            const newSettings = {
                platformName: document.getElementById('set-name').value,
                authorCommission: document.getElementById('set-commission').value,
                maintenanceMode: document.getElementById('set-maintenance').checked,
                allowNewRegistrations: document.getElementById('set-register').checked,
            };

            localStorage.setItem('srishty_settings', JSON.stringify(newSettings));
            alert('Settings successfully saved!');
        });
    }

    async loadModerationView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `<div class="glass section-card animate-slide-up">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h3 style="margin: 0;">Pending Approval Queue</h3>
                <span class="status-badge" style="background: rgba(255,165,0,0.2); color: orange;">Review Required</span>
            </div>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Book Title</th>
                            <th>Author</th>
                            <th>Submitted</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="moderation-list-target">
                        <tr><td colspan="5">Loading pending books...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>`;

        try {
            const data = await this.fetchWithAuth(`${API_BASE_URL}/core/books/?moderation_status=pending`);
            const target = document.getElementById('moderation-list-target');
            const books = data.results || data;

            if (books.length === 0) {
                target.innerHTML = `<tr><td colspan="5">No books pending approval. ☕</td></tr>`;
                return;
            }

            target.innerHTML = books.map(book => `
                <tr>
                    <td>#${book.id}</td>
                    <td><strong>${escapeHTML(book.title)}</strong></td>
                    <td>${escapeHTML(book.author_name)}</td>
                    <td>${new Date(book.created_at).toLocaleDateString()}</td>
                    <td>
                        <button class="btn-action blue" onclick="adminApp.previewBook(${book.id})">Preview</button>
                        <button class="btn-action green" onclick="adminApp.approveBook(${book.id})">Approve</button>
                        <button class="btn-action red" onclick="adminApp.rejectBook(${book.id})">Reject</button>
                    </td>
                </tr>
            `).join('');
        } catch (e) {
            console.error(e);
        }
    }

    async approveBook(id) {
        if (!confirm('Approve this book for public discovery?')) return;
        try {
            await this.fetchWithAuth(`${API_BASE_URL}/core/books/${id}/approve/`, { method: 'POST' });
            this.showSuccess('Book Approved!');
            this.loadModerationView();
        } catch (e) { alert('Action failed'); }
    }

    async rejectBook(id) {
        const notes = prompt('Enter reason for rejection:');
        if (notes === null) return;
        try {
            await this.fetchWithAuth(`${API_BASE_URL}/core/books/${id}/reject/`, { 
                method: 'POST',
                body: JSON.stringify({ notes })
            });
            this.showSuccess('Book Rejected');
            this.loadModerationView();
        } catch (e) { alert('Action failed'); }
    }

    async previewBook(id) {
        const modal = document.getElementById('user-modal');
        const content = document.getElementById('user-modal-content');
        modal.style.display = 'flex';
        content.innerHTML = '<p>Loading preview...</p>';

        try {
            const book = await this.fetchWithAuth(`${API_BASE_URL}/core/books/${id}/`);
            content.innerHTML = `
                <div class="book-preview-content">
                    <div style="display: flex; gap: 20px; margin-bottom: 20px;">
                        <img src="${book.cover || ''}" style="width: 150px; border-radius: 10px;">
                        <div>
                            <h2>${escapeHTML(book.title)}</h2>
                            <p><strong>Category:</strong> ${book.category_name}</p>
                            <p><strong>Description:</strong> ${escapeHTML(book.description)}</p>
                        </div>
                    </div>
                    <div style="max-height: 400px; overflow-y: auto; background: rgba(0,0,0,0.2); padding: 20px; border-radius: 10px;">
                        <h4>Sample Content (Chapter 1)</h4>
                        <div id="sample-content">Loading...</div>
                    </div>
                    <div style="margin-top: 20px; text-align: right;">
                        <button class="btn-action" onclick="document.getElementById('user-modal').style.display='none'">Close Preview</button>
                    </div>
                </div>
            `;
            
            // Load first chapter if exists
            if (book.chapters && book.chapters.length > 0) {
                const chapter = await this.fetchWithAuth(`${API_BASE_URL}/core/chapters/${book.chapters[0].id}/`);
                document.getElementById('sample-content').innerHTML = chapter.content || 'No content in this chapter.';
            } else {
                document.getElementById('sample-content').textContent = 'No chapters uploaded yet.';
            }

        } catch (e) {
            content.innerHTML = '<p>Error loading preview.</p>';
        }
    }

    async loadReportsView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `<div class="glass section-card animate-slide-up">
            <h3>Community Reports</h3>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Type</th>
                            <th>Target</th>
                            <th>Reporter</th>
                            <th>Reason</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody id="reports-list-target">
                        <tr><td colspan="6">Loading reports...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>`;

        try {
            const data = await this.fetchWithAuth(`${API_BASE_URL}/core/reports/`);
            const target = document.getElementById('reports-list-target');
            const reports = data.results || data;

            if (reports.length === 0) {
                target.innerHTML = `<tr><td colspan="6">No reports found. Clean platform! ✨</td></tr>`;
                return;
            }

            target.innerHTML = reports.map(r => `
                <tr>
                    <td>${r.target_book ? '📖 Book' : '👤 User'}</td>
                    <td>${escapeHTML(r.target_book_title || r.target_user_name)}</td>
                    <td>${escapeHTML(r.reporter_name)}</td>
                    <td><span style="color: #FF6584;">${r.reason.toUpperCase()}</span></td>
                    <td><span class="status-badge ${r.status === 'pending' ? 'pending' : 'active'}">${r.status}</span></td>
                    <td>
                        <button class="btn-action" onclick="adminApp.resolveReport(${r.id})">Resolve</button>
                    </td>
                </tr>
            `).join('');
        } catch (e) {
            console.error(e);
        }
    }

    async resolveReport(id) {
        const notes = prompt('Admin resolution notes:');
        if (notes === null) return;
        try {
            await this.fetchWithAuth(`${API_BASE_URL}/core/reports/${id}/resolve/`, { 
                method: 'POST',
                body: JSON.stringify({ notes })
            });
            this.loadReportsView();
        } catch (e) { alert('Action failed'); }
    }

    async showUserProfile(id) {
        const modal = document.getElementById('user-modal');
        const content = document.getElementById('user-modal-content');
        modal.style.display = 'flex';
        content.innerHTML = '<div style="padding: 40px; text-align: center;"><div class="loading-spinner"></div><p>Gathering 360° Profile Data...</p></div>';

        try {
            const user = await this.fetchWithAuth(`${API_BASE_URL}/accounts/admin-profiles/${id}/history/`);
            
            content.innerHTML = `
                <div class="user-details-view animate-slide-up">
                    <div style="display: flex; gap: 30px; margin-bottom: 30px;">
                        <img src="${user.avatar || 'https://via.placeholder.com/150'}" style="width: 120px; height: 120px; border-radius: 20px; object-fit: cover; border: 2px solid var(--accent-primary);">
                        <div style="flex: 1;">
                            <h2 style="margin: 0 0 5px 0; color: white;">${escapeHTML(user.username)} ${user.is_verified ? '<span title="Verified" style="color: #00D2FF; font-size: 0.8em;">✔️</span>' : ''}</h2>
                            <p style="color: var(--text-secondary); margin: 0 0 15px 0;">${user.email}</p>
                            <div style="display: flex; gap: 10px;">
                                <span class="status-badge active">${user.role.toUpperCase()}</span>
                                <button class="btn-action" style="padding: 2px 10px; font-size: 11px;" onclick="adminApp.messageUser(${user.id}, '${escapeHTML(user.username)}')">Direct Message</button>
                            </div>
                        </div>
                        <div style="text-align: right;">
                            <button class="btn-action red" onclick="document.getElementById('user-modal').style.display='none'">Close</button>
                        </div>
                    </div>

                    <div class="stats-mini-grid" style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin-bottom: 30px;">
                        <div class="glass" style="padding: 15px; border-radius: 15px; text-align: center;">
                            <div style="font-size: 24px; font-weight: bold; color: var(--accent-primary);">${user.total_reads}</div>
                            <div style="font-size: 12px; opacity: 0.7;">Books Read</div>
                        </div>
                        <div class="glass" style="padding: 15px; border-radius: 15px; text-align: center;">
                            <div style="font-size: 24px; font-weight: bold; color: var(--accent-secondary);">${user.published_books.length}</div>
                            <div style="font-size: 12px; opacity: 0.7;">Stories Published</div>
                        </div>
                        <div class="glass" style="padding: 15px; border-radius: 15px; text-align: center;">
                            <div style="font-size: 24px; font-weight: bold; color: #FF6584;">${user.reports_received.length}</div>
                            <div style="font-size: 12px; opacity: 0.7;">Safety Flags</div>
                        </div>
                    </div>

                    <div class="glass" style="padding: 20px; border-radius: 15px; margin-bottom: 30px; display: flex; gap: 10px;">
                        <button class="btn-action red" onclick="adminApp.suspendUser(${user.id}, '${escapeHTML(user.username)}')">🚫 Suspend User</button>
                        <button class="btn-action blue" onclick="adminApp.resetPassword(${user.id}, '${escapeHTML(user.username)}')">🔑 Reset Password</button>
                        <button class="btn-action purple" onclick="adminApp.messageUser(${user.id}, '${escapeHTML(user.username)}')">💬 Send Message</button>
                    </div>

                    ${user.verification_status === 'pending' ? `
                        <div class="glass" style="padding: 20px; border-radius: 15px; border: 1px solid rgba(0, 210, 255, 0.3); margin-bottom: 30px; background: rgba(0, 210, 255, 0.05);">
                            <h4 style="margin-top: 0; color: #00D2FF;">🛡️ Verification Review</h4>
                            <p style="font-size: 14px;">This author has requested a verified badge.</p>
                            <div style="display: flex; gap: 20px; margin-top: 15px;">
                                <div style="flex: 1;">
                                    <label style="font-size: 12px; opacity: 0.6; display: block; margin-bottom: 5px;">ID DOCUMENT</label>
                                    <img src="${user.verification_id_image || 'https://via.placeholder.com/100?text=No+ID'}" style="width: 100%; max-height: 150px; border-radius: 10px; object-fit: contain; background: black;">
                                </div>
                                <div style="flex: 1;">
                                    <label style="font-size: 12px; opacity: 0.6; display: block; margin-bottom: 5px;">SOCIAL LINKS</label>
                                    <div class="glass" style="padding: 10px; border-radius: 10px; font-size: 13px; height: 120px; overflow-y: auto;">
                                        ${user.verification_links || 'No links provided'}
                                    </div>
                                </div>
                            </div>
                            <div style="display: flex; gap: 10px; margin-top: 20px;">
                                <button class="btn-action green" style="flex: 1;" onclick="adminApp.approveVerification(${user.id})">Approve & Grant Badge</button>
                                <button class="btn-action red" style="flex: 1;" onclick="adminApp.rejectVerification(${user.id})">Reject Request</button>
                            </div>
                        </div>
                    ` : ''}

                    <div style="display: grid; grid-template-columns: 1.5fr 1fr; gap: 30px;">
                        <div>
                            <h3 style="margin-top: 0;">Author Portfolio</h3>
                            <div class="table-container" style="max-height: 250px; overflow-y: auto;">
                                <table class="data-table">
                                    <thead><tr><th>Title</th><th>Status</th></tr></thead>
                                    <tbody>
                                        ${user.published_books.map(b => `
                                            <tr>
                                                <td>${escapeHTML(b.title)}</td>
                                                <td><span class="status-badge ${b.status === 'approved' ? 'active' : ''}">${b.status}</span></td>
                                            </tr>
                                        `).join('') || '<tr><td colspan="2">No stories yet.</td></tr>'}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                        <div>
                            <h3 style="margin-top: 0;">Safety Flags</h3>
                            <div class="table-container" style="max-height: 250px; overflow-y: auto;">
                                <table class="data-table">
                                    <thead><tr><th>Reason</th><th>Status</th></tr></thead>
                                    <tbody>
                                        ${user.reports_received.map(r => `
                                            <tr>
                                                <td style="color: #FF6584;">${r.reason.toUpperCase()}</td>
                                                <td><span class="status-badge ${r.status === 'resolved' ? 'active' : ''}">${r.status}</span></td>
                                            </tr>
                                        `).join('') || '<tr><td colspan="2">No flags. Good citizen!</td></tr>'}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
            `;
        } catch (e) {
            console.error(e);
            content.innerHTML = '<p style="padding: 40px; text-align: center; color: #FF6584;">Error loading user profile.</p>';
        }
    }

    async approveVerification(id) {
        if (!confirm('Confirm verification for this author? They will receive the blue badge.')) return;
        try {
            await this.fetchWithAuth(`${API_BASE_URL}/accounts/admin-profiles/${id}/verify_approve/`, { method: 'POST' });
            this.showUserProfile(id);
            this.loadUsersView(); // Refresh list in background
        } catch (e) { alert('Failed to approve'); }
    }

    async rejectVerification(id) {
        if (!confirm('Reject this verification request?')) return;
        try {
            await this.fetchWithAuth(`${API_BASE_URL}/accounts/admin-profiles/${id}/verify_reject/`, { method: 'POST' });
            this.showUserProfile(id);
            this.loadUsersView();
        } catch (e) { alert('Failed to reject'); }
    }

    async loadBroadcastView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `<div class="glass section-card animate-slide-up" style="max-width: 600px; margin: 0 auto;">
            <h3>📢 Send System Broadcast</h3>
            <p style="font-size: 14px; opacity: 0.7; margin-bottom: 20px;">
                This message will be sent as a system notification to <strong>ALL</strong> registered users in the mobile app.
            </p>
            <div style="margin-bottom: 20px;">
                <label style="display: block; margin-bottom: 8px; font-size: 12px; opacity: 0.6;">BROADCAST MESSAGE</label>
                <textarea id="broadcast-message" placeholder="e.g. We are performing maintenance tonight at 12 AM UTC..." 
                    style="width: 100%; height: 150px; background: rgba(0,0,0,0.3); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; color: white; padding: 15px; font-family: inherit; resize: none;"></textarea>
            </div>
            <button class="btn-action green" style="width: 100%; padding: 15px;" onclick="adminApp.sendBroadcast()">🚀 Blast Message to All Users</button>
            <p style="font-size: 11px; text-align: center; margin-top: 15px; opacity: 0.5;">
                ⚠️ Use this sparingly to avoid spamming users.
            </p>
        </div>`;
    }

    async sendBroadcast() {
        const message = document.getElementById('broadcast-message').value;
        if (!message) return alert('Please enter a message');
        if (!confirm('Are you sure you want to send this to EVERY user?')) return;

        try {
            const res = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/broadcast/`, {
                method: 'POST',
                body: JSON.stringify({ message })
            });
            alert(`Success! Broadcast sent to ${res.count} users.`);
            document.getElementById('broadcast-message').value = '';
        } catch (e) { alert('Broadcast failed'); }
    }

    async messageUser(id, username) {
        const message = prompt(`Send a direct message to ${username}:`);
        if (!message) return;

        try {
            await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/message_user/`, {
                method: 'POST',
                body: JSON.stringify({ user_id: id, message })
            });
            alert('Message sent successfully!');
        } catch (e) { alert('Failed to send message'); }
    }

    async loadSecurityView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `<div class="glass section-card animate-slide-up">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                <h3 style="margin: 0;">Administrative Audit Logs</h3>
                <span class="status-badge active">System Health: Secure</span>
            </div>
            <div class="table-container">
                <table class="data-table">
                    <thead>
                        <tr>
                            <th>Timestamp</th>
                            <th>Admin</th>
                            <th>Action</th>
                            <th>Target</th>
                            <th>Details</th>
                            <th>IP Address</th>
                        </tr>
                    </thead>
                    <tbody id="audit-logs-target">
                        <tr><td colspan="6">Loading logs...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>`;

        try {
            const logs = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/audit_logs/`);
            const target = document.getElementById('audit-logs-target');
            
            if (logs.length === 0) {
                target.innerHTML = `<tr><td colspan="6">No logs found.</td></tr>`;
                return;
            }

            target.innerHTML = logs.map(l => `
                <tr>
                    <td style="font-size: 12px; opacity: 0.7;">${new Date(l.timestamp).toLocaleString()}</td>
                    <td><strong>${escapeHTML(l.admin)}</strong></td>
                    <td><span class="status-badge" style="background: rgba(108, 99, 255, 0.1); color: var(--accent-primary); font-size: 10px;">${l.action}</span></td>
                    <td>${escapeHTML(l.target || '-')}</td>
                    <td style="font-size: 12px; max-width: 300px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${escapeHTML(l.details)}">
                        ${escapeHTML(l.details || '-')}
                    </td>
                    <td style="font-family: monospace; font-size: 11px; opacity: 0.6;">${l.ip || 'Local'}</td>
                </tr>
            `).join('');
        } catch (e) {
            console.error(e);
        }
    }

    toggleAllUsers(master) {
        document.querySelectorAll('.user-checkbox').forEach(cb => cb.checked = master.checked);
    }

    async bulkVerifyUsers() {
        const selected = Array.from(document.querySelectorAll('.user-checkbox:checked')).map(cb => parseInt(cb.value));
        if (selected.length === 0) return alert('Select users first');
        if (!confirm(`Verify ${selected.length} users at once?`)) return;

        try {
            await this.fetchWithAuth(`${API_BASE_URL}/accounts/admin-profiles/bulk_verify/`, {
                method: 'POST',
                body: JSON.stringify({ user_ids: selected })
            });
            alert(`Success! ${selected.length} users verified.`);
            this.loadUsersView();
        } catch (e) { alert('Failed to reject'); }
    }

    async loadFinanceView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `
            <div class="stats-grid">
                <div class="stat-card glass">
                    <div class="stat-label">Total Revenue</div>
                    <div class="stat-value" id="fin-revenue">$0.00</div>
                </div>
                <div class="stat-card glass">
                    <div class="stat-label">Total Payouts</div>
                    <div class="stat-value" id="fin-payouts">$0.00</div>
                </div>
                <div class="stat-card glass">
                    <div class="stat-label">Pending Requests</div>
                    <div class="stat-value" id="fin-pending">$0.00</div>
                </div>
            </div>
            <div class="chart-grid" style="margin-top: 30px;">
                <div class="glass section-card">
                    <h3>Revenue by Category</h3>
                    <div style="height: 300px;"><canvas id="finCategoryChart"></canvas></div>
                </div>
                <div class="glass section-card">
                    <h3>Recent Transactions</h3>
                    <div class="table-container">
                        <table class="data-table">
                            <thead><tr><th>User</th><th>Amount</th><th>Type</th></tr></thead>
                            <tbody id="fin-transactions-target"></tbody>
                        </table>
                    </div>
                </div>
            </div>
        `;

        try {
            const data = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/financial_stats/`);
            document.getElementById('fin-revenue').textContent = `$${data.total_revenue.toFixed(2)}`;
            document.getElementById('fin-payouts').textContent = `$${data.total_payouts.toFixed(2)}`;
            document.getElementById('fin-pending').textContent = `$${data.pending_payouts.toFixed(2)}`;

            const list = document.getElementById('fin-transactions-target');
            list.innerHTML = data.recent_transactions.map(t => `
                <tr>
                    <td>${escapeHTML(t.user__username)}</td>
                    <td style="color: ${t.type === 'purchase' ? 'var(--accent-green)' : '#FF6584'}">${t.type === 'purchase' ? '+' : '-'}$${t.amount}</td>
                    <td><span class="status-badge">${t.type}</span></td>
                </tr>
            `).join('') || '<tr><td colspan="3">No transactions.</td></tr>';

            new Chart(document.getElementById('finCategoryChart'), {
                type: 'bar',
                data: {
                    labels: data.category_breakdown.map(c => c.category__name || 'Unknown'),
                    datasets: [{
                        label: 'Revenue ($)',
                        data: data.category_breakdown.map(c => c.revenue),
                        backgroundColor: '#6C63FF'
                    }]
                },
                options: this.getChartOptions(true)
            });
        } catch (e) { console.error(e); }
    }

    async loadSupportView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `
            <div class="glass section-card animate-slide-up">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;">
                    <h3>Support Tickets</h3>
                    <select id="ticket-status-filter" class="glass" style="padding: 8px; border-radius: 8px; color: white; background: rgba(0,0,0,0.3);" onchange="adminApp.loadSupportView()">
                        <option value="open">Open</option>
                        <option value="closed">Closed</option>
                    </select>
                </div>
                <div class="table-container">
                    <table class="data-table">
                        <thead><tr><th>User</th><th>Subject</th><th>Created</th><th>Action</th></tr></thead>
                        <tbody id="tickets-target"></tbody>
                    </table>
                </div>
            </div>
        `;

        const status = document.getElementById('ticket-status-filter').value;
        try {
            const tickets = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/tickets/?status=${status}`);
            const target = document.getElementById('tickets-target');
            target.innerHTML = tickets.map(t => `
                <tr>
                    <td>${escapeHTML(t.user__username)}</td>
                    <td><strong>${escapeHTML(t.subject)}</strong></td>
                    <td>${new Date(t.created_at).toLocaleDateString()}</td>
                    <td><button class="btn-action" onclick="adminApp.viewTicket(${t.id}, '${escapeHTML(t.user__username)}', '${escapeHTML(t.message)}')">View & Reply</button></td>
                </tr>
            `).join('') || '<tr><td colspan="4">No tickets found.</td></tr>';
        } catch (e) { console.error(e); }
    }

    viewTicket(id, user, msg) {
        const response = prompt(`Ticket from ${user}:\n\n"${msg}"\n\nEnter your response:`);
        if (!response) return;
        this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/respond_ticket/`, {
            method: 'POST',
            body: JSON.stringify({ ticket_id: id, response })
        }).then(() => {
            this.showSuccess('Response Sent');
            this.loadSupportView();
        });
    }

    async loadBannersView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `
            <div class="glass section-card animate-slide-up">
                <h3>App Banner Manager</h3>
                <p style="opacity: 0.7; margin-bottom: 20px;">Manage promotional banners shown on the mobile app home screen.</p>
                <div class="stats-grid" id="banners-target"></div>
            </div>
        `;

        try {
            const banners = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/banners/`);
            const target = document.getElementById('banners-target');
            target.innerHTML = banners.map(b => `
                <div class="stat-card glass" style="padding: 15px;">
                    <img src="${b.image}" style="width: 100%; height: 100px; object-fit: cover; border-radius: 10px; margin-bottom: 10px;">
                    <h4>${escapeHTML(b.title)}</h4>
                    <div class="toggle-row">
                        <span>Active</span>
                        <label class="switch">
                            <input type="checkbox" ${b.is_active ? 'checked' : ''} onchange="adminApp.toggleBanner(${b.id}, this.checked)">
                            <span class="slider"></span>
                        </label>
                    </div>
                </div>
            `).join('') || '<p>No banners configured.</p>';
        } catch (e) { console.error(e); }
    }

    async toggleBanner(id, active) {
        await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/update_banner/`, {
            method: 'POST',
            body: JSON.stringify({ id, is_active: active })
        });
        this.showSuccess('Banner Updated');
    }

    loadEmailsView() {
        const container = document.getElementById('view-container');
        container.innerHTML = `
            <div class="glass section-card animate-slide-up" style="max-width: 600px; margin: 0 auto;">
                <h3>📧 Send Official Email</h3>
                <div style="margin-top: 20px;">
                    <label style="display: block; font-size: 12px; opacity: 0.6;">TARGET USER ID</label>
                    <input type="number" id="email-user-id" class="glass" style="width: 100%; padding: 10px; margin-bottom: 20px; color: white;">
                    
                    <label style="display: block; font-size: 12px; opacity: 0.6;">SUBJECT</label>
                    <input type="text" id="email-subject" class="glass" style="width: 100%; padding: 10px; margin-bottom: 20px; color: white;">
                    
                    <label style="display: block; font-size: 12px; opacity: 0.6;">MESSAGE</label>
                    <textarea id="email-message" class="glass" style="width: 100%; height: 200px; padding: 15px; color: white; resize: none;"></textarea>
                    
                    <button class="btn-action purple" style="width: 100%; padding: 15px; margin-top: 20px;" onclick="adminApp.sendEmail()">Send Professional Email</button>
                </div>
            </div>
        `;
    }

    async sendEmail() {
        const user_id = document.getElementById('email-user-id').value;
        const subject = document.getElementById('email-subject').value;
        const message = document.getElementById('email-message').value;
        if (!user_id || !subject || !message) return alert('All fields required');

        await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/send_email/`, {
            method: 'POST',
            body: JSON.stringify({ user_id, subject, message })
        });
        this.showSuccess('Email Queued');
    }

    async suspendUser(id, username) {
        const reason = prompt(`Suspend ${username}?\nEnter reason:`);
        if (!reason) return;
        const days = prompt('Suspend for how many days?', '7');
        if (!days) return;

        await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/suspend_user/`, {
            method: 'POST',
            body: JSON.stringify({ user_id: id, reason, days })
        });
        this.showSuccess('User Suspended');
        this.showUserProfile(id);
    }

    async loadDropOffView(bookId, title) {
        const container = document.getElementById('view-container');
        container.innerHTML = `
            <div class="glass section-card animate-slide-up">
                <h3>📖 Drop-off Analytics: ${title}</h3>
                <p style="opacity: 0.7; margin-bottom: 25px;">Percentage of readers who finished each chapter.</p>
                <div style="height: 400px;"><canvas id="dropOffChart"></canvas></div>
            </div>
        `;

        try {
            const data = await this.fetchWithAuth(`${API_BASE_URL}/admin/admin-stats/drop_off_stats/?book_id=${bookId}`);
            new Chart(document.getElementById('dropOffChart'), {
                type: 'line',
                data: {
                    labels: data.map(d => d.chapter__title),
                    datasets: [{
                        label: 'Completion Rate (%)',
                        data: data.map(d => (d.completions / (d.total_reads || 1) * 100).toFixed(1)),
                        borderColor: '#00D2FF',
                        backgroundColor: 'rgba(0, 210, 255, 0.1)',
                        fill: true,
                        tension: 0.4
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: { min: 0, max: 100, ticks: { color: 'rgba(255,255,255,0.5)' } },
                        x: { ticks: { color: 'rgba(255,255,255,0.5)' } }
                    }
                }
            });
        } catch (e) { console.error(e); }
    }
}

const adminApp = new AdminApp();
