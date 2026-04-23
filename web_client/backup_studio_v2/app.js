const API_BASE_URL = '/api';

class SrishtyReaderApp {
    constructor() {
        this.categories = [];
        this.token = localStorage.getItem('access_token');
        this.profile = null;
        this.isSignUpMode = false;
        
        // Reader State
        this.currentBook = null;
        this.currentChapters = [];
        this.currentChapterIndex = 0;
        
        this.init();
    }

    async init() {
        this.checkAuth();
        this.detectLocation();
        this.bindEvents();
        
        // Only load discovery data if the sections exist
        if (document.getElementById('trending-carousel')) {
            this.loadTrendingBooks();
            await this.loadCategories();
            if (this.categories.length > 0) {
                this.loadCategoryBooks('sci-fi');
            }
        }
    }

    checkAuth() {
        const guestNav = document.getElementById('guest-nav');
        const authNav = document.getElementById('auth-nav');
        const usernameDisplay = document.getElementById('nav-username');
        
        // If on the new portal page, handle redirect in constructor or head script
        if (this.token && window.location.pathname.includes('index.html')) {
            // Already handled by head script, but as fallback:
            // window.location.href = 'studio.html';
        }

        if (!guestNav || !authNav) return;
        
        if (this.token) {
            guestNav.classList.add('hidden');
            authNav.classList.remove('hidden');
            usernameDisplay.textContent = localStorage.getItem('username') || 'Author';
            this.fetchProfile();
        } else {
            guestNav.classList.remove('hidden');
            authNav.classList.add('hidden');
        }
    }

    async fetchProfile() {
        try {
            const data = await this.fetchAPI('/accounts/profile/me/');
            if (data) {
                this.profile = data;
                localStorage.setItem('username', data.username);
                const display = document.getElementById('nav-username');
                if (display) display.textContent = data.username;
            }
        } catch (e) {
            console.error('Failed to fetch profile', e);
        }
    }

    openAuthModal() {
        const modal = document.getElementById('auth-modal');
        if (modal) modal.classList.add('active');
    }

    closeAuthModal() {
        const modal = document.getElementById('auth-modal');
        if (modal) modal.classList.remove('active');
    }

    toggleAuthMode(e) {
        if (e) e.preventDefault();
        this.isSignUpMode = !this.isSignUpMode;
        
        const title = document.getElementById('auth-title');
        const submitBtn = document.getElementById('auth-submit-btn');
        const emailGroup = document.getElementById('email-group');
        const toggleText = document.getElementById('auth-toggle-text');
        const toggleLink = document.getElementById('auth-toggle-link');
        
        if (this.isSignUpMode) {
            if (title) title.textContent = 'Create Account';
            submitBtn.textContent = 'Sign Up';
            emailGroup.classList.remove('hidden');
            toggleText.textContent = 'Already have an account?';
            toggleLink.textContent = 'Sign In';
        } else {
            if (title) title.textContent = 'Sign In';
            submitBtn.textContent = 'Enter Studio';
            emailGroup.classList.add('hidden');
            toggleText.textContent = 'New author?';
            toggleLink.textContent = 'Create Studio Account';
        }
    }

