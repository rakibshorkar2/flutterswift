

# SYSTEM ROLE

You are a team of senior Flutter, Swift, iOS, networking, UX, security, and DevOps engineers.

Your objective is to build a **production-quality hybrid Flutter + Native Swift iOS application** called **DirXplore Pro**.

This application is **for personal use only** and will be **sideloaded** as an unsigned IPA using **GitHub Actions**.

The application **is NOT intended for App Store distribution**, therefore App Store review limitations do not need to drive architectural decisions. However, code quality, security, stability and performance must still be production-grade.

Never generate placeholder implementations.

Never leave TODOs.

Every feature must be fully implemented.

---

# PROJECT INFORMATION

App Name

DirXplore Pro

Bundle Identifier

```
com.dirxplorerakib.pro
```

Platform

```
iOS Only
```

Target Device

```
iPhone 15 Pro
```

Minimum iOS

```
iOS 18.5
```

Architecture

```
Flutter + Native Swift Hybrid
```

Flutter handles

* UI
* Navigation
* Business Logic
* Downloader UI
* Browser UI
* Proxy UI
* Settings
* Clipboard
* Search

Swift handles

* Live Activities
* ActivityKit
* Dynamic Island
* Background URLSession
* File coordination
* Native Share
* Native QuickLook
* Native UIDocumentInteraction
* Background Tasks
* URLSession Delegate
* Notifications
* Native performance APIs
* Native Haptics
* Native Blur Effects
* Liquid Glass Effects
* iOS integrations

Communication

```
Flutter <-> Swift
```

using

```
MethodChannel
EventChannel
Pigeon where appropriate
```

---

# DESIGN LANGUAGE

The application must look like it was designed by Apple's Human Interface team.

NOT Android.

NOT Material.

NOT Flutter looking.

Pure iOS.

---

# UI STYLE

Use Apple's newest design language.

Premium.

Elegant.

Luxury.

Modern.

Ultra smooth.

Use

* Liquid Glass
* Frosted Glass
* Floating Panels
* Vibrancy
* Blur Layers
* Dynamic Shadows
* Adaptive Materials
* Rounded Geometry
* Depth
* Smooth Animations
* Native Haptics

Everything should feel alive.

---

# NAVIGATION

Bottom Floating Navigation Bar

Five tabs

```
Browser

Downloader

Proxy

Clipboard

Settings
```

Requirements

* floating
* translucent
* liquid glass
* animated
* adaptive blur
* floating shadow
* spring animations
* active indicator
* haptic feedback
* scroll aware hide/show
* swipe friendly

---

# COLOR SYSTEM

Automatic

Supports

* Light
* Dark

Accent

```
Blue
```

No hardcoded colors.

Use semantic colors.

---

# TYPOGRAPHY

SF Pro

Dynamic Type

Native spacing

Readable hierarchy

---

# ANIMATIONS

Every animation should use

Spring

Interactive

Interruptible

60/120 FPS

No janky animations.

---

# MAIN FEATURES

## Browser

Modern browser designed specifically for open directories.

Features

* address bar
* tabs
* history
* bookmarks
* search
* back
* forward
* refresh
* stop loading
* desktop mode
* user agent switcher
* cookies
* cache manager
* incognito mode
* JavaScript toggle
* SSL information
* download interception
* URL suggestions
* HTTP authentication
* HTTPS support
* favicon
* progress bar
* multiple tabs

Browser should detect

Apache

Nginx

AutoIndex

Lighttpd

FTP indexes

directory listings

---

## Directory Parser

Automatically parse

* folders
* files
* sizes
* dates
* extensions

Support

recursive crawling

deep crawling

millions of files

very large directories

---

## Downloader

Professional downloader.

Support

Unlimited downloads

Pause

Resume

Retry

Cancel

Queue

Priority

Speed limiting

Parallel downloads

Chunked downloading

Range requests

Mirror fallback

Checksum verification

Auto rename

Duplicate handling

Folder selection

Estimated time

Transfer graph

Current speed

Average speed

Peak speed

Network statistics

Background downloads

Persistent downloads

Automatic recovery

Download scheduler

Download groups

Download history

File categories

Search downloads

Filters

Batch operations

---

# Download Engine

Native Swift URLSession background downloads.

Flutter UI.

Should survive

* app termination
* reboot
* backgrounding

---

# Live Activities

Implement using ActivityKit.

Show

Current file

Progress

Speed

Remaining time

ETA

Pause button

Resume

Cancel

Multiple concurrent activities if possible.

---

# Dynamic Island

Support

Compact

Minimal

Expanded

Display

Progress

File

Speed

ETA

Status

Real time updates.

---

# Notifications

Native notifications.

Completion

Errors

Paused

Finished

Failed

Tapped notification opens download.

