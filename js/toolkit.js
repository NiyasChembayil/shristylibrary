const API_BASE = 'https://srishty-backend.onrender.com/api/';
const token = localStorage.getItem('studio_access');

if (!token) window.location.href = 'index.html';

const studioApi = axios.create({
    baseURL: API_BASE,
    headers: { 'Authorization': `Bearer ${token}` }
});

// DOM
const storySelector = document.getElementById('story-selector');
const quoteInput = document.getElementById('card-quote');
const themeOpts = document.querySelectorAll('.theme-opt');
const socialCard = document.getElementById('social-card');
const downloadBtn = document.getElementById('download-card');

const previewTitle = document.getElementById('preview-title');
const previewQuote = document.getElementById('preview-quote');
const previewAuthor = document.getElementById('preview-author');
const previewCover = document.getElementById('preview-cover');

let stories = [];

async function initToolkit() {
    try {
        const res = await studioApi.get('core/books/my_books/');
        stories = res.data;
        
        storySelector.innerHTML = '<option value="">Select a story...</option>' + 
            stories.map(s => `<option value="${s.id}">${s.title}</option>`).join('');

        const profileRes = await studioApi.get('accounts/profile/me/');
        previewAuthor.textContent = `by ${profileRes.data.username}`;

    } catch (err) {
        console.error(err);
    }
}

storySelector.addEventListener('change', (e) => {
    const story = stories.find(s => s.id == e.target.value);
    if (story) {
        previewTitle.textContent = story.title;
        if (story.cover) previewCover.src = story.cover;
        else previewCover.src = '';
    }
});

quoteInput.addEventListener('input', (e) => {
    previewQuote.textContent = e.target.value;
});

themeOpts.forEach(opt => {
    opt.addEventListener('click', () => {
        themeOpts.forEach(o => o.classList.remove('active'));
        opt.classList.add('active');
        
        socialCard.className = `social-card-render ${opt.dataset.theme}`;
    });
});

downloadBtn.addEventListener('click', () => {
    html2canvas(socialCard, {
        useCORS: true,
        scale: 2
    }).then(canvas => {
        const link = document.createElement('a');
        link.download = `Srishty_Promo_${Date.now()}.png`;
        link.href = canvas.toDataURL();
        link.click();
    });
});

initToolkit();