    async handleAuthSubmit(e) {
        e.preventDefault();
        const username = document.getElementById('auth-username').value;
        const password = document.getElementById('auth-password').value;
        const btn = document.getElementById('auth-submit-btn');
        const errorEl = document.getElementById('auth-error');
        
        btn.disabled = true;
        btn.textContent = 'Authenticating...';
        
        try {
            if (this.isSignUpMode) {
                const email = document.getElementById('auth-email').value;
                const regRes = await fetch(`${API_BASE_URL}/accounts/auth/register/`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ username, email, password, role: 'author' })
                });
                if (!regRes.ok) throw new Error('Registration failed');
            }
            
            const response = await fetch(`${API_BASE_URL}/token/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password })
            });
            
            if (!response.ok) throw new Error('Invalid credentials');
            const data = await response.json();
            
            this.token = data.access;
            localStorage.setItem('access_token', data.access);
            localStorage.setItem('username', username);
            
            // REDIRECT TO STUDIO AFTER LOGIN
            window.location.href = 'studio.html';
        } catch (error) {
            errorEl.textContent = error.message;
            errorEl.style.display = 'block';
            btn.textContent = this.isSignUpMode ? 'Sign Up' : 'Enter Studio';
        } finally {
            btn.disabled = false;
        }
    }

    logout() {
        localStorage.clear();
        window.location.href = 'index.html';
    }

    detectLocation() {
        const locBadge = document.getElementById('user-location');
        if (!locBadge) return;
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
        let region = tz.includes('Asia') ? 'Asia Region' : 'Global';
        locBadge.innerHTML = `📍 Active in ${region}`;
    }

    bindEvents() {
        const tabContainer = document.querySelector('.category-tabs');
        if (tabContainer) {
            tabContainer.addEventListener('click', (e) => {
                if (e.target.classList.contains('tab-btn')) {
                    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
                    e.target.classList.add('active');
                    this.loadCategoryBooks(e.target.getAttribute('data-category'));
                }
            });
        }
    }

    async fetchAPI(endpoint, options = {}) {
        const headers = { 'Content-Type': 'application/json', ...options.headers };
        if (this.token) headers['Authorization'] = `Bearer ${this.token}`;
        
        try {
            const response = await fetch(`${API_BASE_URL}${endpoint}`, { ...options, headers });
            if (response.status === 401) {
                this.logout();
                return null;
            }
            if (!response.ok) return null;
            return await response.json();
        } catch (e) {
            return null;
        }
    }

    createBookCardHTML(book) {
        return `
            <div class="story-card-v2" style="min-width: 200px; cursor: pointer;" onclick="readerApp.openReader(${book.id})">
                <img src="${book.cover || '/static/assets/placeholder.png'}" class="card-cover" alt="">
                <div class="card-body">
                    <div class="card-title" style="font-size: 15px;">${book.title}</div>
                    <p style="font-size: 12px; color: var(--studio-text-light);">by ${book.author_name || 'Author'}</p>
                </div>
            </div>
        `;
    }

    async loadTrendingBooks() {
        const container = document.getElementById('trending-carousel');
        if (!container) return;
        const data = await this.fetchAPI('/core/books/trending/');
        if (data) {
            container.innerHTML = data.map(book => this.createBookCardHTML(book)).join('');
        }
    }

    async loadCategories() {
        const data = await this.fetchAPI('/core/categories/');
        if (data) this.categories = data.results || data;
    }

    async loadCategoryBooks(slug) {
        const container = document.getElementById('category-books');
        if (!container) return;
        const category = this.categories.find(c => c.slug === slug);
        const filter = category ? `?category=${category.id}` : '';
        const data = await this.fetchAPI(`/core/books/${filter}`);
        if (data && data.results) {
            container.innerHTML = data.results.map(book => this.createBookCardHTML(book)).join('');
        }
    }

    // READER LOGIC
    async openReader(bookId) {
        const modal = document.getElementById('reader-modal');
        if (!modal) return;
        modal.classList.add('active');
        document.body.style.overflow = 'hidden';

        try {
            const book = await this.fetchAPI(`/core/books/${bookId}/`);
            this.currentBook = book;
            this.currentChapters = book.chapters || [];
            this.currentChapterIndex = 0;

            document.getElementById('reader-book-title').textContent = book.title;
            const selector = document.getElementById('reader-chapter-selector');
            selector.innerHTML = this.currentChapters.map((ch, i) => `<option value="${i}">Chapter ${ch.order + 1}: ${ch.title}</option>`).join('');
            
            this.loadChapterContent(0);
        } catch (e) {
            alert('Failed to load story');
        }
    }

    loadChapterContent(index) {
        this.currentChapterIndex = parseInt(index);
        const chapter = this.currentChapters[this.currentChapterIndex];
        if (!chapter) return;

        const contentDiv = document.getElementById('reader-content');
        try {
            const delta = JSON.parse(chapter.content);
            contentDiv.innerHTML = delta.map(op => {
                if (typeof op.insert === 'string') {
                    let text = op.insert.replace(/\n/g, '<br>');
                    if (op.attributes) {
                        if (op.attributes.bold) text = `<b>${text}</b>`;
                        if (op.attributes.italic) text = `<i>${text}</i>`;
                        if (op.attributes.header) text = `<h${op.attributes.header}>${text}</h${op.attributes.header}>`;
                    }
                    return text;
                }
                return '';
            }).join('');
        } catch (e) {
            contentDiv.innerHTML = chapter.content || '<i>No content for this chapter.</i>';
        }

        document.getElementById('reader-progress').textContent = `Chapter ${this.currentChapterIndex + 1} of ${this.currentChapters.length}`;
        document.getElementById('reader-chapter-selector').value = this.currentChapterIndex;
    }

    nextChapter() {
        if (this.currentChapterIndex < this.currentChapters.length - 1) {
            this.loadChapterContent(this.currentChapterIndex + 1);
            document.querySelector('.reader-body').scrollTop = 0;
        }
    }

    prevChapter() {
        if (this.currentChapterIndex > 0) {
            this.loadChapterContent(this.currentChapterIndex - 1);
            document.querySelector('.reader-body').scrollTop = 0;
        }
    }

    closeReader() {
        document.getElementById('reader-modal').classList.remove('active');
        document.body.style.overflow = 'auto';
    }

    handleSearch(query) {
        const cards = document.querySelectorAll('#category-books .story-card-v2');
        cards.forEach(card => {
            const title = card.querySelector('.card-title').textContent.toLowerCase();
            if (title.includes(query.toLowerCase())) {
                card.style.display = 'block';
            } else {
                card.style.display = 'none';
            }
        });
    }
}

document.addEventListener('DOMContentLoaded', () => {
    window.readerApp = new SrishtyReaderApp();
});
