const API_BASE_URL = `${window.location.origin}/api`;

// Security: XSS Prevention Utility
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

class SrishtyApp {
    constructor() {
        this.token = localStorage.getItem('access_token');
        this.currentUser = localStorage.getItem('username');
        this.currentView = 'home';
        this.isSignUpMode = false;
        this.quill = null;

        // Studio State
        this.currentStoryId = null;
        this.currentChapters = [];
        this.currentChapterId = null;
        this.allExploreBooks = [];
        this.currentExploreCategory = null;

        // Wait for DOM to be ready before init
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.init());
        } else {
            this.init();
        }
    }

    async init() {
        console.log('App: Initializing Srishty Studio PRO...');
        this.checkAuth();

        try {
            this.setupQuill();
            this.fetchCategories();
        } catch (e) {
            console.warn('Init delayed/failed:', e);
        }
    }

    async fetchCategories() {
        try {
            const data = await this.fetchAPI('/core/categories/');
            if (!data) return;
            const cats = data.results || data;
            const select = document.getElementById('create-category');
            if (select && Array.isArray(cats)) {
                // Clear existing options except first
                while (select.options.length > 1) select.remove(1);

                cats.forEach(c => {
                    const opt = document.createElement('option');
                    opt.value = c.id;
                    opt.textContent = c.name;
                    select.appendChild(opt);
                });
            }
        } catch (e) { console.error('Cat Fetch Error:', e); }
    }

    setupQuill() {
        if (!document.getElementById('editor-container')) return;

        this.quill = new Quill('#editor-container', {
            theme: 'snow',
            modules: {
                toolbar: [
                    [{ 'header': [1, 2, 3, false] }],
                    ['bold', 'italic', 'underline', 'strike'],
                    ['blockquote', 'image'],
                    [{ 'list': 'ordered' }, { 'list': 'bullet' }],
                    ['clean']
                ]
            },
            placeholder: 'Start writing your masterpiece...'
        });

        this.quill.on('text-change', () => {
            const text = this.quill.getText().trim();
            const count = text.length > 0 ? text.split(/\s+/).length : 0;
            const wordCountEl = document.getElementById('word-count');
            if (wordCountEl) wordCountEl.textContent = `${count.toLocaleString()} words`;

            // Subtle auto-save indicator
            const statusText = document.getElementById('save-status');
            if (statusText && statusText.textContent === 'Saved') {
                statusText.textContent = 'Editing...';
                statusText.style.color = 'var(--text-secondary)';
            }
        });
    }

    /* ======== API & AUTH ======== */
    async fetchAPI(endpoint, options = {}) {
        const headers = { ...options.headers };
        if (!(options.body instanceof FormData)) {
            headers['Content-Type'] = 'application/json';
        }
        if (this.token) Object.assign(headers, { 'Authorization': `Bearer ${this.token}` });

        let response = await fetch(`${API_BASE_URL}${endpoint}`, { ...options, headers });

        // If 401, the token might be expired. Logout to clear it and try one last time as a guest.
        if (response.status === 401 && this.token) {
            this.logout();
            const guestHeaders = { ...options.headers };
            if (!(options.body instanceof FormData)) {
                guestHeaders['Content-Type'] = 'application/json';
            }
            response = await fetch(`${API_BASE_URL}${endpoint}`, { ...options, headers: guestHeaders });
        }

        if (!response.ok) {
            const bodyText = await response.text();
            let errorMessage = `API Error ${response.status}`;
            try {
                const errorData = JSON.parse(bodyText);
                errorMessage += `: ${JSON.stringify(errorData)}`;
            } catch (e) {
                errorMessage += `: ${bodyText || 'No response body'}`;
            }
            throw new Error(errorMessage);
        }
        return await response.json();
    }

    checkAuth() {
        const gw = document.getElementById('auth-gateway');
        const shell = document.getElementById('app-shell');

        if (!this.token) {
            gw.classList.remove('hidden');
            shell.classList.add('hidden');
        } else {
            gw.classList.add('hidden');
            shell.classList.remove('hidden');

            // Update Navbar Profile
            const usernameEl = document.getElementById('nav-username');
            const initialsEl = document.getElementById('nav-initials');
            const welcome = document.getElementById('welcome-message');

            if (usernameEl) usernameEl.textContent = this.currentUser;
            if (initialsEl && this.currentUser) initialsEl.textContent = this.currentUser.substring(0, 2).toUpperCase();
            if (welcome) welcome.textContent = `Welcome back, ${this.currentUser} 👋`;

            this.switchView('home');
        }
    }

    async handleAuth(e) {
        if (e) e.preventDefault();
        const user = document.getElementById('auth-user').value;
        const pass = document.getElementById('auth-pass').value;
        const errorEl = document.getElementById('auth-error');
        const btn = document.getElementById('auth-btn');

        btn.textContent = 'Authenticating...';
        btn.disabled = true;
        errorEl.style.display = 'none';

        try {
            if (this.isSignUpMode) {
                const email = document.getElementById('auth-email').value;
                await this.fetchAPI('/accounts/auth/register/', {
                    method: 'POST',
                    body: JSON.stringify({ username: user, email, password: pass })
                });
            }
            const res = await fetch(`${API_BASE_URL}/token/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username: user, password: pass })
            });

            if (!res.ok) {
                const errData = await res.json().catch(() => ({}));
                throw new Error(errData.detail || 'Incorrect username or password.');
            }
            const data = await res.json();

            this.token = data.access;
            this.currentUser = user;
            localStorage.setItem('access_token', this.token);
            localStorage.setItem('username', user);

            this.checkAuth();
        } catch (err) {
            console.error('Auth error:', err);
            errorEl.style.display = 'block';
            errorEl.textContent = err.message || (this.isSignUpMode ? 'Registration failed. Please check your details.' : 'Incorrect username or password.');
        } finally {
            btn.textContent = this.isSignUpMode ? 'Register' : 'Sign In';
            btn.disabled = false;
        }
    }

    toggleAuthMode(e) {
        e.preventDefault();
        this.isSignUpMode = !this.isSignUpMode;
        document.getElementById('signup-extra').classList.toggle('hidden');
        document.getElementById('auth-toggle-text').textContent = this.isSignUpMode ? 'Already have an account?' : 'New to Srishty?';
        e.target.textContent = this.isSignUpMode ? 'Sign In' : 'Create Account';
        document.getElementById('auth-btn').textContent = this.isSignUpMode ? 'Register' : 'Sign In';
    }

    logout() {
        this.token = null;
        this.currentUser = null;
        localStorage.removeItem('access_token');
        localStorage.removeItem('username');
        this.checkAuth();
    }

    /* ======== VIEW ROUTING ======== */
    switchView(viewName) {
        document.querySelectorAll('.view-content').forEach(el => {
            el.classList.add('hidden');
            el.style.opacity = '0';
        });

        const activeView = document.getElementById(`view-${viewName}`);
        if (activeView) {
            activeView.classList.remove('hidden');
            // Trigger smooth fade-in
            setTimeout(() => {
                activeView.style.opacity = '1';
            }, 50);
        }

        this.currentView = viewName;

        // Update Nav Active State
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });

        if (viewName === 'home') document.getElementById('nav-home').classList.add('active');
        if (viewName === 'analytics') document.getElementById('nav-analytics').classList.add('active');

        if (viewName === 'home') this.loadDashboard();
        if (viewName === 'create') this.resetCreateForm();
        if (viewName === 'analytics') this.loadAnalyticsData();
        if (viewName === 'explore') this.loadExploreData();
    }

    getMediaUrl(path) {
        if (!path) return 'https://placehold.co/400x600/E2E8F0/64748B?text=Cover+Not+Found';
        if (path.startsWith('http')) return path;
        const backendOrigin = API_BASE_URL.replace('/api', '').replace(/\/$/, '');
        const cleanPath = path.startsWith('/') ? path : `/${path}`;
        return `${backendOrigin}${cleanPath}`;
    }

    /* ======== DASHBOARD ======== */
    async loadDashboard() {
        const grid = document.getElementById('story-grid');
        // Show Loading Skeletons
        grid.innerHTML = `
            <div class="skeleton-card"></div>
            <div class="skeleton-card"></div>
            <div class="skeleton-card"></div>
        `;

        try {
            const data = await this.fetchAPI('/core/books/my_books/');
            const myBooks = data?.results || data;

            if (!myBooks || myBooks.length === 0) {
                grid.innerHTML = `
                    <div style="grid-column: 1/-1; text-align: center; padding: 60px; background: white; border-radius: 24px; border: 2px dashed var(--border-color);">
                        <div style="font-size: 48px; margin-bottom: 16px;">📚</div>
                        <h3 style="margin-bottom: 8px;">Your library is empty</h3>
                        <p style="color: var(--text-secondary); margin-bottom: 24px;">Start your writing journey today by creating your first story.</p>
                        <button class="btn-primary" onclick="app.switchView('create')">Create My First Story</button>
                    </div>
                `;
                return;
            }

            grid.innerHTML = myBooks.map(book => {
                const coverUrl = this.getMediaUrl(book.cover);
                const statusClass = book.is_published ? 'status-published' : 'status-draft';
                const statusLabel = book.is_published ? 'Published' : 'Draft';

                return `
                <div class="story-card">
                    <div class="story-card-img">
                        <img src="${coverUrl}" alt="cover" onerror="this.onerror=null;this.src='https://placehold.co/400x600/E2E8F0/64748B?text=Cover+Lost';">
                        <div class="card-badge ${statusClass}">${statusLabel}</div>
                        <div class="story-card-overlay">
                            <button class="btn-primary" style="width: 100%;" onclick="app.openEditor(${book.id})">Continue Writing</button>
                        </div>
                    </div>
                    <div class="story-info-meta">
                        <div class="story-card-title">${escapeHTML(book.title)}</div>
                        <div class="story-card-subtitle">${book.chapters_count || 0} Chapters • 0 Reads</div>
                    </div>
                    <div class="story-card-actions">
                        <button class="btn-card-write" onclick="app.openEditor(${book.id})">
                            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>
                            Write
                        </button>
                        <button class="btn-card-settings" onclick="app.openSettings(${book.id})">
                            <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                            Settings
                        </button>
                    </div>
                </div>
                `;
            }).join('');

        } catch (err) {
            console.error('Dashboard Error:', err);
            grid.innerHTML = `<div style="grid-column: 1/-1; color: var(--danger); text-align: center; padding: 40px;">⚠️ Failed to load library. Please check your connection.</div>`;
        }
    }

    /* ======== CREATE STORY VIEW ======== */
    resetCreateForm() {
        const form = document.getElementById('create-story-form');
        if (form) form.reset();
    }

    async handleCreateStory(e) {
        e.preventDefault();
        const btn = document.getElementById('create-btn');
        btn.textContent = 'Creating...';
        btn.disabled = true;

        const formData = new FormData();
        formData.append('title', document.getElementById('create-title').value);
        formData.append('description', document.getElementById('create-desc').value);
        formData.append('tags', document.getElementById('create-tags').value);
        formData.append('language', document.getElementById('create-language').value);

        const catId = document.getElementById('create-category').value;
        if (catId) formData.append('category', catId);

        const coverFile = document.getElementById('create-cover').files[0];
        if (coverFile) formData.append('cover', coverFile);

        const audioFile = document.getElementById('create-audio').files[0];
        if (audioFile) formData.append('audio_file', audioFile);

        const importFile = document.getElementById('create-import-file').files[0];

        try {
            const book = await this.fetchAPI('/core/books/', { method: 'POST', body: formData });

            // If an import file is selected, process it
            if (importFile) {
                btn.textContent = 'Importing Chapters...';
                const chapters = await this.readAndParseFile(importFile);
                for (let i = 0; i < chapters.length; i++) {
                    const chap = chapters[i];
                    const chapData = new FormData();
                    chapData.append('title', chap.title);
                    chapData.append('content', chap.content);
                    chapData.append('order', i);
                    await this.fetchAPI(`/core/books/${book.id}/chapters/`, { method: 'POST', body: chapData });
                }
            }

            await this.openEditor(book.id);
        } catch (err) {
            alert(`Failed to create story: ${err.message}`);
        } finally {
            btn.textContent = 'Create Story';
            btn.disabled = false;
        }
    }

    readAndParseFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                const text = e.target.result;
                resolve(this.parseChapters(text));
            };
            reader.onerror = reject;
            reader.readAsText(file);
        });
    }

    /* ======== EDITOR VIEW ======== */
    async openEditor(bookId) {
        this.currentStoryId = bookId;
        this.switchView('editor');
        this.quill.setText('Loading chapter...\n');

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('editor-story-title').textContent = book.title;
            this.currentChapters = book.chapters || [];

            this.renderChapterList();

            if (this.currentChapters.length === 0) {
                this.createNewChapter();
            } else {
                this.loadSelectedChapter(this.currentChapters[0].id);
            }
        } catch (err) {
            console.error(err);
            this.quill.setText('Error loading story context.');
        }
    }

    renderChapterList() {
        const list = document.getElementById('sidebar-chapter-list');
        list.innerHTML = '';

        this.currentChapters.forEach((ch, idx) => {
            const div = document.createElement('div');
            div.className = `chapter-item ${ch.id === this.currentChapterId ? 'active' : ''}`;
            div.innerHTML = `
                <span>${escapeHTML(ch.title) || 'Chapter ' + (idx + 1)}</span>
                <span style="font-size: 10px; opacity: 0.5;">${idx + 1}</span>
            `;
            div.onclick = () => this.loadSelectedChapter(ch.id);
            list.appendChild(div);
        });
    }

    loadChapterContent(chapterObj) {
        if (!chapterObj.content) {
            this.quill.setText('');
            return;
        }
        try {
            this.quill.setContents(JSON.parse(chapterObj.content));
        } catch (e) {
            this.quill.setText(chapterObj.content);
        }
        document.getElementById('editor-chapter-label').textContent = chapterObj.title || 'Untitled Chapter';
    }

    loadSelectedChapter(id) {
        if (id === 'new') {
            this.currentChapterId = null;
            this.quill.setText('');
            document.getElementById('editor-chapter-label').textContent = 'New Chapter';
        } else {
            this.currentChapterId = id;
            const chap = this.currentChapters.find(c => c.id === id);
            if (chap) {
                this.loadChapterContent(chap);
            }
        }

        // Update UI state
        this.renderChapterList();
    }

    async createNewChapter() {
        const textContent = this.quill.getText().trim();
        if (this.currentChapterId === null && textContent.length > 0) {
            await this.saveCurrentChapter();
        }

        const list = document.getElementById('sidebar-chapter-list');
        this.currentChapterId = null;
        this.quill.setText('');
        document.getElementById('editor-chapter-label').textContent = 'New Chapter';
        document.getElementById('save-status').textContent = 'Unsaved';
        document.getElementById('save-status').style.color = 'var(--accent-secondary)';

        // Remove active class from others
        document.querySelectorAll('.chapter-item').forEach(el => el.classList.remove('active'));
        this.quill.focus();
    }

    async saveCurrentChapter() {
        const content = this.quill.getText();
        const textContent = content.trim();
        if (!textContent) return; // Don't save empty

        const saveBtn = document.getElementById('save-indicator');
        const statusText = document.getElementById('save-status');
        saveBtn.textContent = 'Saving...';
        statusText.textContent = 'Saving...';

        const label = document.getElementById('editor-chapter-label').textContent;
        const formData = new FormData();
        formData.append('title', label === 'New Chapter' ? `Chapter ${this.currentChapters.length + 1}` : label);
        formData.append('content', content);

        try {
            if (this.currentChapterId) {
                await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/`, {
                    method: 'PATCH',
                    body: formData
                });
                const idx = this.currentChapters.findIndex(c => c.id === this.currentChapterId);
                if (idx !== -1) this.currentChapters[idx].content = content;
            } else {
                const order = this.currentChapters.length;
                formData.append('order', order);
                const newChap = await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/`, {
                    method: 'POST',
                    body: formData
                });
                this.currentChapterId = newChap.id;
                this.currentChapters.push(newChap);
            }

            saveBtn.textContent = 'Save Draft';
            statusText.textContent = 'Saved';
            statusText.style.color = '#10B981';
            this.renderChapterList();
        } catch (e) {
            console.error('Save Error:', e);
            statusText.textContent = 'Save Error';
            statusText.style.color = 'var(--danger)';
        }
    }

    async publishStory() {
        if (!this.currentStoryId) return;
        if (!confirm('Ready to publish? This will make your story visible in the mobile app library.')) return;

        try {
            const formData = new FormData();
            formData.append('is_published', 'true');
            await this.fetchAPI(`/core/books/${this.currentStoryId}/`, {
                method: 'PATCH',
                body: formData
            });
            alert('Story Published! 🚀');
            this.switchView('home');
        } catch (e) {
            alert(`Failed to publish: ${e.message}`);
        }
    }

    /* ======== SETTINGS VIEW ======== */
    async openSettings(bookId) {
        if (!bookId) bookId = this.currentStoryId;
        if (!bookId) return;

        this.currentStoryId = bookId;
        this.switchView('settings');

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('settings-title').value = book.title;
            document.getElementById('settings-desc').value = book.description;
            document.getElementById('settings-status').value = book.is_published ? 'published' : 'draft';

            const preview = document.getElementById('settings-cover-preview');
            const coverUrl = this.getMediaUrl(book.cover);
            if (coverUrl) {
                preview.src = coverUrl;
                preview.style.display = 'block';
            } else {
                preview.style.display = 'none';
            }

            const audioLabel = document.getElementById('settings-audio-label');
            if (book.audio_file) {
                const parts = book.audio_file.split('/');
                audioLabel.textContent = parts[parts.length - 1];
            } else {
                audioLabel.textContent = 'No audio';
            }
        } catch (e) {
            console.error(e);
        }
    }

    async handleSaveSettings(e) {
        e.preventDefault();
        const btn = document.getElementById('settings-btn');
        btn.textContent = 'Saving...';

        const formData = new FormData();
        formData.append('title', document.getElementById('settings-title').value);
        formData.append('description', document.getElementById('settings-desc').value);
        formData.append('is_published', document.getElementById('settings-status').value === 'published');

        const coverFile = document.getElementById('settings-cover').files[0];
        if (coverFile) formData.append('cover', coverFile);

        const audioFile = document.getElementById('settings-audio').files[0];
        if (audioFile) formData.append('audio_file', audioFile);

        try {
            await this.fetchAPI(`/core/books/${this.currentStoryId}/`, {
                method: 'PATCH',
                body: formData
            });
            alert('Story updated successfully!');
            this.switchView('home');
        } catch (e) {
            alert('Failed to save settings.');
        } finally {
            btn.textContent = 'Save Changes';
        }
    }

    async handleBulkImport(e) {
        const file = e.target.files[0];
        if (!file) return;

        const title = file.name.replace('.txt', '');
        if (!confirm(`Import "${title}" and create chapters automatically?`)) return;

        const reader = new FileReader();
        reader.onload = async (event) => {
            const fullText = event.target.result;
            const chapters = this.parseChapters(fullText);

            try {
                // 1. Create the Book
                const formData = new FormData();
                formData.append('title', title);
                formData.append('description', `Imported from ${file.name}`);
                const book = await this.fetchAPI('/core/books/', { method: 'POST', body: formData });

                // 2. Create Chapters
                for (let i = 0; i < chapters.length; i++) {
                    const chap = chapters[i];
                    const chapData = new FormData();
                    chapData.append('title', chap.title);
                    chapData.append('content', chap.content);
                    chapData.append('order', i);
                    await this.fetchAPI(`/core/books/${book.id}/chapters/`, { method: 'POST', body: chapData });
                }

                alert(`Successfully imported "${title}" with ${chapters.length} chapters! 🚀`);
                this.loadDashboard();
            } catch (err) {
                alert(`Import failed: ${err.message}`);
            }
        };
        reader.readAsText(file);
    }

    parseChapters(text) {
        // Look for "Chapter X" or "CHAPTER X" or "chapter X"
        const chapterRegex = /(?:^|\n)\s*(?:Chapter|CHAPTER|chapter)\s+(\d+|[IVX]+|[A-Z]+).*\n/g;
        const matches = [...text.matchAll(chapterRegex)];

        if (matches.length === 0) {
            // No chapter markers found, treat whole file as one chapter
            return [{ title: 'Chapter 1', content: text }];
        }

        const results = [];
        for (let i = 0; i < matches.length; i++) {
            const start = matches[i].index;
            const end = (i + 1 < matches.length) ? matches[i + 1].index : text.length;
            const rawTitle = matches[i][0].trim();
            const content = text.substring(start + matches[i][0].length, end).trim();

            results.push({
                title: rawTitle,
                content: content
            });
        }
        return results;
    }

    async loadAnalyticsData() {
        try {
            const data = await this.fetchAPI('/core/books/my_books/');
            const books = data?.results || data;
            let totalReads = 0;
            let totalLikes = 0;
            let totalDownloads = 0;

            const tableBody = document.getElementById('analytics-table-body');
            tableBody.innerHTML = '';

            books.forEach(book => {
                totalReads += (book.total_reads || 0);
                totalLikes += (book.likes_count || 0);
                totalDownloads += (book.downloads_count || 0);

                const tr = document.createElement('tr');
                tr.style.borderBottom = '1px solid var(--border-color)';
                tr.innerHTML = `
                    <td style="padding: 16px 8px;">
                        <div style="font-weight: 600;">${escapeHTML(book.title)}</div>
                        <div style="font-size: 11px; color: var(--text-secondary);">${escapeHTML(book.category_name) || 'Uncategorized'}</div>
                    </td>
                    <td style="padding: 16px 8px; font-weight: 700;">${book.total_reads || 0}</td>
                    <td style="padding: 16px 8px;">${book.likes_count || 0}</td>
                    <td style="padding: 16px 8px;">${book.downloads_count || 0}</td>
                    <td style="padding: 16px 8px;">
                        <span style="padding: 4px 10px; border-radius: 20px; font-size: 11px; font-weight: 700; ${book.is_published ? 'background: #DCFCE7; color: #166534;' : 'background: #F3F4F6; color: #374151;'}">
                            ${book.is_published ? 'Published' : 'Draft'}
                        </span>
                    </td>
                `;
                tableBody.appendChild(tr);
            });

            document.getElementById('total-reads').textContent = totalReads;
            document.getElementById('total-likes').textContent = totalLikes;
            document.getElementById('total-downloads').textContent = totalDownloads;

        } catch (e) {
            console.error('Analytics Error:', e);
        }
    }

    /* ======== EXPLORE VIEW ======== */
    async loadExploreData() {
        const grid = document.getElementById('explore-grid');
        grid.innerHTML = '<div class="skeleton-card"></div><div class="skeleton-card"></div><div class="skeleton-card"></div>';

        try {
            this.allExploreBooks = await this.fetchAPI('/core/books/');
            this.renderExploreGrid(this.allExploreBooks);
        } catch (e) {
            console.error(e);
            grid.innerHTML = '<p>Error loading stories.</p>';
        }
    }

    setExploreCategory(cat) {
        this.currentExploreCategory = cat;
        // Update UI
        document.querySelectorAll('.cat-chip').forEach(chip => {
            chip.classList.toggle('active', chip.textContent === (cat || 'All'));
        });
        this.filterExplore();
    }

    filterExplore() {
        const query = document.getElementById('explore-search').value.toLowerCase();
        const filtered = this.allExploreBooks.filter(book => {
            const matchesQuery = book.title.toLowerCase().includes(query) ||
                book.author_name.toLowerCase().includes(query) ||
                (book.tags && book.tags.toLowerCase().includes(query));
            const matchesCat = !this.currentExploreCategory || book.category_name === this.currentExploreCategory;
            return matchesQuery && matchesCat && book.is_published;
        });
        this.renderExploreGrid(filtered);
    }

    renderExploreGrid(books) {
        const grid = document.getElementById('explore-grid');
        if (!books || books.length === 0) {
            grid.innerHTML = '<p style="grid-column: 1/-1; text-align: center; padding: 40px;">No stories found match your search.</p>';
            return;
        }

        grid.innerHTML = books.map(book => {
            const coverUrl = this.getMediaUrl(book.cover);
            return `
                <div class="story-card">
                    <div class="story-card-img">
                        <img src="${coverUrl}" alt="cover">
                    </div>
                    <div class="story-info-meta">
                        <div class="story-card-title">${book.title}</div>
                        <div class="story-card-subtitle">by ${book.author_name}${book.author_is_verified ? ' <svg width="14" height="14" fill="#00D2FF" style="vertical-align: text-bottom; margin-left: 2px;" viewBox="0 0 24 24"><path d="M9 16.172l-4.172-4.172-1.414 1.414L9 19 21 7l-1.414-1.414L9 16.172z"/></svg>' : ''}</div>
                        <div style="margin-top: 8px; font-size: 11px; color: var(--text-secondary);">
                            ${book.total_reads} reads • ${book.likes_count} likes
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }
}

// Global initialization
const app = new SrishtyApp();
