# GitHub Copilot Instructions

All code comments should be written in English.

All messages, including error messages, should be written in English.

README.md should be written in English.

## QML Development Rules

### QML Linting
- **Always run QML linting after editing QML files**
- Use `/usr/lib/qt6/bin/qmllint` to validate QML syntax and detect issues
- Run linting command: `/usr/lib/qt6/bin/qmllint <filename>.qml`
- Fix any warnings or errors before committing QML changes
- This helps catch syntax errors, import issues, and other QML-specific problems early

### QML Plugin Naming (CRITICAL)
- **QML plugins MUST have `lib` prefix in filename to be found by QML engine**
- If CMake generates `someplugin.so`, create symlink: `libsomeplugin.so -> someplugin.so`
- This fixes "module 'ModuleName' plugin 'pluginname' not found" errors
- **REMEMBER**: This exact issue was solved twice - always check plugin filename format first!

### Example Usage
```bash
# After editing any .qml file, run:
/usr/lib/qt6/bin/qmllint contents/ui/config.qml
/usr/lib/qt6/bin/qmllint contents/ui/main.qml
```

## Project-Specific Guidelines

### LibVisual Wallpaper Development
- This is a KDE Plasma 6 wallpaper plugin project
- Uses Qt 6, QML, C++ backend with PulseAudio and FFTW3
- Always validate QML files with qmllint after modifications
- Follow KDE/Plasma coding standards for wallpaper plugins
- Test configuration UI loading after QML changes

### Build and Test Workflow
1. Make code changes
2. **Run qmllint on modified QML files**
3. Build with CMake: `make -j$(nproc)`
4. Install: `make install`
5. **Check QML plugin has `lib` prefix** (`libpluginname.so`)
6. Test wallpaper and configuration in Desktop Settings

### Common Issues
- **QML Plugin Not Found**: Always check if plugin file has `lib` prefix
- **Library Dependencies**: Use `ldd` to check if backing libraries are found
- **Permissions**: QML plugins need execute permissions (`chmod +x`)
- **Multiple Installations**: Clean old installations in `/usr/local/` that may conflict