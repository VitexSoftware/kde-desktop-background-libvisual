# Available Visualizations

This document describes the visualization options available for the KDE Desktop Background LibVisual project.

## LibVisual Plugins (Current Implementation)

The application currently uses libvisual-0.4 actor plugins. The following plugins are installed on the system:

### Installed LibVisual Plugins

1. **jess** - Jess visual plugin
   - Type: Abstract effects
   - File: `/usr/lib/libvisual-0.4/actor/actor_JESS.so`

2. **bumpscope** - Bump scope visualization
   - Type: Oscilloscope/waveform
   - File: `/usr/lib/libvisual-0.4/actor/actor_bumpscope.so`

3. **corona** - Corona effects
   - Type: Plasma/corona effects
   - File: `/usr/lib/libvisual-0.4/actor/actor_corona.so`

4. **lv_flower** - Flower pattern visualization
   - Type: Abstract/geometric
   - File: `/usr/lib/libvisual-0.4/actor/actor_flower.so`

5. **gstreamer** - GStreamer-based visualization
   - Type: Integration with GStreamer
   - File: `/usr/lib/libvisual-0.4/actor/actor_gstreamer.so`

6. **infinite** - Infinite fractals
   - Type: Fractal visualization
   - File: `/usr/lib/libvisual-0.4/actor/actor_infinite.so`

7. **jakdaw** - Spectral analyzer
   - Type: Spectrum analyzer
   - File: `/usr/lib/libvisual-0.4/actor/actor_jakdaw.so`

8. **lv_analyzer** - Audio spectrum analyzer
   - Type: Frequency analyzer
   - File: `/usr/lib/libvisual-0.4/actor/actor_lv_analyzer.so`

9. **lv_gltest** - OpenGL test visualization
   - Type: OpenGL demo/test
   - File: `/usr/lib/libvisual-0.4/actor/actor_lv_gltest.so`

10. **lv_scope** - Oscilloscope
    - Type: Waveform display
    - File: `/usr/lib/libvisual-0.4/actor/actor_lv_scope.so`

11. **madspin** - Spinning effects
    - Type: Rotating/spinning effects
    - File: `/usr/lib/libvisual-0.4/actor/actor_madspin.so`

12. **nastyfft** - FFT-based visualization
    - Type: Frequency spectrum
    - File: `/usr/lib/libvisual-0.4/actor/actor_nastyfft.so`

13. **oinksie** - Oinksie effects
    - Type: Abstract effects
    - File: `/usr/lib/libvisual-0.4/actor/actor_oinksie.so`

**Total LibVisual plugins: 13**

### Notable Missing Plugins

The README.md mentions some plugins that are not currently installed:
- **gforce** - Advanced abstract effects (not found)
- **nebulus** - Nebula effects (not found)

These may require additional packages or compilation from source.

## ProjectM Integration (Recommended Addition)

projectM is a modern, actively maintained music visualization library that is Milkdrop-compatible. It offers significantly more presets and better performance than libvisual.

### ProjectM Statistics

- **Total presets available: 4,188** (.milk files)
- **Preset collections:**
  - presets_bltc201 (large collection)
  - presets_eyetune
  - presets_milkdrop (classic Winamp Milkdrop presets)
  - presets_milkdrop_104
  - presets_milkdrop_200
  - presets_mischa_collection
  - presets_projectM
  - presets_stock
  - presets_tryptonaut (very large collection)
  - presets_yin

### Sample ProjectM Presets

- "Temporal singularities"
- "Van Gogh's nightmare"
- "Survival of the fastest"
- "Through the ether"
- "Pyrotechnics"
- "Dance with the ocean"
- ...and 4,180+ more

### ProjectM Advantages

1. **Modern codebase** - Actively maintained (https://github.com/projectM-visualizer/projectm)
2. **Huge preset library** - 4,188 presets vs 13 libvisual plugins
3. **Milkdrop compatible** - Can use classic Winamp Milkdrop presets
4. **Better performance** - Optimized OpenGL rendering
5. **Cross-platform** - Works on Linux, Windows, macOS
6. **Better documentation** - Active community and development

### ProjectM API

ProjectM provides a C++ API with the following key classes:
- `projectM` - Main visualization engine
- Preset loading and switching
- Audio PCM data input
- OpenGL texture output
- Configuration for preset directories

### Integration Requirements

To add projectM support:

**Dependencies:**
```bash
sudo apt install libprojectm-dev projectm-data
```

**Build flags:**
```bash
pkg-config --cflags --libs libprojectM
```

**Key features to implement:**
- Create `src/projectm_renderer.cpp/h`
- Initialize projectM with preset directories
- Feed audio PCM data from PulseAudio
- Render to OpenGL texture or framebuffer
- Support preset switching/randomization
- Configuration for preset path and settings

## Recommendation

**For the best user experience**, consider implementing a hybrid approach:

1. **Keep LibVisual support** for backward compatibility and simplicity
2. **Add ProjectM support** as the primary/recommended visualization engine
3. **Allow users to choose** between LibVisual and ProjectM in settings
4. **Default to ProjectM** when available, fallback to LibVisual

This would provide:
- 13 LibVisual plugins + 4,188 ProjectM presets = 4,201 total visualizations
- Better visual quality with ProjectM
- More variety and modern effects
- Backward compatibility with existing LibVisual setups

## Usage in Application

### Current LibVisual Usage

```cpp
// From src/visualizer.cpp
m_visualizer->loadPlugin("jakdaw");  // Load spectral analyzer
m_visualizer->processAudio(audioData, samples);
m_visualizer->render();
unsigned char* frame = m_visualizer->getVideoData();
```

### Proposed ProjectM Usage

```cpp
// Proposed for src/projectm_renderer.cpp
projectM* pm = new projectM("/usr/share/projectM/presets");
pm->pcm()->addPCM16(audioData, samples);
pm->renderFrame();
// Extract texture or framebuffer for display
```

## Performance Considerations

- **LibVisual**: CPU-based rendering, lower resource usage
- **ProjectM**: OpenGL-based rendering, higher visual quality but requires GPU

For desktop background rendering, projectM's GPU acceleration would be beneficial as it offloads work from the CPU while providing better visual effects.
