# SkillConnect app icon

The icon uses two interlocking white and mint links that form an S, representing
skilled people connecting. The royal-blue background follows the app's existing
primary color. Bold geometry and generous margins keep the mark legible in
small launcher icons and inside circular or rounded masks.

Source artwork: `mobile/assets/icon/skillconnect-icon.png`.
Generation mode: built-in `image_gen` tool.
The original generated artwork is retained in the source asset; platform icon
sizes are produced by `flutter_launcher_icons`.

## Regenerate platform sizes

```sh
cd mobile
flutter pub get
dart run flutter_launcher_icons
```

Configuration: `mobile/flutter_launcher_icons.yaml`. Generated assets cover
Android density variants and adaptive icons, iOS app icons and the web favicon
and install icons. The same source is bundled in Flutter for `BrandIcon` in the
app header and guest account screen. The icon update is version 1.1.1, build 4.

## Final generation prompt

> Use case: logo-brand. Create one final production app icon for SkillConnect,
> a trusted local marketplace connecting customers with skilled service
> professionals. Square 1024x1024 artwork. Professional, distinctive, extremely
> clean vector-like flat geometry: two bold interlocking rounded links forming
> a subtle S monogram, representing skilled people connecting and dependable
> service. White main link and a restrained mint-teal second link on a solid
> rich royal blue background matching #2358D5. Precisely centered compact mark
> with generous safe margins: all foreground geometry contained within the
> central 58% of the canvas so it works in circular and squircle launcher masks.
> Elegant consistent thickness and optical balance, obvious at 32 pixels.
> Full-bleed square blue background, no rounded outer corners baked in. No text,
> no letters rendered as typography, no words, no tagline, no extra symbols,
> no tools, no hands, no scene, no presentation sheet, no phone mockup, no
> watermark. Avoid gradients, 3D effects, glow, shadows and fine strokes.
> Deliver just one beautifully polished icon.
