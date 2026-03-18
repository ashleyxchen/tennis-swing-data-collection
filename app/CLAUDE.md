# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app for watch motion data collection, built with Capacitor (app ID: `com.ashleyc.watchmotiondata`). The web layer uses vanilla JavaScript with Web Components (no framework), bundled by Vite. The native iOS shell is managed by Capacitor.

## Commands

- `npm start` — Start Vite dev server (serves from `src/`)
- `npm run build` — Build to `dist/` (Vite, no minification)
- `npx cap sync ios` — Sync web assets and Capacitor plugins to the iOS project
- `npx cap open ios` — Open the Xcode project at `ios/App/App.xcodeproj`

## Architecture

- **Web layer** (`src/`): Single-page app using vanilla JS Web Components (`<capacitor-welcome>`, `<capacitor-welcome-titlebar>`). Entry point is `src/index.html`, which loads `src/js/capacitor-welcome.js` as a module.
- **Vite config**: Root is `./src`, output goes to `../dist`. No minification.
- **iOS native** (`ios/`): Standard Capacitor iOS project. `AppDelegate.swift` is the native entry point. Swift Package Manager dependencies are declared in `ios/App/CapApp-SPM/Package.swift` (managed by Capacitor CLI — do not edit manually).
- **Capacitor plugins**: Camera and SplashScreen are currently integrated. SplashScreen auto-hide is disabled (`launchAutoHide: false` in `capacitor.config.json`); it is hidden programmatically in JS.
- **Build output**: `dist/` is the web assets directory that gets copied into `ios/App/App/public/` on `cap sync`.
