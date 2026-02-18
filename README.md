# 📖 Yomu

**Yomu** is a premium, all-in-one reading companion designed for book lovers and audiobook enthusiasts. Whether you're diving into an EPUB, studying a PDF, or listening on the go, Yomu tracks your progress and gamifies your reading journey to help you reach your goals.

---

## ✨ Key Features

### 📚 Versatile Reader
- **Multi-Format Support**: Seamlessly read **EPUB** and **PDF** files with a smooth, optimized interface.
- **Audiobook Integration**: Enjoy your favorite audiobooks with built-in playback controls.
- **Smart Loading**: Efficiently handle large files with intelligent caching and background rendering.

### 📊 Intelligent Tracking
- **Progress Monitoring**: Track exactly how many pages and minutes you've read.
- **Time-Based Accuracy**: Advanced logic differentiates between active reading and skimming.
- **Goal Setting**: Set weekly reading goals (by pages) to stay consistent.

### 🎮 Gamified Experience
- **Ranks & Levels**: Progress from *Kohai* to *Tatsujin* based on both your **Level (XP)** and **Achievements**.
- **Dynamic Achievement Ranking**: Your achieved badges are automatically moved to the top of your collection for quick viewing.
- **Level-Up Celebrations**: Visually stunning rewards and celebrations when you hit new milestones.
- **Activity Visualizations**: Beautiful charts and insights into your reading habits.

| Rank | Level Required | Achievements Required |
| :--- | :--- | :--- |
| **Kohai** (後輩) | 1 | 0 |
| **Yomite** (読み手) | 5 | 2 |
| **Senpai** (先輩) | 10 | 5 |
| **Chousha** (著者) | 20 | 8 |
| **Sensei** (先生) | 40 | 10 |
| **Tatsujin** (達人) | 50 | 12 |

### 🗂️ Library Management
- **Shelf Organization**: Keep your collection tidy with customizable shelves.
- **Duplicate Prevention**: Automatic content-based hashing ensures your library stays unique.
- **History Preservation**: Choose to keep your reading stats even if you remove a book.

---

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev)
- **State Management**: [Riverpod](https://riverpod.dev)
- **Database**: [SQLite](https://pub.dev/packages/sqflite)
- **E-Book Rendering**: `epub_view`, `pdfrx`
- **Audio Playback**: `just_audio`
- **Animations**: `flutter_animate`, `animations`

---

## 📁 Project Structure

```text
lib/
├── components/ # Reusable UI widgets (cards, charts, etc.)
├── core/       # App themes, constants, and utilities
├── models/     # Data models (Book, History, Goal)
├── providers/  # Riverpod providers for state management
├── screens/    # Feature-specific screens (Library, Reader, Dashboard)
└── services/   # Database and file system services
```

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

> [!TIP]
> **Priority Contribution**: We are actively looking for a robust **Text Highlighting** feature for both EPUB and PDF readers. If you're looking for a way to make a big impact, this is it!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.