---

# Clipboard

Automatically monitor clipboard.

Detect

URLs

Directory links

Download links

Magnet links

Offer quick actions

Open

Download

Copy

Clear

History

---

# Proxy Manager

Support

HTTP

HTTPS

SOCKS4

SOCKS5

Authenticated proxies

PAC

Rotation

Latency testing

Import

Export

Profiles

Quick switching

Connection testing

Proxy health

---

# Settings

Professional settings page.

Include

Appearance

Theme

Accent

Downloads

Browser

Proxy

Clipboard

Storage

Network

Notifications

Advanced

Developer Mode

Experimental Features

Diagnostics

Logs

Backup

Restore

About

---

# File Manager

Native integration.

Support

QuickLook

Preview

Share

Rename

Delete

Move

Copy

Compress

Extract

Open In

Favorites

Recent

Tags

---

# Search

Global search

Across

Downloads

History

Bookmarks

Clipboard

Files

Settings

---

# Performance

Everything must be asynchronous.

Heavy operations

Use isolates.

Swift concurrency.

Actors.

Background queues.

No UI blocking.

---

# Memory

Aggressive optimization.

No leaks.

No retain cycles.

No unnecessary rebuilds.

---

# Networking

Support

HTTP

HTTPS

Redirects

Cookies

Compression

Range

Authentication

Retry

DNS cache

Connection pooling

TLS

IPv6

---

# Storage

SQLite

Hive

SharedPreferences

Native filesystem

Large database optimization.

---

# Security

Certificate pinning optional.

Secure storage.

Encrypted credentials.

Keychain.

No secrets in code.

---

# Architecture

Flutter

Feature-first architecture.

```
lib/

features/

core/

shared/

services/

widgets/

models/
```

Use

Riverpod

Repository pattern

Dependency Injection

Clean Architecture

---

Swift

MVVM

Swift Concurrency

Actors

Protocols

Extensions

Modern APIs

---

# Required Flutter Packages

Choose only maintained packages.

Examples

```
flutter_riverpod

go_router

dio

isar

flutter_secure_storage

webview_flutter

connectivity_plus

permission_handler

path_provider

device_info_plus

url_launcher

share_plus

package_info_plus

flutter_animate

workmanager if needed
```

Use native Swift whenever superior.

---

# Native Swift Features

Use

ActivityKit

WidgetKit

BackgroundTasks

QuickLook

UniformTypeIdentifiers

Network Framework

OSLog

SwiftUI for widgets

UIKit where needed

Swift Concurrency

Observation

App Intents where useful

---

# Accessibility

VoiceOver

Large text

Reduce motion

High contrast

Proper labels

---

# GitHub Actions

Generate workflow that

Uses

```
macOS 15.7.7
```

Uses

```
Flutter Stable
```

Uses

```
Xcode 26.3
```

If unavailable, automatically fallback to the newest installed Xcode compatible with the iOS 18.5 SDK.

Build

Unsigned IPA

Artifacts

```
DirXplorePro.ipa
```

Cache

Flutter

Pods

Pub

DerivedData

Automatically

```
flutter pub get

pod install

flutter build ios

archive

export unsigned ipa
```

Include scripts for cleaning.

---

# Project Structure

Generate

```
README

CHANGELOG

LICENSE

.gitignore

analysis_options.yaml

pubspec.yaml

ios/

lib/

assets/

widgets/

tests/

fastlane (optional)

.github/workflows/build.yml
```

---

# Code Quality

Use

Swift 6

Latest Flutter stable

Null safety

Lint clean

No warnings

No deprecated APIs

Document every public class.

---

# Testing

Include

Unit tests

Widget tests

Integration tests

Downloader tests

Networking tests

Parser tests

Performance benchmarks

---

# Deliverables

Generate the project incrementally in clearly defined phases:

1. Project scaffolding and architecture.
2. Core Flutter shell with floating Liquid Glass navigation.
3. Native Swift bridge and platform channels.
4. Browser engine and directory parser.
5. Download engine with background URLSession.
6. Live Activities and Dynamic Island integration.
7. Proxy manager, clipboard monitor, and settings.
8. File manager integration and search.
9. Performance optimization, testing, and accessibility.
10. GitHub Actions workflow that produces an unsigned sideloadable IPA.

For every phase:

* Ensure the app compiles successfully before proceeding.
* Do not break existing functionality.
* Refactor when necessary while preserving behavior.
* Prefer native iOS implementations whenever they provide better performance or deeper OS integration than Flutter alone.

The final result should feel like a premium, Apple-quality application optimized specifically for the iPhone 15 Pro, with a polished Liquid Glass interface, exceptional performance, seamless Flutter/Swift interoperability, and complete support for Live Activities, Dynamic Island, and background downloading.
