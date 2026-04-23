const API_BASE_URL = 'https://srishty-backend.onrender.com/api';

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
        const backendOrigin = API_BASE_URL.replace('/api', '');
        return `${backendOrigin}${path}`;
    }

    /* ======== DASHBOARD ======== */
    async loadDashboard() {
        const grid = document.getElementById('story-grid');
        grid.innerHTML = '<p style="color: var(--text-secondary);">Loading your masterpieces...</p>';
        
        try {
            const data = await this.fetchAPI('/core/books/');
            const books = data.results || data;
            
            if (!books || books.length === 0) {
                grid.innerHTML = `<p style="color: var(--text-secondary);">You haven't written anything yet. Click Create New Story to begin!</p>`;
                return;
            }

            // Filter for current user's books if applicable
            const myBooks = books.filter(b => b.author_name === this.currentUser);
            
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
            grid.innerHTML = `<p style="color: #ff6b6b;">Failed to load stories. Checking connection...</p>`;
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
    async openEditor(bookId, isNew = false) {
        this.currentStoryId = bookId;
        this.switchView('editor');
        this.quill.setText('Loading...\n');

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('editor-story-title').textContent = book.title;
            this.currentChapters = book.chapters || [];
            
            // Build Chapter Dropdown
            const select = document.getElementById('editor-chapter-select');
            select.innerHTML = '';
            
            if (this.currentChapters.length === 0) {
                // Must save a new first chapter
                select.innerHTML = `<option value="new">Chapter 1 ▾</option>`;
                this.currentChapterId = null;
                this.quill.setText('');
            } else {
                this.currentChapters.forEach((ch, idx) => {
                    const opt = document.createElement('option');
                    opt.value = ch.id;
                    opt.textContent = `${ch.title || 'Chapter '+(idx+1)} ▾`;
                    select.appendChild(opt);
                });
                // Load first available chapter
                this.currentChapterId = this.currentChapters[0].id;
                select.value = this.currentChapterId;
                this.loadChapterContent(this.currentChapters[0]);
            }
        } catch (err) {
            console.error(err);
            this.quill.setText('Error loading story context.');
        }
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
    }

    loadSelectedChapter() {
        const select = document.getElementById('editor-chapter-select');
        this.currentChapterId = select.value === "new" ? null : parseInt(select.value);
        
        document.getElementById('chapter-audio').value = ''; // Reset audio picker

        const chap = this.currentChapters.find(c => c.id === this.currentChapterId);
        if (chap) {
            this.loadChapterContent(chap);
        } else {
            this.quill.setText('');
        }
    }

    createNewChapter() {
        const select = document.getElementById('editor-chapter-select');
        
        // Prevent multiple unsaved chapters
        const existingNew = Array.from(select.options).find(opt => opt.value === "new");
        if (existingNew) {
            select.value = "new";
            this.loadSelectedChapter();
        } else {
            const nextNum = this.currentChapters.length + 1;
            const opt = document.createElement('option');
            opt.value = "new";
            opt.textContent = `Chapter ${nextNum} (Unsaved) ▾`;
            select.appendChild(opt);
            select.value = "new";
            
            document.getElementById('chapter-audio').value = ''; // Reset audio picker
            this.currentChapterId = null;
            this.quill.setText('');
            this.quill.focus();
        }
    }

    async saveCurrentChapter() {
        const content = JSON.stringify(this.quill.getContents());
        const select = document.getElementById('editor-chapter-select');
        let chapterTitle = select.options[select.selectedIndex].textContent.replace(' ▾','').replace(' (Unsaved)','');
        
        // Prevent empty save
        if(this.quill.getText().trim() === "") return alert("Chapter is empty.");

        const formData = new FormData();
        formData.append('title', chapterTitle);
        formData.append('content', content);

        const audioFile = document.getElementById('chapter-audio').files[0];
        if (audioFile) formData.append('audio_file', audioFile);

        try {
            if (this.currentChapterId) {
                // Update
                await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/${this.currentChapterId}/`, {
                    method: 'PATCH',
                    body: formData
                });
                // Sync the local memory so we can reverse directly to this chapter later
                const idx = this.currentChapters.findIndex(c => c.id === this.currentChapterId);
                if (idx !== -1) {
                    this.currentChapters[idx].content = content;
                    this.currentChapters[idx].title = chapterTitle;
                }
                select.options[select.selectedIndex].textContent = `${chapterTitle} ▾`;
            } else {
                // Create
                const order = this.currentChapters.length + 1;
                formData.append('order', order);
                const newChap = await this.fetchAPI(`/core/books/${this.currentStoryId}/chapters/`, {
                    method: 'POST',
                    body: formData
                });
                this.currentChapterId = newChap.id;
                this.currentChapters.push(newChap);
                
                // Update dropdown and selection
                select.options[select.selectedIndex].value = newChap.id;
                select.options[select.selectedIndex].textContent = `${chapterTitle} ▾`;
            }
            }
            alert('Draft Saved Successfully! You can now view this in your app.');
        } catch(e) {
            console.error('Save Error:', e);
            alert(`Failed to save chapter: ${e.message}\n(Using API: ${API_BASE_URL})`);
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
