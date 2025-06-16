# campusquest

CampusQuest is a cross-platform Flutter application designed for managing academic resources, notes, events, and user roles (students, instructors, admins) in a campus environment.


## Features

- User authentication and role-based access (Student, Instructor, Admin)
- Course and program management
- Notes and file uploads/downloads (with Supabase storage integration)
- Event scheduling and management
- Timetable and attendance tracking
- Assignment creation and submission
- Cross-platform support: Android, iOS, Windows, Linux, macOS, Web

## Project Structure

```
campusquest/
├── android/           # Android native code & build files
├── assets/            # App assets (images, etc.)
├── build/             # Build outputs (auto-generated)
├── campusquest/       # (May contain additional project files)
├── ios/               # iOS native code & build files
├── lib/               # Dart source code
│   ├── Data/          # Static data (e.g., notes_data.dart)
│   └── modules/       # App modules (admin, student, etc.)
├── linux/             # Linux desktop support
├── macos/             # macOS desktop support
├── test/              # Unit and widget tests
├── web/               # Web support
├── windows/           # Windows desktop support
├── pubspec.yaml       # Flutter/Dart dependencies and metadata
├── README.md          # Project documentation
└── ...                # Other config and metadata files
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Dart SDK (comes with Flutter)
- Android Studio/Xcode/Visual Studio (for platform-specific builds)
- Supabase account (for storage backend)

### Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/Krut369/campusquest.git
   cd campusquest
   ```

2. **Install dependencies:**
   ```sh
   flutter pub get
   ```

3. **Configure Supabase:**
   - Update your Supabase credentials in the appropriate Dart files (usually in a config or service file).

4. **Run the app:**
   - For mobile:
     ```sh
     flutter run
     ```
   - For desktop (Windows/Linux/macOS):
     ```sh
     flutter run -d windows   # or linux, macos
     ```
   - For web:
     ```sh
     flutter run -d chrome
     ```

## Building for Release

- **Android:**  
  `flutter build apk` or `flutter build appbundle`
- **iOS:**  
  `flutter build ios`
- **Windows/Linux/macOS:**  
  `flutter build windows` (or `linux`, `macos`)
- **Web:**  
  `flutter build web`

## Testing

Run all tests with:
```sh
flutter test
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/YourFeature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/YourFeature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License.

## Demo Videos

### Student Demo


https://github.com/user-attachments/assets/4d405968-7abf-4420-9acc-c3e0669618c9


###

Instructor

https://github.com/user-attachments/assets/abffa4db-90d4-43a8-a0de-aa0c321909b5


### Admin Demo


https://github.com/user-attachments/assets/9a0f69e3-5e9e-41af-93b9-28f4fd2a943c


---

For more information, see the [Flutter documentation](https://docs.flutter.dev/).
