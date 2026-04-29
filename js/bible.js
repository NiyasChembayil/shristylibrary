const API_BASE = 'https://srishty-backend.onrender.com/api/';
const token = localStorage.getItem('studio_access');

if (!token) window.location.href = 'index.html';

const studioApi = axios.create({
    baseURL: API_BASE,
    headers: { 'Authorization': `Bearer ${token}` }
});

// State
let nodes = new vis.DataSet([]);
let edges = new vis.DataSet([]);
let characters = [];

// DOM
const charList = document.getElementById('char-list');
const addCharBtn = document.getElementById('add-char-btn');
const charModal = document.getElementById('char-modal');
const saveCharBtn = document.getElementById('save-char');
const cancelCharBtn = document.getElementById('cancel-char');

function initGraph() {
    const container = document.getElementById('relation-graph');
    const data = { nodes, edges };
    const options = {
        nodes: {
            shape: 'dot',
            size: 30,
            font: { color: '#ffffff', size: 14, face: 'Inter' },
            borderWidth: 2,
            color: {
                background: '#6C63FF',
                border: '#00D2FF',
                highlight: { background: '#00D2FF', border: '#ffffff' }
            }
        },
        edges: {
            color: 'rgba(255, 255, 255, 0.2)',
            width: 2,
            smooth: { type: 'continuous' }
        },
        physics: {
            forceAtlas2Based: {
                gravitationalConstant: -50,
                centralGravity: 0.01,
                springLength: 100,
                springConstant: 0.08
            },
            maxVelocity: 50,
            solver: 'forceAtlas2Based',
            timestep: 0.35,
            stabilization: { iterations: 150 }
        }
    };
    new vis.Network(container, data, options);
}

// Local mock data logic (since backend might not have dedicated bible endpoints yet)
// We'll store bible data in localStorage for now to show the feature, 
// or use the 'Story Bible' text notes if available.

async function loadBible() {
    const saved = localStorage.getItem('studio_bible_data');
    if (saved) {
        const data = JSON.parse(saved);
        characters = data.characters || [];
        renderCharacters();
        updateGraph();
    }
}

function renderCharacters() {
    charList.innerHTML = characters.map(c => `
        <div class="char-item">
            <span>${c.name}</span>
            <span class="role">${c.role}</span>
        </div>
    `).join('');
}

function updateGraph() {
    nodes.clear();
    edges.clear();
    
    characters.forEach(c => {
        nodes.add({ id: c.id, label: c.name, title: c.role });
    });

    // Mock connections for demo
    if (characters.length > 1) {
        edges.add({ from: characters[0].id, to: characters[1].id });
    }
}

addCharBtn.addEventListener('click', () => charModal.classList.remove('hidden'));
cancelCharBtn.addEventListener('click', () => charModal.classList.add('hidden'));

saveCharBtn.addEventListener('click', () => {
    const name = document.getElementById('new-char-name').value;
    const role = document.getElementById('new-char-role').value;
    
    if (name) {
        const newChar = { id: Date.now(), name, role };
        characters.push(newChar);
        localStorage.setItem('studio_bible_data', JSON.stringify({ characters }));
        
        renderCharacters();
        updateGraph();
        charModal.classList.add('hidden');
        
        document.getElementById('new-char-name').value = '';
        document.getElementById('new-char-role').value = '';
    }
});

initGraph();
loadBible();
