# Srishty - Product Description Page (PDP)

## 📌 Executive Summary
**Srishty** is a premium storytelling and reading platform designed for a modern audience. It aims to bridge the gap between social community platforms like Instagram/Wattpad and professional reading/listening experiences like Kindle/Audible. Srishty is entirely free for all users, focusing on amplifying storytelling without monetization barriers.

## 🎯 Target Audience
- **Readers & Listeners:** Users looking for a seamless, immersive, and customizable reading or audiobook listening experience.
- **Writers & Audio Creators:** Storytellers who want a modern "Author Studio" to publish text or audio content and build an engaged community.
- **Social Explorers:** Users who enjoy discovering new content and interacting directly with authors through likes, comments, and follows.

---

## 🚀 Key Consumer Features (Free Access)

### 📖 Premium Reading Experience
- **Custom Renderer:** Markdown-lite renderer offering a clean, distraction-free reading interface.
- **Personalization:** Granular controls for typography, font sizes, and comprehensive dark-mode support.
- **Glassmorphic UI:** A visually stunning, modern app aesthetic emphasizing transparent, frosted-glass interface elements.

### 🎧 Audio Library Integration
- **Immersive Listening:** Full audiobook playback support alongside traditional reading.
- **Advanced Player Controls:** Background playback capabilities and adjustable playback speeds.

### ✍️ Author Studio
- **Streamlined Publishing:** A simple, multi-step creation flow for sharing stories and audio.
- **Unified Media:** Ability to publish standard text chapters or audio-focused content seamlessly.

### 🌍 Discovery & Social Ecosystem
- **Trending & Discovery:** Region-aware content discovery engine highlighting both local and global stories.
- **Social Networking:** Instagram-style profiles allowing users to follow their favorite authors.
- **Community Engagement:** Built-in interactions including likes, comments, and unified search for books, authors, and genres.

---

## 🏗️ Technical Architecture & Stack

Srishty is built horizontally across multiple platforms to ensure maximum reach and performance.

### 1. Frontend: Mobile & Desktop Applications
- **Framework:** Flutter (Cross-platform for Android, iOS, Windows, Mac, and Web).
- **State Management:** Riverpod.
- **API Communication:** Dio.
- **Design Language:** Glassmorphism, smooth micro-interactions, responsive scaling.

### 2. Backend: Core API Server
- **Framework:** Django & Django REST Framework (DRF) in Python.
- **Core Modules:**
  - `accounts`: JWT Authentication and user profile management.
  - `core`: Story, chapter, and media management.
  - `social`: Social graphing, likes, comments, and following logic.
- **Database:** SQLite (development default) / PostgreSQL/MySQL (production ready).

### 3. Web Client (Gallery/Discovery)
- **Tech Stack:** Vanilla JavaScript, HTML5, Vanilla CSS (`index.html`, `app.js`, `style.css`).
- **Purpose:** A fast, lightweight, read-only gallery for public content discovery. Includes a lightweight web-based studio (`studio.html`, `studio.js`) for basic publishing.

### 4. Web Admin Dashboard
- **Purpose:** Dedicated dashboard for monitoring platform health and managing the ecosystem.

---

## 🛠️ Development & Deployment

### Prerequisites
- **Flutter SDK:** `^3.11.3`
- **Python:** `^3.10`
- **Node.js:** For associated web tooling.

### Installation & Getting Started
Developers can easily set up the stack:
1. **Backend:** Install `requirements.txt`, run migrations (`python manage.py migrate`), and seed the database (`python populate_fake_data.py`).
2. **Frontend:** Run `flutter pub get` and execute on standard mobile emulators or desktop targets.

### Testing Strategy
- **Frontend:** Flutter Analyzer (`flutter analyze`) for code health.
- **Backend:** Django unit tests for API integrity and workflow validation.

---

## ⚖️ Licensing
Copyright © 2026 Srishty Platform. 
Srishty is provided as a free platform, dedicated to its mission to amplify storytelling worldwide.
