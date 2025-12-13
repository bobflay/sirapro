# SIRA PRO - Carré d'Or Color Usage

## Strict Color Palette

The app now uses **ONLY** colors from the Carré d'Or logo, plus one essential color (green for success).

### 🎨 Logo Colors (Primary Usage)

```dart
AppColors.primary    // #E30613 - Carré d'Or Red
AppColors.secondary  // #FDB813 - Carré d'Or Gold
AppColors.accent     // #1A1A1A - Logo Black
```

### 📊 Color Variations (Logo-based)

**Red Shades:**
- `AppColors.primaryDark` (#B00510) - Darker red
- `AppColors.primaryLight` (#FF3B47) - Lighter red
- `AppColors.primaryVeryLight` (#FFE5E7) - Very light red backgrounds

**Gold Shades:**
- `AppColors.secondaryDark` (#C89B0E) - Darker gold
- `AppColors.secondaryLight` (#FFC940) - Lighter gold
- `AppColors.secondaryVeryLight` (#FFF9E6) - Very light gold backgrounds

### ⚪ Neutral Colors
- `AppColors.white` (#FFFFFF)
- `AppColors.black` (#000000)
- `AppColors.background` (#F8F8F8)
- `AppColors.lightGray` (#E5E5E5)
- `AppColors.gray` (#999999)
- `AppColors.darkGray` (#555555)

### ✅ Additional Color (Only One)
- `AppColors.success` (#2D7A2E) - Dark green for success states ONLY

## Color Mapping by Feature

### Alert System
| Status | Color | Hex |
|--------|-------|-----|
| Urgent | Dark Red | #B00510 |
| High | Brand Red | #E30613 |
| Medium | Gold | #FDB813 |
| Low | Gray | #999999 |
| Pending | Gold | #FDB813 |
| In Progress | Red | #E30613 |
| Resolved | Green | #2D7A2E |

### Alert Types (Icons)
| Type | Color | Usage |
|------|-------|-------|
| Rupture Grave | Red | Primary |
| Litige Problème | Dark Red | Primary Dark |
| Problème Rayon | Gold | Secondary |
| Risque Perte | Red | Primary |
| Demande Spéciale | Dark Gold | Secondary Dark |
| Opportunité | Gold | Secondary |
| Other | Black | Accent |

### Orders
| Status | Color |
|--------|-------|
| Pending | Gold |
| Confirmed | Dark Red |
| Processing | Red |
| Delivered | Green |
| Cancelled | Gray |

### Visit Reports
| Status | Color |
|--------|-------|
| Active | Red |
| Completed | Green |
| Incomplete | Gold |

## UI Components

### AppBar
- Background: Red (#E30613)
- Text: White

### Buttons
- Primary Action: Red background, White text
- Success Action: Green background, White text
- Outlined: Red border and text

### Cards
- Border accents: Red or Gold
- Background: White

### Status Badges
- Background: Status color
- Text: White (or Black for Gold backgrounds)

## Gradients

All gradients use shades of the same logo color:

```dart
// Red gradient (Red to Light Red)
LinearGradient(
  colors: [Color(0xFFE30613), Color(0xFFFF3B47)],
)

// Gold gradient (Gold to Light Gold)
LinearGradient(
  colors: [Color(0xFFFDB813), Color(0xFFFFC940)],
)

// Red to Dark Red
LinearGradient(
  colors: [Color(0xFFE30613), Color(0xFFB00510)],
)
```

## Files Updated

✅ **Color Palette:**
- `lib/utils/app_colors.dart` - Restricted to logo colors only

✅ **Alert Screens:**
- `lib/screens/alertes_page.dart` - All colors updated
- `lib/screens/alert_creation_page.dart` - All colors updated
- `lib/screens/alert_detail_page.dart` - All colors updated

✅ **Theme:**
- `lib/main.dart` - Using AppTheme with logo colors

## Design Rules

### ✅ DO:
- Use `AppColors.primary` (Red) for all primary actions
- Use `AppColors.secondary` (Gold) for highlights and pending states
- Use `AppColors.success` (Green) ONLY for completed/success states
- Use neutral grays for disabled states and backgrounds
- Use gradients of the same color family

### ❌ DON'T:
- Never use blue, purple, orange, teal, or any color outside the palette
- Never use arbitrary colors - always use AppColors constants
- Never use multiple unrelated colors in the same component
- Don't use the logo colors for success states (use green instead)

## Color Count

**Total Colors Used:**
- 3 Logo colors (Red, Gold, Black)
- 6 Logo variations (3 shades of Red, 3 shades of Gold)
- 6 Neutral colors (White, Black, 4 grays)
- 1 Additional color (Green for success)

**Total: 16 colors** (extremely minimal and brand-focused)

## Before & After

### Before ❌
- Used: Purple, Blue, Orange, Teal, Amber, and more random colors
- Total colors: ~20+ arbitrary colors

### After ✅
- Uses: Only Carré d'Or logo colors + green for success
- Total colors: 16 purposeful colors
- 100% brand consistency
