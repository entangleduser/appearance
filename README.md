## Appearance

A menu bar app that controls the appearance of a system (macOS)

![](https://raw.githubusercontent.com/entangleduser/appearance/main/Assets/Preview@Dark.png#gh-dark-mode-only)
![](https://raw.githubusercontent.com/entangleduser/appearance/main/Assets/Preview@Light.png#gh-light-mode-only)

### Modules
#### Auto Appearance
- Automatically changes appearance based on location and solar phase.
> [!TIP]
> Location can be set manually in `Settings` menu.

- Uses system events to ‘tell’ system appearance to change themes or can smoothly transition with permission to record the screen.
> [!NOTE]
> System appearance apparently has privileges to record the screen (without an indicator) by default. But this appears to be necessary in order to create the transition effect.

> [!WARNING]
> In some cases the system will ask for screen recording permissions after enabling. To fix this, please follow the instructions below.
> - Go to `System Settings > Privacy & Security > Screen & System Audio Recording`.
> - Remove the app under `Screen & System Audio Recording`, then restart the process.

### Sources
- [Nightfall](https://github.com/r-thomson/Nightfall) to effectively transition between themes.
- [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) to observe and set changes to start at login functionality.
