# KeySwap Installation Guide

## System Requirements
- macOS 13.0 or later
- Apple Silicon (ARM64) or Intel Mac support
- Accessibility permissions enabled

## Installation Methods

### Method 1: DMG Installer (Recommended)
1. Download `KeySwap-1.0.0.0.dmg`
2. Double-click to mount the disk image
3. Drag the KeySwap.app to your Applications folder
4. Eject the disk image
5. Open Applications and launch KeySwap

### Method 2: ZIP Archive
1. Download `KeySwap-1.0.0.0.zip`
2. Extract the archive
3. Drag KeySwap.app to your Applications folder

### Method 3: Direct from Build
1. Open the project: `KeySwap.xcodeproj`
2. Select the KeySwap target
3. Build for Release: `Product > Build`
4. Find the app in `Derived Data` or build output directory

## First Launch Setup

When you first launch KeySwap:

1. **Grant Accessibility Permissions**
   - macOS will prompt you to allow KeySwap to use accessibility features
   - Open System Preferences > Security & Privacy > Accessibility
   - Add KeySwap to the allowed apps list if prompted

2. **Test the Feature**
   - Open any application that accepts text input
   - Type in Hebrew layout, then press `F9` to swap with English characters
   - Or type in English layout and press `F9` to swap with Hebrew characters

## Usage

### Basic Operation
- **Hotkey**: Press `F9` to swap the last typed word
- **Active Layouts**: Hebrew and English keyboard layouts
- **Fallback Mechanism**: If Accessibility API is unavailable, a clipboard-based fallback is used

### Features
- Bilingual character correction
- Accessibility-based clipboard integration
- Optional post-swap spell checking (macOS system spellcheck)

## Troubleshooting

### "Accessibility permissions denied"
- Open System Preferences > Security & Privacy > Accessibility
- Ensure KeySwap has permission

### "Hotkey doesn't work"
- Check that F9 is not bound to another application
- Verify that KeySwap is running (check Activity Monitor)
- Quit and relaunch KeySwap

### "Characters not swapping"
- Ensure the correct keyboard layouts are installed (Hebrew/English)
- Check that you're using supported keyboard layouts

## Uninstallation

Simply drag KeySwap.app from Applications to Trash.

## Support

For issues or feature requests, visit: https://github.com/eran-segev/KeySwap-MacOS
