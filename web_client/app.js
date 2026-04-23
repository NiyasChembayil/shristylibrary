const API_BASE_URL = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' 
    ? 'http://localhost:8000/api' 
    : 'https://srishty-backend.onrender.com/api';

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
        
        // Wait for DOM to be ready before init
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.init());
        } else {
            this.init();
        }
    }

    async init() {
        console.log('App: Initializing Wattpad-Style Studio...');
        this.checkAuth();
        
        try {
            this.setupQuill();
        } catch (e) {
            console.warn('Quill setup delayed/failed:', e);
        }
    }

    setupQuill() {
        if (!document.getElementById('editor-container')) return;
        
        this.quill = new Quill('#editor-container', {
            theme: 'snow',
            modules: {
                toolbar: [
                    ['bold', 'italic', 'underline', 'strike'],
                    ['blockquote', 'image'],
                    [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                    ['clean']
                ]
            },
            placeholder: 'Start your story here...'
        });

        this.quill.on('text-change', () => {
            const text = this.quill.getText().trim();
            const count = text.length > 0 ? text.split(/\s+/).length : 0;
            const wordCountEl = document.getElementById('word-count');
            if(wordCountEl) wordCountEl.textContent = `Word Count: ${count.toLocaleString()}`;
        });
    }

    /* ======== API & AUTH ======== */
    async fetchAPI(endpoint, options = {}) {
        const headers = { ...options.headers };
        if (!(options.body instanceof FormData)) {
            headers['Content-Type'] = 'application/json';
        }
        if (this.token) Object.assign(headers, { 'Authorization': `Bearer ${this.token}` });
        
        const response = await fetch(`${API_BASE_URL}${endpoint}`, { ...options, headers });
        if (response.status === 401) { this.logout(); return null; }
        if (!response.ok) {
            let errorText = `API Error: ${response.status}`;
            try {
                const errorData = await response.json();
                errorText += ` - ${JSON.stringify(errorData)}`;
            } catch (e) {
                errorText += ` - ${await response.text()}`;
            }
            throw new Error(errorText);
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
            
            const welcome = document.getElementById('welcome-message');
            if(welcome) welcome.textContent = `Welcome, ${this.currentUser} 👋`;
            
            this.switchView('home');
        }
    }

    async handleAuth(e) {
        e.preventDefault();
        const user = document.getElementById('auth-user').value;
        const pass = document.getElementById('auth-pass').value;
        const errorEl = document.getElementById('auth-error');
        
        try {
            if (this.isSignUpMode) {
                const email = document.getElementById('auth-email').value;
                await this.fetchAPI('/accounts/register/', {
                    method: 'POST',
                    body: JSON.stringify({ username: user, email, password: pass })
                });
            }
            const res = await fetch(`${API_BASE_URL}/token/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username: user, password: pass })
            });
            
            if (!res.ok) throw new Error();
            const data = await res.json();
            
            this.token = data.access;
            this.currentUser = user;
            localStorage.setItem('access_token', this.token);
            localStorage.setItem('username', user);
            
            this.checkAuth();
        } catch (err) {
            console.error('Sign-in error:', err);
            alert('Sign-in error: ' + err.message);
            errorEl.style.display = 'block';
            errorEl.textContent = this.isSignUpMode ? 'Registration failed.' : `Sign-in failed. ${err.message || 'Check connection.'}`;
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
        document.querySelectorAll('.view-content').forEach(el => el.classList.add('hidden'));
        const activeView = document.getElementById(`view-${viewName}`);
        if(activeView) activeView.classList.remove('hidden');
        this.currentView = viewName;

        if (viewName === 'home') this.loadDashboard();
        if (viewName === 'create') this.resetCreateForm();
    }

    getMediaUrl(path) {
        if (!path) return 'https://placehold.co/400x600?text=No+Cover';
        if (path.startsWith('http')) return path;
        
        // Resilience: Handle potential double slashes or missing slashes
        const backendOrigin = API_BASE_URL.replace('/api', '').replace(/\/$/, '');
        const cleanPath = path.startsWith('/') ? path : `/${path}`;
        return `${backendOrigin}${cleanPath}`;
    }

    /* ======== DASHBOARD ======== */
    async loadDashboard() {
        const grid = document.getElementById('story-grid');
        grid.innerHTML = '<p style="color: var(--text-secondary);">Loading your masterpieces...</p>';
        
        try {
            // OPTIMIZATION: Request only current user's books 
            // backend filters by author=request.user when calling /my_books/
            const myBooks = await this.fetchAPI('/core/books/my_books/');
            
            if (!myBooks || myBooks.length === 0) {
                grid.innerHTML = `<p style="color: var(--text-secondary);">You haven't written anything yet. Click Create New Story to begin!</p>`;
                return;
            }

            grid.innerHTML = myBooks.map(book => {
                const coverUrl = this.getMediaUrl(book.cover);
                return `
                <div class="story-card">
                    <div class="story-card-img">
                        <img src="${coverUrl}" alt="cover" onerror="this.onerror=null;this.src='https://placehold.co/400x600?text=Cover+Not+Found';">
                        <div class="status-badge ${book.is_published ? 'status-published' : 'status-draft'}">
                            ${book.is_published ? 'Published' : 'Draft'}
                        </div>
                    </div>
                    <div class="story-card-content">
                        <div class="story-card-title">${book.title}</div>
                    </div>
                    <div class="story-card-actions">
                        <button onclick="app.openSettings(${book.id})">⚙️ Settings</button>
                        <button onclick="app.openEditor(${book.id})">✏️ Write</button>
                    </div>
                </div>
                `;
            }).join('');

        } catch (err) {
            console.error('Dashboard Error:', err);
            alert('Dashboard Error: ' + err.message);
            grid.innerHTML = `<p style="color: #ff6b6b;">Failed to load stories. ${err.message}</p>`;
        }
    }

    /* ======== CREATE STORY VIEW ======== */
    resetCreateForm() {
        document.getElementById('create-story-form').reset();
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
        
        const coverFile = document.getElementById('create-cover').files[0];
        if (coverFile) formData.append('cover', coverFile);

        try {
            const book = await this.fetchAPI('/core/books/', { method: 'POST', body: formData });
            // Immediately open editor for a new Chapter 1
            await this.openEditor(book.id, true);
        } catch (err) {
            alert(`Failed to create story. ${err.message}`);
        } finally {
            btn.textContent = 'Create Story';
            btn.disabled = false;
        }
    }

    /* ======== EDITOR VIEW ======== */
    async openEditor(bookId) {
        this.currentStoryId = bookId;
        this.switchView('editor');
        this.quill.setText('Loading...\n');

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('editor-story-title').textContent = book.title;
            this.currentChapters = book.chapters || [];
            
            this.renderChapterList();

            if (this.currentChapters.length === 0) {
                this.createNewChapter();
            } else {
                // Load first chapter
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
                <span>${ch.title || 'Chapter ' + (idx + 1)}</span>
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
        document.getElementById('chapter-audio').value = '';
        document.getElementById('audio-filename').textContent = 'Attach Audio';
        this.renderChapterList();
    }

    createNewChapter() {
        // Only allow one unsaved "new" chapter at a time
        const list = document.getElementById('sidebar-chapter-list');
        const existingNew = Array.from(list.children).find(el => el.dataset.id === 'new');
        
        if (!existingNew) {
            const div = document.createElement('div');
            div.className = 'chapter-item active';
            div.dataset.id = 'new';
            div.innerHTML = `<span>New Chapter *</span>`;
            list.appendChild(div);
            
            this.currentChapterId = null;
            this.quill.setText('');
            document.getElementById('editor-chapter-label').textContent = 'New Chapter';
            this.quill.focus();
        }
    }

    async saveCurrentChapter() {
        const content = JSON.stringify(this.quill.getContents());
        const textContent = this.quill.getText().trim();
        if(!textContent) {
            alert('Please write something first!');
            return;
        }
        
        const saveBtn = document.getElementById('save-indicator');
        const statusText = document.getElementById('save-status');
        saveBtn.textContent = 'Saving...';
        statusText.textContent = 'Saving...';

        const label = document.getElementById('editor-chapter-label').textContent;
        const formData = new FormData();
        formData.append('title', label === 'New Chapter' ? `Chapter ${this.currentChapters.length + 1}` : label);
        formData.append('content', content);

        const audioFile = document.getElementById('chapter-audio').files[0];
        if (audioFile) formData.append('audio_file', audioFile);

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
            this.renderChapterList();
            alert('Progress Saved!');
        } catch(e) {
            console.error('Save Error:', e);
            alert(`Failed: ${e.message}`);
            statusText.textContent = 'Error';
        }
    }

    async publishStory() {
        if (!this.currentStoryId) return;
        if (!confirm('Are you ready to publish this story to the world?')) return;

        try {
            const formData = new FormData();
            formData.append('is_published', 'true');
            await this.fetchAPI(`/core/books/${this.currentStoryId}/`, {
                method: 'PATCH',
                body: formData
            });
            alert('Story Published successfully! 🎉');
            this.switchView('home');
        } catch (e) {
            alert(`Failed to publish: ${e.message}`);
        }
    }

    /* ======== SETTINGS VIEW ======== */
    async openSettings(bookId) {
        if(!bookId) bookId = this.currentStoryId;
        if(!bookId) return;

        this.currentStoryId = bookId;
        this.switchView('settings');
        
        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('settings-title').value = book.title;
            document.getElementById('settings-desc').value = book.description;
            document.getElementById('settings-status').value = book.is_published ? 'published' : 'draft';
            
            const preview = document.getElementById('settings-cover-preview');
            const coverUrl = this.getMediaUrl(book.cover);
            if(coverUrl) {
                preview.src = coverUrl;
                preview.style.display = 'block';
            } else {
                preview.style.display = 'none';
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

        try {
            await this.fetchAPI(`/core/books/${this.currentStoryId}/`, {
                method: 'PATCH',
                body: formData
            });
            alert('Settings Updated!');
            this.switchView('home');
        } catch (e) {
            alert('Failed to save settings.');
        } finally {
            btn.textContent = 'Save Changes';
        }
    }
}

// Global initialization - Create instance immediately
const app = new SrishtyApp();
