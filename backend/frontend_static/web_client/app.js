const API_URL = (window.location.origin.includes('localhost') || window.location.origin.includes('127.0.0.1') || window.location.protocol === 'file:') ? 'http://127.0.0.1:8000/api' : 'https://srishty-backend.onrender.com/api';

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
        this.token = localStorage.getItem('studio_access');
        this.currentUser = localStorage.getItem('username');
        this.currentView = 'home';
        this.isSignUpMode = false;
        this.quill = null;
        this.successAnimation = null;

        // Studio State
        this.currentStoryId = null;
        this.currentChapters = [];
        this.currentChapterId = null;
        this.allExploreBooks = [];
        this.currentExploreCategory = null;
        this.initTheme();

        // Wait for DOM to be ready before init
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.init());
        } else {
            this.init();
        }

        this.currentStoryCharacters = [];
        this.currentStoryRelationships = [];
        this.charNetwork = null;
        this.currentSprint = null;
        this.wordsWrittenAtSprintStart = 0;
        this.sprintPoller = null;
    }

    initTheme() {
        const savedTheme = localStorage.getItem('srishty_theme') || 'light';
        if (savedTheme === 'dark') {
            document.body.classList.add('dark-mode');
            setTimeout(() => this.updateThemeIcons(true), 100);
        }
    }

    toggleTheme() {
        const isDark = document.body.classList.toggle('dark-mode');
        localStorage.setItem('srishty_theme', isDark ? 'dark' : 'light');
        this.updateThemeIcons(isDark);
    }

    updateThemeIcons(isDark) {
        const sun = document.getElementById('theme-icon-sun');
        const moon = document.getElementById('theme-icon-moon');
        if (sun && moon) {
            if (isDark) {
                sun.classList.remove('hidden');
                moon.classList.add('hidden');
            } else {
                sun.classList.add('hidden');
                moon.classList.remove('hidden');
            }
        }
    }

    async init() {
        console.log('App: Initializing Srishty Studio PRO...');
        try {
            this.checkAuth();
            this.setupQuill();
            this.fetchCategories();
            this.initDropZones();
        } catch (e) {
            console.error('CRITICAL INIT ERROR:', e);
            alert('Studio Init Error: ' + e.message);
        }
    }

    initDropZones() {
        ['create-drop-zone', 'settings-drop-zone'].forEach(id => {
            const zone = document.getElementById(id);
            if (!zone) return;

            const input = zone.querySelector('input[type="file"]');
            const preview = zone.querySelector('.drop-zone-preview');

            ['dragover', 'dragleave', 'drop'].forEach(evt => {
                zone.addEventListener(evt, e => {
                    e.preventDefault();
                    e.stopPropagation();
                });
            });

            zone.addEventListener('dragover', () => zone.classList.add('over'));
            zone.addEventListener('dragleave', () => zone.classList.remove('over'));
            zone.addEventListener('drop', e => {
                zone.classList.remove('over');
                const files = e.dataTransfer.files;
                if (files.length) {
                    input.files = files;
                    this.handleFilePreview(files[0], preview);
                }
            });

            input.addEventListener('change', () => {
                if (input.files.length) {
                    this.handleFilePreview(input.files[0], preview);
                }
            });
        });
    }

    handleFilePreview(file, previewImg) {
        if (!file || !previewImg) return;
        const reader = new FileReader();
        reader.onload = e => {
            previewImg.src = e.target.result;
            previewImg.classList.remove('hidden');
        };
        reader.readAsDataURL(file);
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

        const toolbarOptions = [
            [{ 'header': [1, 2, 3, false] }],
            ['bold', 'italic', 'underline', 'strike'],
            ['blockquote', 'image'],
            [{ 'list': 'ordered' }, { 'list': 'bullet' }],
            ['clean']
        ];

        this.quill = new Quill('#editor-container', {
            theme: 'snow',
            modules: { toolbar: toolbarOptions },
            placeholder: 'Start writing your masterpiece...'
        });

        // Story Bible Editor
        if (document.getElementById('bible-editor')) {
            this.bibleQuill = new Quill('#bible-editor', {
                theme: 'snow',
                placeholder: 'Character profiles, world-building notes...',
                modules: { 
                    toolbar: {
                        container: toolbarOptions,
                        container: '#bible-editor-toolbar'
                    }
                }
            });
            
            this.bibleQuill.on('text-change', () => {
                this.debouncedSaveBible();
            });
        }

        this.quill.on('text-change', () => {
            const text = this.quill.getText().trim();
            const count = text.length > 0 ? text.split(/\s+/).length : 0;
            const wordCountEl = document.getElementById('word-count');
            if (wordCountEl) wordCountEl.textContent = `${count.toLocaleString()} words`;

            // Update real-time progress bar if we have session data
            if (this.dailyStats) {
                const sessionWords = Math.max(0, count - (this.chapterInitialWords || 0));
                this.updateWritingProgress(this.dailyStats.today_words + sessionWords);
            }

            // Debounced Auto-save
            if (this.currentChapterId) {
                if (this.autoSaveTimeout) clearTimeout(this.autoSaveTimeout);
                this.autoSaveTimeout = setTimeout(() => {
                    this.saveCurrentChapter(true); // silent = true
                    this.fetchWritingStats(); // Refresh stats after save
                }, 2000);
            }
        });

        this.debouncedSaveBible = this.debounce(() => this.saveBible(), 2000);
    }

    debounce(func, timeout = 300) {
        let timer;
        return (...args) => {
            clearTimeout(timer);
            timer = setTimeout(() => { func.apply(this, args); }, timeout);
        };
    }

    /* ======== API & AUTH ======== */
    async fetchAPI(endpoint, options = {}) {
        const url = endpoint.startsWith('http') ? endpoint : `${API_URL}${endpoint}`;
        const headers = { ...options.headers };
        if (this.token) headers['Authorization'] = `Bearer ${this.token}`;

        try {
            const response = await axios({
                url,
                method: options.method || 'GET',
                data: options.body instanceof FormData ? options.body : (options.body ? JSON.parse(options.body) : null),
                headers
            });
            return response.data;
        } catch (err) {
            console.error('API Error:', err);
            if (err.response?.status === 401 && this.token) {
                this.logout();
            }
            const msg = err.response?.data?.detail || err.response?.data?.error || err.message;
            throw new Error(msg);
        }
    }

    checkAuth() {
        const gw = document.getElementById('auth-section') || document.getElementById('auth-gateway');
        const shell = document.getElementById('app-section') || document.getElementById('app-shell');

        console.log('App: Checking auth status...', this.token ? 'Logged In' : 'Logged Out');

        if (!this.token) {
            if (gw) gw.classList.remove('hidden');
            if (shell) shell.classList.add('hidden');
        } else {
            if (gw) gw.classList.add('hidden');
            if (shell) shell.classList.remove('hidden');

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

    async handleAuth(typeOrEvent) {
        let type = this.isSignUpMode ? 'register' : 'login';
        if (typeof typeOrEvent === 'string') {
            type = typeOrEvent;
            this.isSignUpMode = (type === 'register');
        } else if (typeOrEvent && typeOrEvent.preventDefault) {
            typeOrEvent.preventDefault();
            typeOrEvent.stopPropagation();
        }

        const userField = document.getElementById(type === 'login' ? 'login-username' : 'reg-username') || document.getElementById('auth-user');
        const passField = document.getElementById(type === 'login' ? 'login-password' : 'reg-password') || document.getElementById('auth-pass');
        const emailField = document.getElementById('reg-email') || document.getElementById('auth-email');
        const errorEl = document.getElementById('auth-error');
        const btn = document.getElementById(type === 'login' ? 'auth-btn-login' : 'auth-btn-reg') || document.getElementById('auth-btn');

        if (!userField || !passField) {
            console.error('Auth fields missing in DOM');
            return;
        }

        const user = userField.value;
        const pass = passField.value;

        if (btn) {
            btn.dataset.originalText = btn.textContent;
            btn.textContent = 'Authenticating...';
            btn.disabled = true;
        }
        if (errorEl) errorEl.style.display = 'none';

        try {
            console.log('Auth: Starting authentication for', user, 'Mode:', type);
            if (type === 'register') {
                const email = emailField ? emailField.value : '';
                console.log('Auth: Registering email', email);
                await this.fetchAPI('/accounts/auth/register/', {
                    method: 'POST',
                    body: JSON.stringify({ 
                        username: user, 
                        email: email, 
                        password: pass,
                        role: 'author'
                    })
                });
                console.log('Auth: Registration successful!');
            }

            console.log('Auth: Fetching JWT token...');
            const res = await axios.post(`${API_URL}/token/`, { username: user, password: pass });
            const data = res.data;
            console.log('Auth: Token received!');

            this.token = data.access;
            this.currentUser = user;
            localStorage.setItem('studio_access', data.access);
            localStorage.setItem('studio_refresh', data.refresh);
            localStorage.setItem('username', user);

            this.checkAuth();
        } catch (err) {
            console.error('Auth failure:', err);
            let errorMsg = 'Unknown error';
            if (err.response?.data) {
                if (typeof err.response.data === 'string') {
                    errorMsg = err.response.data;
                } else if (err.response.data.detail) {
                    errorMsg = err.response.data.detail;
                } else {
                    errorMsg = Object.entries(err.response.data)
                        .map(([field, msgs]) => `${field}: ${Array.isArray(msgs) ? msgs.join(' ') : msgs}`)
                        .join('\n');
                }
            } else {
                errorMsg = err.message;
            }

            if (errorEl) {
                errorEl.style.display = 'block';
                errorEl.textContent = errorMsg;
            }
            alert('Authentication Failed:\n' + errorMsg);
        } finally {
            if (btn) {
                btn.textContent = btn.dataset.originalText || (this.isSignUpMode ? 'Register' : 'Sign In');
                btn.disabled = false;
            }
        }
    }

    toggleAuth(e) {
        if (e && e.preventDefault) e.preventDefault();
        this.isSignUpMode = !this.isSignUpMode;
        
        const loginForm = document.getElementById('login-form');
        const regForm = document.getElementById('register-form');
        
        if (loginForm && regForm) {
            loginForm.classList.toggle('hidden', this.isSignUpMode);
            regForm.classList.toggle('hidden', !this.isSignUpMode);
        }
    }

    logout() {
        this.token = null;
        this.currentUser = null;
        localStorage.removeItem('studio_access');
        localStorage.removeItem('studio_refresh');
        localStorage.removeItem('username');
        this.checkAuth();
    }

    /* ======== VIEW ROUTING ======== */
    showTab(tabName) {
        console.log('App: Switching to tab', tabName);
        const viewName = tabName === 'my-stories' ? 'home' : tabName;
        this.switchView(viewName);
    }

    switchView(viewName) {
        console.log('App: Switching view to', viewName);
        
        // Handle both 'view-*' (old) and 'tab-*' (new) IDs
        const possibleIds = [`view-${viewName}`, `tab-${viewName}`];
        if (viewName === 'home') possibleIds.push('tab-my-stories');

        document.querySelectorAll('.view-content, [id^="tab-"], [id^="view-"]').forEach(el => {
            if (el.id && (el.id.startsWith('tab-') || el.id.startsWith('view-'))) {
                el.classList.add('hidden');
                el.style.opacity = '0';
            }
        });

        let activeView = null;
        for (const id of possibleIds) {
            activeView = document.getElementById(id);
            if (activeView) break;
        }

        if (activeView) {
            activeView.classList.remove('hidden');
            setTimeout(() => {
                activeView.style.opacity = '1';
            }, 50);
        }

        this.currentView = viewName;

        // Update Nav Active State
        document.querySelectorAll('.nav-link').forEach(link => {
            link.classList.remove('active');
        });

        if (viewName === 'home') document.getElementById('nav-home')?.classList.add('active');
        if (viewName === 'analytics') document.getElementById('nav-analytics')?.classList.add('active');
        if (viewName === 'comments') document.getElementById('nav-comments')?.classList.add('active');
        if (viewName === 'bible') document.getElementById('nav-bible')?.classList.add('active');
        if (viewName === 'achievements') document.getElementById('nav-achievements')?.classList.add('active');

        if (viewName === 'home') {
            this.loadDashboard();
            document.getElementById('nav-bible')?.classList.add('hidden');
        }
        if (viewName === 'explore') {
            this.loadExploreData();
            document.getElementById('nav-bible')?.classList.add('hidden');
        }
        if (viewName === 'create') this.resetCreateForm();
        if (viewName === 'analytics') this.loadAnalyticsData();
        if (viewName === 'comments') this.loadCommentsView();
        if (viewName === 'bible') this.loadBibleView();
        if (viewName === 'achievements') this.loadAchievementsView();
    }

    /* ======== COMMENTS HUB (Feedback) ======== */
    async loadCommentsView() {
        const list = document.getElementById('comments-hub-list');
        list.innerHTML = `<p style="text-align: center; color: var(--text-secondary); padding: 40px;">Checking for new feedback...</p>`;

        try {
            const comments = await this.fetchAPI('/social/comments/author_comments/');
            
            if (!comments || comments.length === 0) {
                list.innerHTML = `
                    <div style="text-align: center; padding: 60px; background: white; border-radius: 24px; border: 1px solid var(--border-color);">
                        <div style="font-size: 48px; margin-bottom: 16px;">💬</div>
                        <h3>No feedback yet</h3>
                        <p style="color: var(--text-secondary);">When readers comment on your stories, they will appear here.</p>
                    </div>
                `;
                return;
            }

            list.innerHTML = comments.map(comment => {
                const date = new Date(comment.created_at).toLocaleDateString();
                const bookTitle = comment.book_title || 'Your Story';
                const chapterTitle = comment.chapter_title ? ` - ${comment.chapter_title}` : '';
                
                let repliesHtml = '';
                if (comment.replies && comment.replies.length > 0) {
                    repliesHtml = `
                        <div class="comment-replies" style="margin-left: 40px; margin-top: 15px; border-left: 2px solid var(--accent-primary); padding-left: 15px;">
                            ${comment.replies.map(r => `
                                <div class="reply-item" style="margin-bottom: 10px; font-size: 13px;">
                                    <strong>${r.username}</strong> <span style="opacity: 0.6; font-size: 11px;">${new Date(r.created_at).toLocaleDateString()}</span>
                                    <p style="margin-top: 4px;">${escapeHTML(r.text)}</p>
                                </div>
                            `).join('')}
                        </div>
                    `;
                }

                return `
                    <div class="comment-card" style="background: white; padding: 24px; border-radius: 20px; box-shadow: var(--shadow-sm); border: 1px solid var(--border-color);">
                        <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px;">
                            <div style="display: flex; gap: 12px; align-items: center;">
                                <div style="width: 40px; height: 40px; background: var(--accent-primary); color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: bold;">
                                    ${comment.username.substring(0,2).toUpperCase()}
                                </div>
                                <div>
                                    <div style="font-weight: 700;">${comment.username}</div>
                                    <div style="font-size: 12px; color: var(--text-secondary);">On <strong>${escapeHTML(bookTitle)}${escapeHTML(chapterTitle)}</strong> • ${date}</div>
                                </div>
                            </div>
                            <button class="btn-quiet" onclick="app.showReplyInput(${comment.id})">Reply</button>
                        </div>
                        <p style="font-size: 15px; line-height: 1.6;">${escapeHTML(comment.text)}</p>
                        
                        <div id="reply-input-${comment.id}" class="hidden" style="margin-top: 20px; border-top: 1px solid var(--border-color); padding-top: 20px;">
                            <textarea id="reply-text-${comment.id}" class="form-input" placeholder="Type your reply..." rows="2"></textarea>
                            <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
                                <button class="btn-outline" style="padding: 6px 15px; font-size: 12px;" onclick="app.showReplyInput(${comment.id}, false)">Cancel</button>
                                <button class="btn-primary" style="padding: 6px 15px; font-size: 12px;" onclick="app.submitReply(${comment.id}, ${comment.book}, ${comment.chapter || 'null'})">Send Reply</button>
                            </div>
                        </div>

                        ${repliesHtml}
                    </div>
                `;
            }).join('');

        } catch (err) {
            console.error('Comments Error:', err);
            list.innerHTML = `<p style="text-align: center; color: var(--danger);">Failed to load feedback.</p>`;
        }
    }

    showReplyInput(id, show = true) {
        const el = document.getElementById(`reply-input-${id}`);
        if (el) el.classList.toggle('hidden', !show);
    }

    async submitReply(parentId, bookId, chapterId) {
        const textEl = document.getElementById(`reply-text-${parentId}`);
        const text = textEl.value.trim();
        if (!text) return;

        try {
            await this.fetchAPI('/social/comments/', {
                method: 'POST',
                body: JSON.stringify({
                    book: bookId,
                    chapter: chapterId,
                    text: text,
                    parent: parentId
                })
            });
            this.showSuccessAnimation();
            this.loadCommentsView();
        } catch (err) {
            alert('Failed to send reply.');
        }
    }

    getMediaUrl(path) {
        if (!path) return 'https://placehold.co/400x600/E2E8F0/64748B?text=Cover+Not+Found';
        if (path.startsWith('http')) return path;
        const backendOrigin = API_URL.replace('/api', '').replace(/\/$/, '');
        const cleanPath = path.startsWith('/') ? path : `/${path}`;
        return `${backendOrigin}${cleanPath}`;
    }

    /* ======== DASHBOARD ======== */
    async loadDashboard() {
        const grid = document.getElementById('story-grid');
        // Load Writing Stats
        this.fetchWritingStats();

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

        const coverFile = document.getElementById('create-cover');
        const audioFile = document.getElementById('create-audio');
        const importFile = document.getElementById('create-import-file').files[0];

        if (this.designedCoverFileCreate) {
            formData.append('cover', this.designedCoverFileCreate);
            this.designedCoverFileCreate = null;
        } else if (coverFile.files[0]) {
            formData.append('cover', coverFile.files[0]);
        }

        if (audioFile.files[0]) formData.append('audio_file', audioFile.files[0]);

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
            this.showSuccessAnimation();
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
        document.getElementById('nav-bible').classList.remove('hidden');
        this.quill.setText('Loading chapter...\n');

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('editor-story-title').textContent = book.title;
            this.currentChapters = book.chapters || [];
            this.fetchWritingStats();

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
            div.setAttribute('data-id', ch.id);
            const premiumIcon = ch.is_premium ? `<span title="Premium Chapter" style="font-size: 10px; margin-left: 4px;">🔒</span>` : '';
            div.innerHTML = `
                <div style="display: flex; align-items: center; gap: 10px; width: 100%;">
                    <svg style="cursor: grab; color: var(--text-secondary);" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M4 8h16M4 16h16"/></svg>
                    <span style="flex: 1;">${escapeHTML(ch.title) || 'Chapter ' + (idx + 1)}${premiumIcon}</span>
                </div>
            `;
            div.onclick = (e) => {
                // Don't switch if dragging handle
                if (e.target.closest('svg')) return;
                this.loadSelectedChapter(ch.id);
            };
            list.appendChild(div);
        });

        this.initSortable();
    }

    initSortable() {
        const list = document.getElementById('sidebar-chapter-list');
        if (!list) return;

        if (this.sortable) this.sortable.destroy();

        this.sortable = new Sortable(list, {
            animation: 150,
            handle: 'svg', // Drag handle
            ghostClass: 'sortable-ghost',
            onEnd: async (evt) => {
                const chapterIds = Array.from(list.querySelectorAll('.chapter-item')).map(el => parseInt(el.getAttribute('data-id')));
                
                // Update local state first for immediate feedback
                const reordered = chapterIds.map(id => this.currentChapters.find(c => c.id === id));
                this.currentChapters = reordered;

                // Sync with backend
                try {
                    const statusText = document.getElementById('save-status');
                    statusText.textContent = 'Updating Order...';
                    
                    // We send the new order to the backend. 
                    // To be efficient, we can send a batch update or just iterate.
                    // For now, let's iterate and update the 'order' field.
                    for (let i = 0; i < this.currentChapters.length; i++) {
                        const chapter = this.currentChapters[i];
                        await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${chapter.id}/`, {
                            method: 'PATCH',
                            body: JSON.stringify({ order: i })
                        });
                    }
                    statusText.textContent = 'Order Saved';
                    statusText.style.color = '#10B981';
                } catch (err) {
                    console.error('Failed to reorder:', err);
                    alert('Failed to save new chapter order.');
                    this.renderChapterList(); // Revert UI
                }
            }
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
        
        const text = this.quill.getText().trim();
        this.chapterInitialWords = text ? text.split(/\s+/).length : 0;
        
        document.getElementById('editor-chapter-label').textContent = chapterObj.title || 'Untitled Chapter';
        
        // Audiobook Player
        const audioContainer = document.getElementById('chapter-audio-container');
        const audioPlayer = document.getElementById('chapter-audio-player');
        if (chapterObj.audio_file) {
            audioPlayer.src = this.getMediaUrl(chapterObj.audio_file);
            audioContainer.classList.remove('hidden');
        } else {
            audioContainer.classList.add('hidden');
        }

        // Premium fields
        const premiumToggle = document.getElementById('chapter-is-premium');
        const coinsInput = document.getElementById('chapter-coins');
        if (premiumToggle && coinsInput) {
            premiumToggle.checked = chapterObj.is_premium || false;
            coinsInput.value = chapterObj.coins_required || 0;
            this.togglePremiumInput(premiumToggle.checked);
        }
    }

    togglePremiumInput(isPremium) {
        const coinsInput = document.getElementById('chapter-coins');
        if (coinsInput) coinsInput.classList.toggle('hidden', !isPremium);
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
        document.getElementById('branching-panel').classList.add('hidden');
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

    async saveCurrentChapter(silent = false) {
        const content = this.quill.root.innerHTML;
        const textContent = this.quill.getText().trim();
        if (!textContent) return; // Don't save empty

        const saveBtn = document.getElementById('save-indicator');
        const statusText = document.getElementById('save-status');
        saveBtn.textContent = 'Saving...';
        statusText.textContent = 'Saving...';

        const label = document.getElementById('editor-chapter-label').textContent;
        const isPremium = document.getElementById('chapter-is-premium').checked;
        const coins = document.getElementById('chapter-coins').value || 0;

        const formData = new FormData();
        formData.append('title', label === 'New Chapter' ? `Chapter ${this.currentChapters.length + 1}` : label);
        formData.append('content', content);
        formData.append('is_premium', isPremium);
        formData.append('coins_required', coins);

        try {
            if (this.currentChapterId) {
                await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/`, {
                    method: 'PATCH',
                    body: formData
                });
                const idx = this.currentChapters.findIndex(c => c.id === this.currentChapterId);
                if (idx !== -1) {
                    this.currentChapters[idx].content = content;
                    this.currentChapters[idx].is_premium = isPremium;
                    this.currentChapters[idx].coins_required = coins;
                }
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
            statusText.textContent = silent ? 'Saved Automatically' : 'Saved';
            statusText.style.color = '#10B981';
            
            // Only refresh sidebar if it's a manual save (for new chapter names)
            if (!silent) this.renderChapterList();
        } catch (e) {
            console.error('Save Error:', e);
            statusText.textContent = 'Save Failed';
            statusText.style.color = 'var(--danger)';
            if (!silent) alert(`Failed to save: ${e.message}`);
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
            this.showSuccessAnimation();
            this.switchView('home');
        } catch (e) {
            alert(`Failed to publish: ${e.message}`);
        }
    }

    async handleChapterAudioUpload(input) {
        const file = input.files[0];
        if (!file || !this.currentChapterId) return;

        const statusText = document.getElementById('save-status');
        statusText.textContent = 'Uploading audio...';

        const formData = new FormData();
        formData.append('audio_file', file);

        // Find chapter number (1-indexed) based on order (0-indexed)
        const chapter = this.currentChapters.find(c => c.id === this.currentChapterId);
        if (!chapter) return;
        formData.append('chapter_number', chapter.order + 1);

        try {
            const res = await this.fetchAPI(`/core/books/${this.currentStoryId}/upload_audio/`, {
                method: 'POST',
                body: formData
            });
            statusText.textContent = 'Audio Uploaded';
            statusText.style.color = '#10B981';
            
            // Update local state and player
            const chapter = this.currentChapters.find(c => c.id === this.currentChapterId);
            if (chapter) {
                chapter.audio_file = res.url;
                this.loadChapterContent(chapter); // Refresh player
            }
            alert('Chapter audio uploaded successfully!');
        } catch (e) {
            console.error('Audio Upload Error:', e);
            statusText.textContent = 'Upload Failed';
            statusText.style.color = 'var(--danger)';
            alert(`Failed to upload audio: ${e.message}`);
        }
    }

    /* ======== SETTINGS VIEW ======== */
    async openSettings(bookId) {
        if (!bookId) bookId = this.currentStoryId;
        if (!bookId) return;

        this.currentStoryId = bookId;
        this.switchView('settings');
        document.getElementById('nav-bible').classList.remove('hidden');

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('settings-title').value = book.title;
            document.getElementById('settings-desc').value = book.description;
            document.getElementById('settings-status').value = book.is_published ? 'published' : 'draft';

            const preview = document.getElementById('settings-cover-preview');
            const coverUrl = this.getMediaUrl(book.cover);
            if (coverUrl) {
                preview.src = coverUrl;
                preview.classList.remove('hidden');
            } else {
                preview.classList.add('hidden');
            }

            const audioLabel = document.getElementById('settings-audio-label');
            const audioPlayer = document.getElementById('settings-audio-player');
            if (book.audio_file) {
                const url = this.getMediaUrl(book.audio_file);
                audioPlayer.src = url;
                audioPlayer.classList.remove('hidden');
                audioLabel.textContent = 'Currently uploaded audiobook';
            } else {
                audioPlayer.classList.add('hidden');
                audioLabel.textContent = 'No audiobook uploaded';
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

        const coverFile = document.getElementById('settings-cover');
        if (this.designedCoverFileSettings) {
            formData.append('cover', this.designedCoverFileSettings);
            this.designedCoverFileSettings = null;
        } else if (coverFile && coverFile.files[0]) {
            formData.append('cover', coverFile.files[0]);
        }

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
                this.showSuccessAnimation();
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
                    <td style="padding: 16px 8px; font-weight: 700; color: var(--accent-primary); cursor: pointer;" onclick="app.showBookRetention(${book.id}, '${escapeHTML(book.title)}')">View Retention</td>
                    <td style="padding: 16px 8px;">
                        <span style="padding: 4px 10px; border-radius: 20px; font-size: 11px; font-weight: 700; ${book.is_published ? 'background: #DCFCE7; color: #166534;' : 'background: #F3F4F6; color: #374151;'}">
                            ${book.is_published ? 'Published' : 'Draft'}
                        </span>
                    </td>
                `;
                tableBody.appendChild(tr);
            });

            document.getElementById('total-reads').textContent = totalReads.toLocaleString();
            document.getElementById('total-likes').textContent = totalLikes.toLocaleString();
            document.getElementById('total-downloads').textContent = totalDownloads.toLocaleString();

            if (books.length > 0) {
                this.showBookRetention(books[0].id, books[0].title);
            }

        } catch (e) {
            console.error('Analytics Error:', e);
        }
    }

    async showBookRetention(bookId, title) {
        try {
            const stats = await this.fetchAPI(`/core/books/${bookId}/retention_stats/`);
            if (!stats || !Array.isArray(stats)) return;

            const labels = stats.map(s => s.title);
            const data = stats.map(s => s.reads_count);

            const ctx = document.getElementById('retentionChart').getContext('2d');
            if (this.retentionChart) this.retentionChart.destroy();

            const isDark = document.body.classList.contains('dark-mode');
            const gridColor = isDark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)';
            const textColor = isDark ? '#94A3B8' : '#64748B';

            this.retentionChart = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Readers per Chapter',
                        data: data,
                        borderColor: '#6366F1',
                        backgroundColor: 'rgba(99, 102, 241, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4,
                        pointBackgroundColor: '#6366F1',
                        pointRadius: 4
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            grid: { color: gridColor },
                            ticks: { color: textColor }
                        },
                        x: {
                            grid: { display: false },
                            ticks: { color: textColor }
                        }
                    }
                }
            });
        } catch (e) { console.error('Retention Stats Error:', e); }
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
                        <div class="story-card-title">${escapeHTML(book.title)}</div>
                        <div class="story-card-subtitle">by ${escapeHTML(book.author_name)}${book.author_is_verified ? ' <svg width="14" height="14" fill="#00D2FF" style="vertical-align: text-bottom; margin-left: 2px;" viewBox="0 0 24 24"><path d="M9 16.172l-4.172-4.172-1.414 1.414L9 19 21 7l-1.414-1.414L9 16.172z"/></svg>' : ''}</div>
                        <div style="margin-top: 8px; font-size: 11px; color: var(--text-secondary);">
                            ${book.total_reads} reads • ${book.likes_count} likes
                        </div>
                    </div>
                </div>
            `;
        }).join('');
    }

    showSuccessAnimation() {
        const overlay = document.getElementById('success-overlay');
        overlay.style.display = 'flex';
        
        if (!this.successAnimation) {
            this.successAnimation = lottie.loadAnimation({
                container: document.getElementById('success-lottie'),
                renderer: 'svg',
                loop: false,
                autoplay: true,
                path: 'https://assets10.lottiefiles.com/packages/lf20_pqnfmone.json'
            });
        } else {
            this.successAnimation.goToAndPlay(0, true);
        }

        setTimeout(() => {
            overlay.style.opacity = '0';
            setTimeout(() => {
                overlay.style.display = 'none';
                overlay.style.opacity = '1';
            }, 500);
        }, 2500);
    }

    /* ======== STORY BIBLE ======== */
    async loadBibleView() {
        if (!this.currentStoryId) return;
        const status = document.getElementById('bible-save-status');
        status.textContent = 'Loading notes...';

        try {
            const bible = await this.fetchAPI(`/core/story-bible/get_by_book/?book_id=${this.currentStoryId}`);
            if (bible && bible.content) {
                this.bibleQuill.root.innerHTML = bible.content;
            } else {
                this.bibleQuill.setText('');
            }
            status.textContent = 'Ready';
        } catch (e) {
            console.error('Bible Load Error:', e);
            status.textContent = 'Error loading notes';
        }
    }

    async saveBible() {
        if (!this.currentStoryId) return;
        const status = document.getElementById('bible-save-status');
        status.textContent = 'Saving notes...';
        status.style.color = 'var(--text-secondary)';

        try {
            // First get the bible to ensure we have the ID or create it
            const bible = await this.fetchAPI(`/core/story-bible/get_by_book/?book_id=${this.currentStoryId}`);
            
            await this.fetchAPI(`/core/story-bible/${bible.id}/`, {
                method: 'PATCH',
                body: JSON.stringify({
                    content: this.bibleQuill.root.innerHTML
                })
            });
            
            status.textContent = 'Saved';
            status.style.color = '#10B981';
        } catch (e) {
            console.error('Bible Save Error:', e);
            status.textContent = 'Save failed';
            status.style.color = 'var(--danger)';
        }
    }

    /* ======== WRITING GOALS & STREAKS ======== */
    async fetchWritingStats() {
        try {
            const stats = await this.fetchAPI('/core/books/writing-stats/');
            this.dailyStats = stats;
            this.updateWritingUI(stats);
        } catch (e) { console.error('Stats Error:', e); }
    }

    updateWritingUI(stats) {
        // Streak Nav
        const streakIndicator = document.getElementById('streak-indicator');
        const streakCount = document.getElementById('streak-count');
        if (stats.current_streak > 0) {
            streakIndicator.classList.remove('hidden');
            streakCount.textContent = stats.current_streak;
        } else {
            streakIndicator.classList.add('hidden');
        }

        // Dashboard Widget
        const dWords = document.getElementById('dashboard-goal-words');
        const dTarget = document.getElementById('dashboard-goal-target');
        const dBar = document.getElementById('dashboard-goal-bar');
        const dPercent = document.getElementById('dashboard-goal-percent');

        if (dWords) {
            dWords.textContent = stats.today_words;
            dTarget.textContent = stats.daily_goal;
            const percent = Math.min(100, Math.floor((stats.today_words / stats.daily_goal) * 100));
            dBar.style.width = `${percent}%`;
            dPercent.textContent = `${percent}%`;
        }

        // Editor Footer
        this.updateWritingProgress(stats.today_words);
    }

    updateWritingProgress(todayTotal) {
        const bar = document.getElementById('editor-goal-bar');
        const text = document.getElementById('editor-goal-text');
        if (bar && this.dailyStats) {
            const percent = Math.min(100, Math.floor((todayTotal / this.dailyStats.daily_goal) * 100));
            bar.style.width = `${percent}%`;
            text.textContent = `${percent}%`;
            
            if (percent >= 100) {
                bar.style.background = '#00D2FF';
                if (!this.goalCelebrated) {
                    this.goalCelebrated = true;
                    this.showGoalToast();
                }
            }
        }
    }

    showGoalToast() {
        const toast = document.createElement('div');
        toast.innerHTML = `
            <div style="position: fixed; top: 80px; right: 20px; background: #00D2FF; color: white; padding: 16px 24px; border-radius: 16px; box-shadow: var(--shadow-lg); z-index: 10000; display: flex; align-items: center; gap: 12px; animation: slideIn 0.5s ease-out;">
                <div style="font-size: 24px;">🎯</div>
                <div>
                    <div style="font-weight: 800; font-size: 16px;">Daily Goal Reached!</div>
                    <div style="font-size: 12px; opacity: 0.9;">You're on fire! Keep going.</div>
                </div>
            </div>
        `;
        document.body.appendChild(toast);
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transition = '0.5s';
            setTimeout(() => toast.remove(), 500);
        }, 4000);
    showLivePreview() {
        if (!this.currentStoryId) {
            alert("Please select a story first.");
            return;
        }

        const modal = document.getElementById('qr-modal');
        const container = document.getElementById('qrcode-container');
        container.innerHTML = ""; // Clear old QR

        // Format: srishty://preview/<book_id>
        const deepLink = `srishty://preview/${this.currentStoryId}`;
        
        new QRCode(container, {
            text: deepLink,
            width: 200,
            height: 200,
            colorDark: "#0F172A",
            colorLight: "#ffffff",
            correctLevel: QRCode.CorrectLevel.H
        });

        modal.classList.remove('hidden');
    }

    showSocialToolkit() {
        const selection = this.quill.getSelection();
        const quote = selection ? this.quill.getText(selection.index, selection.length).trim() : "";
        if (quote) {
            document.getElementById('toolkit-quote').value = quote;
        }

        // Setup preview info
        document.getElementById('card-book-title').textContent = document.getElementById('editor-story-title').textContent;
        document.getElementById('card-author-name').textContent = `by ${document.getElementById('nav-username').textContent}`;
        
        const coverImg = document.getElementById('card-book-cover');
        const bgImg = document.getElementById('card-bg-img');
        
        // Find cover from dashboard cards
        let coverUrl = "";
        const cards = document.querySelectorAll('.story-card');
        cards.forEach(card => {
            const title = card.querySelector('h3')?.textContent;
            if (title === document.getElementById('editor-story-title').textContent) {
                coverUrl = card.querySelector('img').src;
            }
        });

        if (coverUrl) {
            coverImg.src = coverUrl;
            bgImg.src = coverUrl;
        } else {
            coverImg.src = 'https://placehold.co/400x600/E2E8F0/64748B?text=Book+Cover';
            bgImg.src = 'https://placehold.co/400x600/0F172A/ffffff?text=Background';
        }

        this.updateToolkitPreview();
        document.getElementById('toolkit-modal').classList.remove('hidden');
    }

    updateToolkitPreview() {
        const quote = document.getElementById('toolkit-quote').value;
        const template = document.getElementById('toolkit-template').value;
        const renderArea = document.getElementById('card-template-render');
        const quoteText = document.getElementById('card-quote-text');
        const quoteMark = document.getElementById('card-quote-mark');
        const bgImg = document.getElementById('card-bg-img');
        
        quoteText.textContent = quote || "Every story starts with a single word.";
        
        // Reset styles
        renderArea.style.background = "transparent";
        quoteText.style.display = "block";
        quoteMark.style.display = "block";
        bgImg.style.filter = "brightness(0.4) blur(10px)";
        quoteText.style.color = "white";
        document.getElementById('card-book-title').style.color = "white";
        document.getElementById('card-author-name').style.color = "rgba(255,255,255,0.7)";

        if (template === 'glass') {
            renderArea.style.background = "linear-gradient(135deg, rgba(108, 99, 255, 0.8) 0%, rgba(0, 210, 255, 0.8) 100%)";
            bgImg.style.filter = "brightness(0.6) blur(5px)";
        } else if (template === 'bookish') {
            renderArea.style.background = "rgba(255, 255, 255, 0.9)";
            quoteText.style.color = "#0F172A";
            document.getElementById('card-book-title').style.color = "#0F172A";
            document.getElementById('card-author-name').style.color = "#475569";
            bgImg.style.filter = "brightness(1) grayscale(1)";
        } else if (template === 'announcement') {
            quoteMark.style.display = "none";
            quoteText.innerHTML = `<span style="font-size: 44px; font-weight: 900; display: block; margin-bottom: 10px; color: var(--accent-primary);">NEW CHAPTER</span> OUT NOW`;
        }
    }

    async downloadSocialCard() {
        const area = document.getElementById('social-card-canvas');
        const btn = event.currentTarget;
        const originalText = btn.innerHTML;
        btn.innerHTML = "Generating...";
        btn.disabled = true;

        try {
            const canvas = await html2canvas(area, {
                useCORS: true,
                scale: 3, // Ultra high res
                backgroundColor: "#0F172A"
            });
            const link = document.createElement('a');
            link.download = `Srishty_Toolkit_${Date.now()}.png`;
            link.href = canvas.toDataURL('image/png');
            link.click();
        } catch (e) {
            console.error(e);
            alert("Failed to generate image. Please try again.");
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    }

    async showHistory() {
        if (!this.currentChapterId) {
            alert("Please select a chapter first.");
            return;
        }

        const panel = document.getElementById('history-panel');
        const list = document.getElementById('history-list');
        list.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 40px;">Loading history...</p>';
        panel.classList.remove('hidden');

        try {
            const versions = await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/history/`);
            
            if (versions.length === 0) {
                list.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 40px;">No versions found for this chapter.</p>';
                return;
            }

            list.innerHTML = versions.map(v => {
                const date = new Date(v.created_at).toLocaleString();
                return `
                    <div class="history-card" onclick="app.previewVersion(${v.id})">
                        <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
                            <span style="font-weight: 700; font-size: 13px;">${date}</span>
                            <span style="font-size: 11px; background: var(--bg-main); color: var(--accent-primary); padding: 2px 8px; border-radius: 4px; font-weight: 700;">${v.word_count} words</span>
                        </div>
                        <p style="font-size: 12px; color: var(--text-secondary); display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; margin: 0; line-height: 1.5;">
                            ${v.content_preview}
                        </p>
                        <button class="btn-primary" style="width: 100%; margin-top: 15px; height: 36px; font-size: 12px;" onclick="app.restoreVersion(event, ${v.id})">Restore This Version</button>
                    </div>
                `;
            }).join('');
        } catch (e) {
            list.innerHTML = '<p style="text-align: center; color: var(--danger); padding: 40px;">Failed to load history.</p>';
        }
    }

    hideHistory() {
        document.getElementById('history-panel').classList.add('hidden');
    }

    async restoreVersion(event, versionId) {
        event.stopPropagation();
        if (!confirm("Are you sure you want to restore this version? Your current draft will be replaced.")) return;

        try {
            const res = await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/restore_version/`, {
                method: 'POST',
                body: JSON.stringify({ version_id: versionId })
            });
            
            if (res.status === 'restored') {
                try {
                    // Try parsing as Delta (Quill format)
                    const delta = JSON.parse(res.content);
                    this.quill.setContents(delta);
                } catch (e) {
                    // Fallback to HTML
                    this.quill.root.innerHTML = res.content;
                }
                this.hideHistory();
                this.showSuccessAnimation();
                this.saveCurrentChapter(); // Auto-save the restoration as a new version
            }
        } catch (e) {
        }
    }



    openCoverDesigner(context) {
        this.coverDesignerContext = context; // 'create' or 'settings'
        const titleInput = context === 'create' ? 'create-title' : 'settings-title';
        const title = document.getElementById(titleInput).value;
        const author = document.getElementById('nav-username').textContent;
        
        document.getElementById('cover-title-input').value = title;
        document.getElementById('cover-author-input').value = author;
        
        document.getElementById('designer-modal').classList.remove('hidden');
        this.updateCoverDesigner();
    }

    setCoverColor(color) {
        document.getElementById('cover-color-input').value = color;
        this.updateCoverDesigner();
    }

    updateCoverDesigner() {
        const canvas = document.getElementById('cover-canvas');
        if (!canvas) return;
        const ctx = canvas.getContext('2d');
        const template = document.getElementById('cover-template').value;
        const title = document.getElementById('cover-title-input').value || "Your Story Title";
        const author = document.getElementById('cover-author-input').value || "Author Name";
        const color = document.getElementById('cover-color-input').value;

        // Clear
        ctx.fillStyle = "#ffffff";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        if (template === 'minimal') {
            ctx.fillStyle = color;
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            ctx.fillStyle = "white";
            ctx.textAlign = "center";
            ctx.font = "bold 60px sans-serif";
            this.wrapText(ctx, title.toUpperCase(), canvas.width/2, 400, 500, 70);
            
            ctx.font = "30px sans-serif";
            ctx.fillText(author, canvas.width/2, 800);
            
        } else if (template === 'vibrant') {
            const grad = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
            grad.addColorStop(0, color);
            grad.addColorStop(1, "#0F172A");
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            ctx.fillStyle = "white";
            ctx.textAlign = "center";
            ctx.font = "bold 70px sans-serif";
            this.wrapText(ctx, title, canvas.width/2, 350, 500, 80);

            ctx.fillStyle = color;
            ctx.fillRect(canvas.width/2 - 50, 600, 100, 4);

            ctx.fillStyle = "white";
            ctx.font = "italic 30px sans-serif";
            ctx.fillText(`by ${author}`, canvas.width/2, 700);

        } else if (template === 'noir') {
            ctx.fillStyle = "#111827";
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            
            ctx.strokeStyle = color;
            ctx.lineWidth = 20;
            ctx.strokeRect(40, 40, canvas.width - 80, canvas.height - 80);

            ctx.fillStyle = "white";
            ctx.textAlign = "center";
            ctx.font = "900 65px serif";
            this.wrapText(ctx, title, canvas.width/2, 400, 500, 80);

            ctx.font = "bold 25px sans-serif";
            ctx.fillText(author.toUpperCase(), canvas.width/2, 850);
        } else if (template === 'fantasy') {
            ctx.fillStyle = "#0F172A";
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            const radGrad = ctx.createRadialGradient(canvas.width/2, canvas.height/2, 0, canvas.width/2, canvas.height/2, 600);
            radGrad.addColorStop(0, color + "44");
            radGrad.addColorStop(1, "transparent");
            ctx.fillStyle = radGrad;
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            ctx.fillStyle = "white";
            ctx.textAlign = "center";
            ctx.font = "bold 80px serif";
            ctx.shadowColor = color;
            ctx.shadowBlur = 20;
            this.wrapText(ctx, title, canvas.width/2, 450, 600, 90);
            
            ctx.shadowBlur = 0;
            ctx.font = "30px sans-serif";
            ctx.fillText(author, canvas.width/2, 950);
        }
    }

    wrapText(ctx, text, x, y, maxWidth, lineHeight) {
        const words = text.split(' ');
        let line = '';
        for (let n = 0; n < words.length; n++) {
            let testLine = line + words[n] + ' ';
            let metrics = ctx.measureText(testLine);
            let testWidth = metrics.width;
            if (testWidth > maxWidth && n > 0) {
                ctx.fillText(line, x, y);
                line = words[n] + ' ';
                y += lineHeight;
            } else {
                line = testLine;
            }
        }
        ctx.fillText(line, x, y);
    }

    applyDesignedCover() {
        const canvas = document.getElementById('cover-canvas');
        canvas.toBlob((blob) => {
            const file = new File([blob], "designed_cover.png", { type: "image/png" });
            
            const previewId = this.coverDesignerContext === 'create' ? 'create-cover-preview' : 'settings-cover-preview';
            
            if (this.coverDesignerContext === 'create') {
                this.designedCoverFileCreate = file;
            } else {
                this.designedCoverFileSettings = file;
            }

            const preview = document.getElementById(previewId);
            preview.src = canvas.toDataURL();
            preview.classList.remove('hidden');
            
            document.getElementById('designer-modal').classList.add('hidden');
        }, 'image/png');
    }

    toggleBranching() {
        const panel = document.getElementById('branching-panel');
        panel.classList.toggle('hidden');
        if (!panel.classList.contains('hidden')) {
            this.loadBranchingData();
        }
    }

    async loadBranchingData() {
        const targetSelect = document.getElementById('choice-target');
        targetSelect.innerHTML = '<option value="">Select Chapter...</option>' + 
            this.currentChapters
                .filter(ch => ch.id !== this.currentChapterId)
                .map(ch => `<option value="${ch.id}">${ch.title || 'Untitled'}</option>`)
                .join('');

        this.renderChoices();
    }

    renderChoices() {
        const currentChapter = this.currentChapters.find(ch => ch.id === this.currentChapterId);
        const list = document.getElementById('choice-list');
        
        if (!currentChapter || !currentChapter.choices || currentChapter.choices.length === 0) {
            list.innerHTML = '<p style="grid-column: 1/-1; text-align: center; color: var(--text-secondary); padding: 20px;">No paths added yet.</p>';
            return;
        }

        list.innerHTML = currentChapter.choices.map(c => `
            <div style="background: white; border: 1px solid var(--border-color); padding: 16px; border-radius: 12px; display: flex; justify-content: space-between; align-items: center; box-shadow: var(--shadow-sm);">
                <div>
                    <div style="font-weight: 700; font-size: 14px;">"${c.text}"</div>
                    <div style="font-size: 11px; color: var(--accent-primary); font-weight: 600; margin-top: 4px;">➡️ Goes to: ${this.getChapterTitle(c.target_chapter)}</div>
                </div>
                <button class="btn-quiet" style="color: var(--danger); padding: 5px;" onclick="app.removeChoice(${c.id})">
                    <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                </button>
            </div>
        `).join('');
    }

    getChapterTitle(id) {
        const ch = this.currentChapters.find(c => c.id === id);
        return ch ? (ch.title || 'Untitled') : 'Unknown Chapter';
    }

    async addChoice() {
        const text = document.getElementById('choice-text').value;
        const targetId = document.getElementById('choice-target').value;

        if (!text || !targetId) {
            alert("Please provide choice text and select a target chapter.");
            return;
        }

        try {
            const res = await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/add_choice/`, {
                method: 'POST',
                body: JSON.stringify({ text, target_chapter_id: targetId })
            });

            // Update local state
            const ch = this.currentChapters.find(c => c.id === this.currentChapterId);
            if (!ch.choices) ch.choices = [];
            ch.choices.push(res);
            
            document.getElementById('choice-text').value = '';
            this.renderChoices();
            this.showSuccessAnimation();
        } catch (e) {
            alert("Failed to add choice.");
        }
    }

    async removeChoice(choiceId) {
        if (!confirm("Remove this path?")) return;

        try {
            await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/remove_choice/`, {
                method: 'POST',
                body: JSON.stringify({ choice_id: choiceId })
            });

            // Update local state
            const ch = this.currentChapters.find(c => c.id === this.currentChapterId);
            ch.choices = ch.choices.filter(c => c.id !== choiceId);
            this.renderChoices();
        } catch (e) {
            alert("Failed to remove choice.");
        }
    }

    switchBibleTab(tab) {
        document.getElementById('bible-tab-notes').classList.toggle('active', tab === 'notes');
        document.getElementById('bible-tab-characters').classList.toggle('active', tab === 'characters');
        
        document.getElementById('bible-content-notes').classList.toggle('hidden', tab !== 'notes');
        document.getElementById('bible-content-characters').classList.toggle('hidden', tab !== 'characters');
        
        if (tab === 'characters') {
            this.loadCharacterData();
        }
    }

    async loadCharacterData() {
        if (!this.currentStoryId) return;
        
        // Refresh book data to get characters
        const book = await this.fetchAPI(`/core/books/${this.currentStoryId}/`);
        this.currentStoryCharacters = book.characters || [];
        
        const rels = await this.fetchAPI(`/core/books/${this.currentStoryId}/relationships/`);
        this.currentStoryRelationships = rels || [];
        
        this.renderCharacterList();
        this.renderRelationshipList();
        this.renderCharacterGraph();
    }

    renderCharacterList() {
        const list = document.getElementById('bible-character-list');
        if (this.currentStoryCharacters.length === 0) {
            list.innerHTML = '<p style="font-size: 12px; color: var(--text-secondary); text-align: center;">No characters yet.</p>';
            return;
        }

        list.innerHTML = this.currentStoryCharacters.map(char => `
            <div style="display: flex; align-items: center; gap: 10px; background: #F8FAFC; padding: 10px; border-radius: 12px; border: 1px solid var(--border-color);">
                <div style="width: 12px; height: 12px; border-radius: 50%; background: ${char.color}"></div>
                <div style="flex: 1;">
                    <div style="font-size: 13px; font-weight: 700;">${escapeHTML(char.name)}</div>
                    <div style="font-size: 10px; color: var(--text-secondary);">${escapeHTML(char.role) || 'No role'}</div>
                </div>
                <button class="btn-quiet" style="padding: 4px; color: var(--danger);" onclick="app.deleteCharacter(${char.id})">
                    <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>
                </button>
            </div>
        `).join('');
    }

    renderRelationshipList() {
        const list = document.getElementById('bible-rel-list');
        if (this.currentStoryRelationships.length === 0) {
            list.innerHTML = '<p style="font-size: 12px; color: var(--text-secondary); text-align: center;">No relationships yet.</p>';
            return;
        }

        list.innerHTML = this.currentStoryRelationships.map(rel => {
            const from = this.currentStoryCharacters.find(c => c.id === rel.from_character);
            const to = this.currentStoryCharacters.find(c => c.id === rel.to_character);
            if (!from || !to) return '';
            
            return `
                <div style="font-size: 12px; background: #F1F5F9; padding: 8px 12px; border-radius: 10px; border: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-weight: 600;">${escapeHTML(from.name)} <span style="color: var(--text-secondary); font-weight: 400;">is ${escapeHTML(rel.type)} of</span> ${escapeHTML(to.name)}</span>
                    <button class="btn-quiet" style="padding: 2px; color: var(--danger);" onclick="app.deleteRelationship(${rel.id})">×</button>
                </div>
            `;
        }).join('');
    }

    renderCharacterGraph() {
        const container = document.getElementById('character-graph');
        if (!container) return;
        
        const nodes = new vis.DataSet(this.currentStoryCharacters.map(c => ({
            id: c.id,
            label: c.name,
            color: {
                background: c.color,
                border: '#ffffff',
                highlight: { background: c.color, border: '#000000' }
            },
            font: { color: '#ffffff', weight: 'bold' },
            shape: 'dot',
            size: 25
        })));

        const edges = new vis.DataSet(this.currentStoryRelationships.map(r => ({
            from: r.from_character,
            to: r.to_character,
            label: r.type,
            font: { align: 'horizontal', size: 10 },
            arrows: 'to',
            color: { color: '#94A3B8' }
        })));

        const data = { nodes, edges };
        const options = {
            physics: {
                enabled: true,
                stabilization: true
            },
            layout: {
                randomSeed: 2
            }
        };

        if (this.charNetwork) this.charNetwork.destroy();
        this.charNetwork = new vis.Network(container, data, options);
    }

    showAddCharacter() {
        document.getElementById('char-name').value = '';
        document.getElementById('char-role').value = '';
        document.getElementById('character-modal').classList.remove('hidden');
    }

    async saveCharacter() {
        const name = document.getElementById('char-name').value;
        const role = document.getElementById('char-role').value;
        const color = document.getElementById('char-color').value;

        if (!name) return alert("Character name is required");

        try {
            await this.fetchAPI('/core/characters/', {
                method: 'POST',
                body: JSON.stringify({
                    book: this.currentStoryId,
                    name, role, color
                })
            });
            document.getElementById('character-modal').classList.add('hidden');
            this.loadCharacterData();
            this.showSuccessAnimation();
        } catch (e) {
            alert("Failed to save character");
        }
    }

    showAddRelationship() {
        if (this.currentStoryCharacters.length < 2) {
            alert("Add at least 2 characters first.");
            return;
        }

        const fromSelect = document.getElementById('rel-from');
        const toSelect = document.getElementById('rel-to');
        
        const options = this.currentStoryCharacters.map(c => `<option value="${c.id}">${c.name}</option>`).join('');
        fromSelect.innerHTML = options;
        toSelect.innerHTML = options;
        
        document.getElementById('rel-modal').classList.remove('hidden');
    }

    async saveRelationship() {
        const from = document.getElementById('rel-from').value;
        const to = document.getElementById('rel-to').value;
        const type = document.getElementById('rel-type').value;
        const desc = document.getElementById('rel-desc').value;

        if (from === to) return alert("Characters must be different");

        try {
            await this.fetchAPI('/core/relationships/', {
                method: 'POST',
                body: JSON.stringify({
                    from_character: from,
                    to_character: to,
                    type, description: desc
                })
            });
            document.getElementById('rel-modal').classList.add('hidden');
            this.loadCharacterData();
            this.showSuccessAnimation();
        } catch (e) {
            alert("Failed to save relationship");
        }
    }

    async deleteCharacter(id) {
        if (!confirm("Delete this character and all their relationships?")) return;
        try {
            await this.fetchAPI(`/core/characters/${id}/`, { method: 'DELETE' });
            this.loadCharacterData();
        } catch (e) { alert("Failed to delete character"); }
    }

    async deleteRelationship(id) {
        if (!confirm("Remove this relationship?")) return;
        try {
            await this.fetchAPI(`/core/relationships/${id}/`, { method: 'DELETE' });
            this.loadCharacterData();
        } catch (e) { alert("Failed to delete relationship"); }
    }

    async showSprintModal() {
        document.getElementById('sprint-modal').classList.remove('hidden');
        await this.loadActiveSprint();
        this.startSprintPoller();
    }

    async loadActiveSprint() {
        try {
            const sprint = await this.fetchAPI('/core/sprints/active_sprint/');
            this.currentSprint = sprint;
            if (sprint) {
                document.getElementById('sprint-title').textContent = sprint.title;
                this.updateSprintTimer();
                this.renderSprintLeaderboard();
                
                const isPart = sprint.participants.some(p => p.username === this.currentUser);
                document.getElementById('btn-join-sprint').classList.toggle('hidden', isPart);
                document.getElementById('sprint-progress-container').classList.toggle('hidden', !isPart);
                document.getElementById('sprint-status-msg').textContent = isPart ? "Sprint in progress! Keep writing." : "Join this active sprint!";
            }
        } catch (e) {
            console.error("Sprint load error", e);
        }
    }

    updateSprintTimer() {
        if (!this.currentSprint) return;
        const end = new Date(this.currentSprint.end_time).getTime();
        const now = new Date().getTime();
        const diff = end - now;

        if (diff <= 0) {
            document.getElementById('sprint-timer').textContent = "00:00";
            document.getElementById('sprint-status-msg').textContent = "Sprint finished! Well done.";
            return;
        }

        const mins = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
        const secs = Math.floor((diff % (1000 * 60)) / 1000);
        document.getElementById('sprint-timer').textContent = `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
        
        // Only trigger next timeout if modal is visible to save resources
        if (!document.getElementById('sprint-modal').classList.contains('hidden')) {
            setTimeout(() => this.updateSprintTimer(), 1000);
        }
    }

    renderSprintLeaderboard() {
        if (!this.currentSprint) return;
        const list = document.getElementById('sprint-leaderboard');
        list.innerHTML = this.currentSprint.participants.map((p, i) => `
            <div style="display: flex; align-items: center; justify-content: space-between; background: white; padding: 10px 15px; border-radius: 12px; border: 1px solid var(--border-color); ${p.username === this.currentUser ? 'border-color: var(--accent-primary); background: #EEF2FF;' : ''}">
                <div style="display: flex; align-items: center; gap: 10px;">
                    <span style="font-weight: 800; color: var(--text-secondary); width: 20px;">#${i + 1}</span>
                    <span style="font-weight: 700;">${escapeHTML(p.username)}</span>
                </div>
                <span style="font-weight: 800; color: #10B981;">${p.words_written} words</span>
            </div>
        `).join('') || '<p style="text-align: center; font-size: 12px; color: var(--text-secondary);">Be the first to join!</p>';
        
        const userPart = this.currentSprint.participants.find(p => p.username === this.currentUser);
        if (userPart) {
            document.getElementById('sprint-user-words').textContent = userPart.words_written;
        }
    }

    async joinSprint() {
        if (!this.currentSprint) return;
        try {
            await this.fetchAPI(`/core/sprints/${this.currentSprint.id}/join/`, { method: 'POST' });
            this.wordsWrittenAtSprintStart = parseInt(document.getElementById('word-count').textContent) || 0;
            await this.loadActiveSprint();
        } catch (e) {
            alert("Failed to join sprint.");
        }
    }

    startSprintPoller() {
        if (this.sprintPoller) clearInterval(this.sprintPoller);
        this.sprintPoller = setInterval(async () => {
            const modal = document.getElementById('sprint-modal');
            if (modal.classList.contains('hidden')) {
                clearInterval(this.sprintPoller);
                return;
            }
            
            // If participating, update progress first
            if (this.currentSprint) {
                const isPart = this.currentSprint.participants.some(p => p.username === this.currentUser);
                if (isPart) {
                    const currentWords = parseInt(document.getElementById('word-count').textContent) || 0;
                    const delta = Math.max(0, currentWords - this.wordsWrittenAtSprintStart);
                    await this.fetchAPI(`/core/sprints/${this.currentSprint.id}/update_progress/`, {
                        method: 'POST',
                        body: JSON.stringify({ words_written: delta })
                    });
                }
            }
            
            await this.loadActiveSprint();
        }, 10000); // Every 10 seconds
    }

    closeSprintModal() {
        document.getElementById('sprint-modal').classList.add('hidden');
        if (this.sprintPoller) clearInterval(this.sprintPoller);
    }

    async exportBook(format) {
        if (!this.currentStoryId) return;
        
        const btn = event.currentTarget;
        const originalText = btn.innerHTML;
        btn.innerHTML = '<span style="font-size: 12px;">Generating...</span>';
        btn.disabled = true;

        try {
            const url = `${API_URL}/core/books/${this.currentStoryId}/export_${format}/`;
            
            const response = await fetch(url, {
                headers: { 'Authorization': `Bearer ${this.token}` }
            });
            
            if (!response.ok) throw new Error('Export failed');
            
            const blob = await response.blob();
            const downloadUrl = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = downloadUrl;
            a.download = `srishty_export_${this.currentStoryId}.${format}`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(downloadUrl);
            a.remove();
            
            this.showSuccessAnimation();
        } catch (err) {
            console.error(err);
            alert(`Export failed: ${err.message}`);
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    }

    async loadAchievementsView() {
        const container = document.getElementById('achievements-container');
        container.innerHTML = '<p style="color: var(--text-secondary); text-align: center; grid-column: 1 / -1;">Loading achievements...</p>';
        
        try {
            const checkRes = await this.fetchAPI('/core/achievements/check_all/', { method: 'POST' });
            if (checkRes && checkRes.new_unlocks && checkRes.new_unlocks.length > 0) {
                this.showAchievementUnlocked(checkRes.new_unlocks[0].achievement);
            }

            const data = await this.fetchAPI('/core/achievements/mine/');
            const unlockedIds = data.unlocked.map(ua => ua.achievement.id);
            const allAchievements = data.all;
            
            if (allAchievements.length === 0) {
                container.innerHTML = '<p style="text-align: center; grid-column: 1 / -1;">No achievements configured.</p>';
                return;
            }

            let html = '';
            
            allAchievements.forEach(ach => {
                const isUnlocked = unlockedIds.includes(ach.id);
                const statusClass = isUnlocked ? 'unlocked' : 'locked';
                const dateStr = isUnlocked ? data.unlocked.find(ua => ua.achievement.id === ach.id).unlocked_at : null;
                const dateHtml = isUnlocked ? 
                    `<div style="font-size: 11px; color: var(--accent-primary); margin-top: 4px; font-weight: bold;">Unlocked on ${new Date(dateStr).toLocaleDateString()}</div>` : 
                    `<div style="font-size: 11px; color: var(--text-secondary); margin-top: 4px;">Locked</div>`;

                html += `
                    <div class="achievement-card ${statusClass}">
                        <div class="ach-icon-wrapper">
                            ${ach.icon}
                        </div>
                        <div style="flex: 1;">
                            <h4 style="margin: 0; font-size: 15px; color: var(--text-primary);">${escapeHTML(ach.title)}</h4>
                            <p style="margin: 4px 0 0; font-size: 12px; color: var(--text-secondary); line-height: 1.4;">${escapeHTML(ach.description)}</p>
                            ${dateHtml}
                        </div>
                    </div>
                `;
            });
            
            container.innerHTML = html;
        } catch (err) {
            console.error(err);
            container.innerHTML = '<p style="color: red; grid-column: 1 / -1;">Error loading achievements.</p>';
        }
    }

    showAchievementUnlocked(achievement) {
        document.getElementById('achievement-icon').innerText = achievement.icon || '🏆';
        document.getElementById('achievement-title').innerText = achievement.title;
        document.getElementById('achievement-desc').innerText = achievement.description;
        
        const modal = document.getElementById('achievement-modal');
        modal.classList.remove('hidden');
        
        setTimeout(() => {
            if(!modal.classList.contains('hidden')) {
                modal.classList.add('hidden');
            }
        }, 5000);
    }
    }
}

// Global initialization
const app = new SrishtyApp();
