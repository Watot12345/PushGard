# PushGard — Defend Your EGO

Competitive 1v1 head-to-head push-up battles with a **Tug-of-War Knockout Bar (`+15` rep lead = Instant KO)**, **60-second timed decisions**, **Win/Loss Elo Ego Ranking**, and **100% on-device camera pose tracking**.

---

## Publishing Setup (GitHub Pages & GitHub App Releases)

This repository is pre-configured with automated CI/CD pipelines and local release tooling:

| Pipeline | File | What It Does |
| :--- | :--- | :--- |
| **GitHub Pages (Web Beta Hub + Live App)** | [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml) | Verifies `thresholds.json`, runs `flutter analyze` & `flutter test`, builds Flutter Web (`--release`), and deploys [`web-portal/index.html`](web-portal/index.html) (`/` Beta Hub) + `/app/` (Live Web App) to GitHub Pages on every push to `main`. |
| **GitHub App Releases (Android APK & AAB)** | [`.github/workflows/release-apk.yml`](.github/workflows/release-apk.yml) | Triggers on any `v*` tag (e.g. `v1.0.0-beta.1`) or manual dispatch. Builds universal APK, split-ABI APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`), and `.aab`, generates `SHA256SUMS.txt`, and publishes a GitHub Release. |
| **Local Release Builder** | [`scripts/prepare_release.sh`](scripts/prepare_release.sh) | Runs all checks and stages the complete GitHub Pages site in `dist/gh-pages/` (pass `--apk` to also build the release APK locally). |

---

## Quick Publish Commands

### 1. Push to GitHub & Activate GitHub Pages
```bash
git add -A
git commit -m "feat: PushGard v1.0.0-beta.1 mobile arena, kinematic engine, and release pipelines"
git remote add origin https://github.com/<YOUR_USERNAME>/PushGard.git
git push -u origin main
```
> In your GitHub repo settings: go to **Settings → Pages → Build and deployment → Source** and select **GitHub Actions**.

### 2. Publish an Android APK Release on GitHub Releases
```bash
git tag v1.0.0-beta.1
git push origin v1.0.0-beta.1
```
This automatically triggers [`.github/workflows/release-apk.yml`](.github/workflows/release-apk.yml) and attaches `PushGard-android-universal.apk` to your GitHub Releases page (which the **"DOWNLOAD ANDROID APK"** button on your GitHub Pages site links to automatically).
