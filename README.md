# 🧹 Spatio — Smart Floor Plan & Family Chore Management

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Realtime%20%26%20Auth-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Drift SQLite](https://img.shields.io/badge/Drift-Local%20SQLite-4479A1?style=for-the-badge&logo=sqlite&logoColor=white)
![Riverpod](https://img.shields.io/badge/Riverpod-State%20Management-00599C?style=for-the-badge)
![Tests](https://img.shields.io/badge/Tests-140%2F140%20Passed-success?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)

**Spatio** is a modern, gamified household management and cleaning application featuring an interactive 2D vector architectural floor plan, multi-floor navigation, real-time collaborator presence, and an engaging rewards system for children.

</div>

---

## 🌟 Key Features

### 📐 1. Interactive 2D Vector Architectural Floor Plan
- **Multi-Floor Support:** Switch effortlessly between Ground Floor, 1st Floor, and higher levels with dynamic staircase detection and transitions.
- **Precision Wall Drawing:** Interactive polygon wall drawer with configurable grid snapping (10px, 20px, 50px) using Ray-Casting (Jordan Curve theorem) and Green's Theorem centroid calculation.
- **Rich 50+ Item Furniture Catalog:** 11 categorized room groups (Living Room, Bedroom, Kitchen, Bathroom, Dining, Office, Kids & Play, Laundry, Utility & Gym, Outdoor, Stairs) with accurate Material icons, emojis, and dimensions.
- **Collision Detection:** Real-time Axis-Aligned Bounding Box (AABB) collision checks prevent accidental furniture overlaps.
- **Sims-Style Furniture Placement:** Ghost cursor preview, rotation controls (90° increments), and dimensional tweaking.

### 🧹 2. Intelligent Cleanliness Engine
- **Dynamic Cleanliness Scoring (0–100%):** Calculates real-time hygiene scores based on pending tasks, priority levels (1–5), and overdue deadlines with exponential penalization.
- **Visual Status Badging:** Clear visual distinction between rooms and furniture with material-tinted fills, outer architectural walls, and drop shadows.
- **Hierarchical Inspection:** Tap any room or piece of furniture to immediately inspect assigned chores, due dates, and completion status.

### ⚡ 3. Realtime Presence & Multi-Device Sync
- **Supabase Realtime Presence:** See what family members are doing live (*"👧 Anna is placing Double Bed"*, *"👦 Ben is typing a task"*).
- **Collaborator Badges & Room Highlights:** Active rooms glow with a collaborator aura on the floor plan canvas.
- **Offline-First Resilience:** Seamless two-way synchronization between cloud Supabase Postgres and local Drift SQLite with offline mutation queueing.

### 🎁 4. Child Gamification & Custom Rewards Store
- **Celebration Effects:** Rewarding task completion animations with 65-particle gravity confetti, bouncy trophies, streak counters, and level progression badges (*Apprentice Cleaner -> Master Cleaner*).
- **Parent Custom Rewards:** Adults can design custom household rewards (e.g., 🍦 Ice cream trip, 🎮 1 hour gaming time) with point costs and inventory caps.
- **Atomic Point Redemptions:** Backed by atomic PostgreSQL RPC transactions ensuring points and inventory stay strictly consistent without race conditions.

### 🔐 5. Multi-Tenant Family Security & RBAC
- **Household Data Isolation:** Strict multi-tenant isolation ensures family data is strictly accessible only to household members.
- **Role-Based Access Control (RBAC):** Parents can edit floor plans and manage rewards; children have safe access to view tasks and redeem points.
- **Password Strength & Live Form Validation:** Instant client-side validation with real-time requirement chip tracking.

---

## 🏗️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── constants/        # Centralized localization strings & configuration
│   ├── database/         # Drift SQLite schema, migrations & cross-platform connections
│   ├── network/          # Supabase client initialization & connection lifecycle
│   ├── services/         # CleanlinessEngine, PresenceService, SyncService, AuthService
│   ├── theme/            # Material Design 3 theme system
│   └── widgets/          # Reusable UI components (TaskCelebrationOverlay, etc.)
└── features/cleaning_tasks/
    ├── data/             # Remote & Local datasources, DTOs, Repository implementations
    ├── domain/           # Pure entities (Room, TaskItem, FurnitureItem, Reward, AppUser)
    └── presentation/     # Riverpod controllers, CustomFloorPainter, screens & dialogs
```

- **Frontend Framework:** [Flutter](https://flutter.dev) (iOS, Android, Web)
- **State Management:** [Flutter Riverpod](https://riverpod.dev)
- **Backend / Cloud:** [Supabase](https://supabase.com) (PostgreSQL, Auth, Realtime WebSocket Presence, RPC)
- **Local Persistence:** [Drift](https://drift.simonbinder.eu) (SQLite) with WebAssembly (`sqlite3.wasm`) support
- **Testing:** Custom `MasterTestRunner` orchestrator covering 140 automated tests with zero database residue guarantee.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.13.3`)
- Dart SDK (`>= 3.1.0`)
- Android Studio / Xcode (for mobile deployments)

### 1. Clone the repository
```bash
git clone https://github.com/<your-username>/spatio.git
cd spatio
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Run automated tests
Run the full test suite with 100% in-memory database isolation:
```bash
flutter test test/master_test_runner.dart
```

### 4. Run the application
```bash
# Web
flutter run -d chrome

# Android / iOS
flutter run
```

### 5. Build an Android Release APK
```bash
flutter build apk --release
```
The compiled APK will be located at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Testing Suite & Quality Assurance

Spatio features an enterprise-grade Master Test Suite verifying:
- **Domain & Use Cases:** Task load-balancing, immutability, date formatting, and state transitions.
- **Geometry & Graphics:** Jordan Curve ray-casting polygon hits, AABB bounding collisions, and Green's Theorem centroid calculation.
- **Engine Logic:** Exponential penalty decays and cleanliness score clamping.
- **Database & Offline Sync:** RAM-isolated Drift SQLite transactions and cascade deletions with zero residue.
- **Diagnostic Benchmarks:** 10,000 ray-casts in < 150ms and 50,000 entity memory leak stability.

Run tests anytime with:
```bash
flutter test
```

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
