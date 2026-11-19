# Implementación en Flutter

Cómo se leen estos tokens desde el código de la app.

## Dónde vive cada cosa

| Qué | Archivo |
|---|---|
| Colores por tema | `lib/core/theme/app_colors.dart`: `AppColors` como `ThemeExtension`, con `AppColors.dark` y `AppColors.light` |
| Tipografía | `lib/core/theme/app_typography.dart`: `AppText` con un `TextStyle` por estilo |
| Espaciado, radios y tamaños | `lib/core/theme/app_tokens.dart`: `Space.s4`, `Radii.md`, `Sizes.touchMin` |
| `ThemeData` | `lib/core/theme/app_theme.dart`: `AppTheme.dark` y `AppTheme.light`, armados solo con lo anterior |
| Componentes | `lib/presentation/widgets/` |

## Reglas

- Leer el color desde el contexto: `context.colors.surface`. No referenciar constantes estáticas `AppTheme.*` en widgets, porque no cambian con el tema.
- `MaterialApp` declara `theme`, `darkTheme` y `themeMode` (Sistema, Claro u Oscuro, elegible en Ajustes). Por defecto, Oscuro.
- Estilos de texto por nombre: `AppText.titleSm`, nunca `TextStyle(fontSize: …)`.
- Espacios con `Space.*` y `Gap`; radios con `Radii.*`.
- Las fuentes se declaran en `pubspec.yaml` bajo `fonts:` (Outfit 500 y 600, IBM Plex Sans 400, 500 y 600, IBM Plex Mono 500) con los archivos en `assets/fonts/`.
- Locale `es_AR`.

## Correspondencia con Material 3

| Token | `ColorScheme` |
|---|---|
| `bg` | `surface` (y `scaffoldBackgroundColor`) |
| `surface` | `surfaceContainer` |
| `surface-raised` | `surfaceContainerHighest` |
| `text` | `onSurface` |
| `text-muted` | `onSurfaceVariant` |
| `accent` / `on-accent` | `primary` / `onPrimary` |
| `accent-soft` | `primaryContainer` (y `secondaryContainer`, `tertiaryContainer`) |
| `border` | `outlineVariant` |
| `border-strong` | `outline` |
| `danger` / `on-danger` | `error` / `onError` |
| `danger-soft` | `errorContainer` |

Los semánticos sin lugar en `ColorScheme` (`success`, `warning`, sus `-soft`, `cat-*`, `paint-*`, `whatsapp`) viven en `AppColors`.

| Estilo | `TextTheme` |
|---|---|
| `display` | `displaySmall` |
| `title-lg` | `headlineSmall` |
| `title-md` | `titleLarge` |
| `title-sm` | `titleMedium` |
| `body-lg` | `bodyLarge` |
| `body` | `bodyMedium` |
| `label` | `labelLarge` |
| `caption` | `bodySmall` |
| `overline` | `labelSmall` |

## Qué prohíbe el lint

Fuera de `lib/core/theme/`: `Color(0x…)`, `Colors.*` salvo `transparent`, `.withValues(alpha:)`, `fontSize:`, `BorderRadius.circular(` con literal y `GestureDetector` con `onTap`.
