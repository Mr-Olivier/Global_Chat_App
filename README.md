# 💬 GlobalChat

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
</div>

<div align="center">
  <h3>Simple real-time chat application</h3>
  <p>Connect and chat with other users in real-time using Flutter and Firebase.</p>
</div>

---

## ✨ Features

- 🔐 **User Authentication** - Login and register with email
- 💬 **Real-time Chat** - Send and receive messages instantly
- 👤 **User Profiles** - View and edit your profile
- 🚪 **Logout** - Secure logout functionality
- 📱 **Cross-platform** - Works on Android and iOS

---

## 🛠️ Built With

- **Flutter** - Mobile app framework
- **Firebase Auth** - User authentication
- **Firebase Firestore** - Real-time database
- **Firebase Storage** - Profile image storage

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK installed
- Android Studio or VS Code
- Firebase project setup

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Mr-Olivier/Global_Chat_App
   cd globalchat
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Setup Firebase**

   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Add your app and download config files:
     - `google-services.json` → `android/app/`
     - `GoogleService-Info.plist` → `ios/Runner/`

4. **Run the app**
   ```bash
   flutter run
   ```

---

## 📱 How to Use

1. **Register/Login** - Create an account or login with existing credentials
2. **Chat** - Start chatting with other users
3. **Profile** - Tap on your profile to view and edit your information
4. **Logout** - Use the logout option when you're done

---

## 📁 Project Structure

```
lib/
├── screens/          # App screens (login, chat, profile)
├── widgets/          # Reusable UI components
├── services/         # Firebase services
├── models/           # Data models
└── main.dart         # App entry point
```

---

## 🤝 Contributing

1. Fork the project
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

---

<div align="center">
  <p>Made with ❤️ using Flutter and Firebase</p>
</div>
