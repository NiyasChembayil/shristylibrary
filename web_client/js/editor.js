const API_BASE = 'https://srishty-backend.onrender.com/api/';
const token = localStorage.getItem('studio_access');

// Auth Check
if (!token) window.location.href = 'index.html';

const studioApi = axios.create({
    baseURL: API_BASE,
    headers: { 'Authorization': `Bearer ${token}` }
});

// State
let currentStoryId = new URLSearchParams(window.location.search).get('id');
let currentChapterId = null;
let chapters = [];
let quill = null;
let saveTimeout = null;

// DOM Elements
const chaptersList = document.getElementById('chapters-list');
const addChapterBtn = document.getElementById('add-chapter-btn');
const chapterTitleInput = document.getElementById('chapter-title-input');
const saveStatus = document.getElementById('save-status');
const publishBtn = document.getElementById('publish-btn');
const bibleBtn = document.getElementById('story-bible-btn');
const bibleOverlay = document.getElementById('bible-overlay');
const closeBible = document.getElementById('close-bible');

// Initialize Quill
function initQuill() {
    quill = new Quill('#editor-container', {
        theme: 'snow',
        modules: {
            toolbar: [
                ['bold', 'italic', 'underline', 'strike'],
                [{ 'header': 1 }, { 'header': 2 }],
                [{ 'list': 'ordered'}, { 'list': 'bullet' }],
                ['clean']
            ]
        },
        placeholder: 'Start writing your story...'
    });

    quill.on('text-change', () => {
        if (!currentChapterId) return;
        saveStatus.textContent = 'Unsaved changes...';
        clearTimeout(saveTimeout);
        saveTimeout = setTimeout(autoSave, 2000);
    });
}

// Auto-save logic
async function autoSave() {
    if (!currentChapterId) return;
    saveStatus.textContent = 'Saving...';
    try {
        await studioApi.patch(`core/chapters/${currentChapterId}/`, {
            title: chapterTitleInput.value,
            content: quill.root.innerHTML
        });
        saveStatus.textContent = 'Saved';
    } catch (err) {
        console.error('Save failed:', err);
        saveStatus.textContent = 'Save failed!';
    }
}

// Initialize Page
async function initEditor() {
    initQuill();
    
    if (currentStoryId) {
        await loadStoryDetails();
        await loadChapters();
    } else {
        // Create new story first
        await createNewStory();
    }
}

async function createNewStory() {
    try {
        const res = await studioApi.post('core/books/', {
            title: 'Untitled Story',
            category: 1 // Default category
        });
        currentStoryId = res.data.id;
        // Update URL without refresh
        window.history.pushState({}, '', `editor.html?id=${currentStoryId}`);
        await loadStoryDetails();
        await addChapter();
    } catch (err) {
        console.error('Failed to create story:', err);
    }
}

async function loadStoryDetails() {
    try {
        const res = await studioApi.get(`core/books/${currentStoryId}/`);
        const story = res.data;
        document.getElementById('story-title-input').value = story.title;
        document.getElementById('story-desc-input').value = story.description || '';
        if (story.cover) {
            document.getElementById('story-cover-display').innerHTML = `<img src="${story.cover}" style="width:100%; height:100%; object-fit:cover; border-radius:12px;">`;
        }
    } catch (err) {
        console.error('Failed to load story meta:', err);
    }
}

async function loadChapters() {
    try {
        const res = await studioApi.get(`core/chapters/?book=${currentStoryId}`);
        chapters = res.data;
        renderChapters();
        if (chapters.length > 0 && !currentChapterId) {
            selectChapter(chapters[0].id);
        }
    } catch (err) {
        console.error('Failed to load chapters:', err);
    }
}

function renderChapters() {
    chaptersList.innerHTML = chapters.map((ch, idx) => `
        <div class="chapter-item ${currentChapterId == ch.id ? 'active' : ''}" onclick="selectChapter(${ch.id})">
            <span>Ch ${idx + 1}: ${ch.title || 'Untitled'}</span>
        </div>
    `).join('');
}

async function selectChapter(id) {
    if (saveStatus.textContent === 'Saving...') return;
    currentChapterId = id;
    const chapter = chapters.find(ch => ch.id == id);
    chapterTitleInput.value = chapter.title || 'Untitled';
    quill.root.innerHTML = chapter.content || '';
    renderChapters();
}

async function addChapter() {
    try {
        const res = await studioApi.post('core/chapters/', {
            book: currentStoryId,
            title: 'New Chapter',
            content: '',
            order: chapters.length + 1
        });
        await loadChapters();
        selectChapter(res.data.id);
    } catch (err) {
        console.error('Failed to add chapter:', err);
    }
}

// Meta update
document.getElementById('save-meta-btn').addEventListener('click', async () => {
    const title = document.getElementById('story-title-input').value;
    const description = document.getElementById('story-desc-input').value;
    try {
        await studioApi.patch(`core/books/${currentStoryId}/`, { title, description });
        alert('Story updated successfully!');
    } catch (err) {
        alert('Failed to update story.');
    }
});

// Event Listeners
addChapterBtn.addEventListener('click', addChapter);
chapterTitleInput.addEventListener('input', () => {
    clearTimeout(saveTimeout);
    saveTimeout = setTimeout(autoSave, 2000);
});

bibleBtn.addEventListener('click', () => bibleOverlay.classList.remove('hidden'));
closeBible.addEventListener('click', () => bibleOverlay.classList.add('hidden'));

publishBtn.addEventListener('click', async () => {
    try {
        await studioApi.patch(`core/books/${currentStoryId}/`, { moderation_status: 'published' });
        alert('Congratulations! Your story is now published on Srishty.');
    } catch (err) {
        alert('Publishing failed.');
    }
});

initEditor();
