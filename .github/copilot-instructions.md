# GitHub Copilot Instructions

## QML Development Rules

### QML Linting
- **Always run QML linting after editing QML files**
- Use `/usr/lib/qt6/bin/qmllint` to validate QML syntax and detect issues
- Run linting command: `/usr/lib/qt6/bin/qmllint <filename>.qml`
- Fix any warnings or errors before committing QML changes
- This helps catch syntax errors, import issues, and other QML-specific problems early

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
5. Test wallpaper and configuration in Desktop Settings