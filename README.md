# Srishty — Your Stories, Amplified.

Srishty is a premium storytelling and reading platform built for a modern audience. It combines the community aspects of Instagram and Wattpad with the professional reading experience of Kindle and the immersive listening of Audible.

## 🚀 Key Features

- **📖 Premium Reader**: Glassmorphic UI with customizable typography and dark-mode support.
- **🎧 Audio Library**: Full audiobook integration with background playback and speed control.
- **✍️ Author Studio**: Simple, multi-step creation flow for sharing stories and audio.
- **🔥 Trending & Discovery**: Region-aware content discovery for local and global stories.
- **🤝 Social Ecosystem**: Follow your favorite authors, like, and comment on stories.

## 🏗️ Architecture

The platform follows a modern, multi-tier architecture:

- **Frontend (Flutter)**: A single codebase for Android, iOS, Windows, and MacOS. Uses **Riverpod** for state management and **Dio** for API communication.
- **Backend (Django)**: A powerful REST API using **Django REST Framework (DRF)**. Features include JWT authentication, media storage, and social logic.
- **Web Client (Vanilla JS/CSS)**: A fast, read-only gallery for public content discovery.
- **Web Admin**: A dedicated dashboard for managing the platform's ecosystem.

## 🛠️ Getting Started

### Prerequisites

- Flutter SDK (^3.11.3)
- Python (^3.10)
- Node.js (for web tools)

### Installation

1. **Clone the repository**
   ```bash
   git clone [repository-url]
   cd booksrishty
   ```

2. **Backend Setup**
   ```bash
   cd backend
   pip install -r requirements.txt
   python manage.py migrate
   python populate_fake_data.py
   python manage.py runserver
   ```

3. **Frontend Setup**
   ```bash
   cd frontend
   flutter pub get
   flutter run
   ```

## ⚖️ License

Copyright © 2026 Srishty Platform. All rights reserved.
The platform is provided for free as part of our mission to amplify storytelling.
