class StudioApp {
    constructor() {
        this.quill = null;
        this.currentBookId = null;
        this.currentChapterId = null;
        this.currentChapterOrder = 0;
        this.myBooks = [];
        this.isSaving = false;
        this.init();
    }

    init() {
        // Wait for app.js to fully initialize
        const waitForApp = setInterval(() => {
            if (window.readerApp && window.readerApp.token) {
                clearInterval(waitForApp);
                console.log('App authenticated, initializing studio...');
                try {
                    this.initEditor();
                } catch (e) {
                    console.error('Editor init failed', e);
                }
                this.updateUserProfile();
                this.loadMyStories();
            } else if (window.readerApp && !window.readerApp.token && !window.readerApp.isLoading) {
                clearInterval(waitForApp);
                alert('You must be logged in to access the Author Studio.');
                window.location.href = '/index.html';
            }
        }, 50);

        // Listen for cover change in settings
        document.getElementById('settings-cover-action')?.addEventListener('change', (e) => {
            const input = document.getElementById('settings-cover-file');
            if (e.target.value === 'change') {
                input.classList.remove('hidden');
            } else {
                input.classList.add('hidden');
            }
        });
    }

    initEditor() {
        this.quill = new Quill('#editor-container', {
            theme: 'snow',
            placeholder: 'Start writing your story here...',
            modules: {
                toolbar: [
                    [{ 'header': [1, 2, false] }],
                    ['bold', 'italic', 'underline', 'strike'],
                    ['blockquote', 'code-block'],
                    [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                    ['link', 'image'],
                    ['clean']
                ]
            }
        });

        this.quill.on('text-change', () => {
            this.updateWordCount();
        });
    }

    updateUserProfile() {
        const profile = window.readerApp.profile;
        if (profile) {
            document.getElementById('welcome-name').textContent = profile.username;
            document.getElementById('profile-name').textContent = profile.username;
            const avatar = document.getElementById('header-avatar');
            if (profile.avatar) avatar.src = profile.avatar;
        }
    }

    switchView(viewName, data = null) {
        console.log('Switching view to:', viewName);
        const targetView = document.getElementById(`view-${viewName}`);
        if (!targetView) {
            console.error('View not found:', viewName);
            return;
        }

        // Hide all views
        document.querySelectorAll('.studio-view').forEach(el => el.classList.add('hidden'));
        // Show target view
        targetView.classList.remove('hidden');

        // Update nav links
        document.querySelectorAll('.nav-links a').forEach(el => el.classList.remove('active'));
        if (viewName === 'dashboard') {
            const dashLink = document.querySelector('.nav-links a[onclick*="dashboard"]');
            if (dashLink) dashLink.classList.add('active');
            this.loadMyStories();
        }

        if (viewName === 'editor' && data) {
            this.loadEditor(data.bookId);
        }

        if (viewName === 'settings' && data) {
            this.loadSettings(data.bookId);
        }
    }

    async loadMyStories() {
        const grid = document.getElementById('stories-grid');
        try {
            const data = await window.readerApp.fetchAPI('/core/books/my_books/');
            if (!data) throw new Error('No data received');
            this.myBooks = data.results || data;
            
            if (this.myBooks.length === 0) {
                grid.innerHTML = '<div class="loading-spinner">You haven\'t created any stories yet. Click the button above to start!</div>';
                return;
            }

            grid.innerHTML = this.myBooks.map(book => `
                <div class="story-card-v2">
                    <img src="${book.cover || '/static/assets/placeholder.png'}" class="card-cover" alt="">
                    <div class="card-body">
                        <div class="card-title">
                            ${book.title}
                            <span class="status-badge ${book.is_published ? 'published' : 'draft'}">
                                ${book.is_published ? 'Published' : 'Draft'}
                            </span>
                        </div>
                        <p style="font-size: 12px; color: var(--studio-text-light); margin-bottom: 5px;">
                            ${book.category_name || 'Uncategorized'} • ${book.language} 
                        </p>
                        <div class="card-actions">
                            <button class="btn-card" onclick="studioApp.switchView('editor', {bookId: ${book.id}})">Edit Content</button>
                            <button class="btn-card" onclick="studioApp.switchView('settings', {bookId: ${book.id}})">Settings</button>
                        </div>
                    </div>
                </div>
            `).join('');
        } catch (err) {
            grid.innerHTML = '<div class="loading-spinner">Error loading stories. Please refresh.</div>';
        }
    }

    async handleCreateStory() {
        const title = document.getElementById('create-title').value;
        const description = document.getElementById('create-desc').value;
        const tags = document.getElementById('create-tags').value;
        const language = document.getElementById('create-lang').value;
        const coverFile = document.getElementById('create-cover').files[0];

        if (!title) {
            alert('Please enter a title.');
            return;
        }

        const formData = new FormData();
        formData.append('title', title);
        formData.append('description', description);
        formData.append('tags', tags);
        formData.append('language', language);
        if (coverFile) formData.append('cover', coverFile);

        try {
            const data = await window.readerApp.fetchAPI('/core/books/', {
                method: 'POST',
                body: formData
            });
            this.switchView('editor', { bookId: data.id });
        } catch (err) {
            alert('Failed to create story: ' + err.message);
        }
    }

    async loadEditor(bookId) {
        this.currentBookId = bookId;
        try {
            const book = await window.readerApp.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('editor-story-title').textContent = book.title;
            const publishBtn = document.getElementById('btn-publish-toggle');
            publishBtn.textContent = book.is_published ? 'Unpublish' : 'Publish';

            // Load Chapters
            const chapters = book.chapters || [];
            const selector = document.getElementById('chapter-selector');
            if (chapters.length === 0) {
                // Auto create first chapter if none exist
                await this.addChapter(true); 
                return;
            }

            selector.innerHTML = chapters.map(ch => `<option value="${ch.order}">Chapter ${ch.order + 1}: ${ch.title}</option>`).join('');
            
            // Load content of first chapter
            this.loadChapterContent(chapters[0].order);
        } catch (err) {
            alert('Error loading editor: ' + err.message);
        }
    }

    async loadChapterContent(order) {
        try {
            this.currentChapterOrder = parseInt(order);
            const data = await window.readerApp.fetchAPI(`/core/books/${this.currentBookId}/chapters/?order=${order}`);
            const chapter = data.results ? data.results[0] : (data[0] || null);
            
            if (chapter) {
                this.currentChapterId = chapter.id;
                try {
                    const content = JSON.parse(chapter.content);
                    this.quill.setContents(content);
                } catch (e) {
                    this.quill.setText(chapter.content || '');
                }
            } else {
                this.quill.setText('');
                this.currentChapterId = null;
            }
        } catch (err) {
            console.error('Failed to load chapter content', err);
        }
    }

    async saveDraft() {
        if (!this.currentBookId || this.isSaving) return;
        this.isSaving = true;

        const content = JSON.stringify(this.quill.getContents());
        
        try {
            if (this.currentChapterId) {
                await window.readerApp.fetchAPI(`/core/books/${this.currentBookId}/chapters/${this.currentChapterId}/`, {
                    method: 'PATCH',
                    body: JSON.stringify({ content: content })
                });
            } else {
                // Create chapter if matches unknown order
                await window.readerApp.fetchAPI(`/core/books/${this.currentBookId}/chapters/`, {
                    method: 'POST',
                    body: JSON.stringify({ 
                        title: `Chapter ${this.currentChapterOrder + 1}`,
                        order: this.currentChapterOrder,
                        content: content 
                    })
                });
            }
            alert('Draft saved successfully!');
        } catch (err) {
            alert('Failed to save draft: ' + err.message);
        } finally {
            this.isSaving = false;
        }
    }

    async addChapter(silent = false) {
        try {
            const nextOrder = document.getElementById('chapter-selector').options.length;
            const res = await window.readerApp.fetchAPI(`/core/books/${this.currentBookId}/chapters/`, {
                method: 'POST',
                body: JSON.stringify({
                    title: `Chapter ${nextOrder + 1}`,
                    order: nextOrder,
                    content: ''
                })
            });
            if (!silent) alert('New chapter added!');
            this.loadEditor(this.currentBookId);
        } catch (err) {
            alert('Failed to add chapter: ' + err.message);
        }
    }

    async togglePublish() {
        const btn = document.getElementById('btn-publish-toggle');
        const currentState = btn.textContent === 'Unpublish';
        try {
            await window.readerApp.fetchAPI(`/core/books/${this.currentBookId}/`, {
                method: 'PATCH',
                body: JSON.stringify({ is_published: !currentState })
            });
            btn.textContent = !currentState ? 'Unpublish' : 'Publish';
            alert(`Story successfully ${!currentState ? 'Published' : 'Unpublished'}!`);
        } catch (err) {
            alert('Failed to update publication status');
        }
    }

    async loadSettings(bookId) {
        this.currentBookId = bookId;
        try {
            const book = await window.readerApp.fetchAPI(`/core/books/${bookId}/`);
            document.getElementById('settings-header-title').textContent = `Settings: ${book.title}`;
            document.getElementById('settings-title').value = book.title;
            document.getElementById('settings-desc').value = book.description;
            document.getElementById('settings-status').value = book.is_published.toString();
            document.getElementById('settings-cover-preview').src = book.cover || '/static/assets/placeholder.png';
        } catch (err) {
            alert('Failed to load settings');
        }
    }

    async saveSettings() {
        const title = document.getElementById('settings-title').value;
        const description = document.getElementById('settings-desc').value;
        const isPublished = document.getElementById('settings-status').value === 'true';
        const coverAction = document.getElementById('settings-cover-action').value;
        const coverFile = document.getElementById('settings-cover-file').files[0];

        const formData = new FormData();
        formData.append('title', title);
        formData.append('description', description);
        formData.append('is_published', isPublished);
        if (coverAction === 'change' && coverFile) {
            formData.append('cover', coverFile);
        }

        try {
            await window.readerApp.fetchAPI(`/core/books/${this.currentBookId}/`, {
                method: 'PATCH',
                body: formData
            });
            alert('Settings saved!');
            this.switchView('dashboard');
        } catch (err) {
            alert('Failed to save settings: ' + err.message);
        }
    }

    updateWordCount() {
        const text = this.quill.getText().trim();
        const words = text ? text.split(/\s+/).length : 0;
        document.getElementById('word-count').textContent = `Word Count: ${words.toLocaleString()}`;
    }
}

document.addEventListener('DOMContentLoaded', () => {
    window.studioApp = new StudioApp();
});
