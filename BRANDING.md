# SIRA PRO - Carré d'Or Branding Guide

## Logo Usage

The Carré d'Or logo is located at `images/logo.png`.

### Display Logo in UI

```dart
// Display logo as an image
Image.asset(
  'images/logo.png',
  width: 200,
  height: 80,
  fit: BoxFit.contain,
)
```

### Example: Login Screen Logo

```dart
Padding(
  padding: const EdgeInsets.all(32.0),
  child: Image.asset(
    'images/logo.png',
    height: 100,
  ),
)
```

## Color Palette

The brand color palette is defined in `lib/utils/app_colors.dart` and extracted from the Carré d'Or logo.

### Primary Brand Colors

```dart
import 'package:sirapro/utils/app_colors.dart';

// Primary Red - Main brand color
AppColors.primary        // #E30613 (Carré d'Or Red)

// Secondary Gold - Accent color
AppColors.secondary      // #FDB813 (Carré d'Or Gold)

// Accent Black
AppColors.accent         // #1A1A1A (Logo text color)
```

### Color Variations

```dart
// Red variations
AppColors.primaryLight       // #FF4757
AppColors.primaryDark        // #B00510
AppColors.primaryVeryLight   // #FFE5E7

// Gold variations
AppColors.secondaryLight     // #FFD54F
AppColors.secondaryDark      // #C89B0E
AppColors.secondaryVeryLight // #FFF9E6
```

### Status Colors

```dart
AppColors.success  // #4CAF50 (Green)
AppColors.warning  // #FF9800 (Orange)
AppColors.error    // #E30613 (Brand Red)
AppColors.info     // #2196F3 (Blue)
```

### Alert Priority Colors

```dart
AppColors.urgent   // #B71C1C (Deep Red)
AppColors.high     // #E30613 (Brand Red)
AppColors.medium   // #FF9800 (Orange)
AppColors.low      // #9E9E9E (Gray)
```

## Theme Usage

The app uses a pre-configured theme based on Carré d'Or branding.

### Apply Theme (Already configured in main.dart)

```dart
MaterialApp(
  title: 'SIRA PRO - Carré d\'Or',
  theme: AppTheme.lightTheme,
  home: MyHomePage(),
)
```

### Custom Buttons

```dart
// Primary button (automatically styled with brand colors)
ElevatedButton(
  onPressed: () {},
  child: Text('Action'),
)

// Custom colored button
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.secondary,
    foregroundColor: AppColors.black,
  ),
  child: Text('Gold Button'),
)
```

### Gradients

```dart
// Primary gradient (Red to Dark Red)
Container(
  decoration: BoxDecoration(
    gradient: AppColors.primaryGradient,
  ),
)

// Secondary gradient (Gold variations)
Container(
  decoration: BoxDecoration(
    gradient: AppColors.secondaryGradient,
  ),
)

// Brand gradient (Red to Gold)
Container(
  decoration: BoxDecoration(
    gradient: AppColors.brandGradient,
  ),
)
```

### Helper Methods

```dart
// Get color based on alert priority
Color priorityColor = AppColors.getAlertPriorityColor('urgent');

// Get color based on order status
Color statusColor = AppColors.getOrderStatusColor('delivered');
```

## Design Guidelines

### Do's ✅
- Use `AppColors.primary` (Red) for primary actions and branding
- Use `AppColors.secondary` (Gold) for highlights and secondary actions
- Use neutral grays for backgrounds and disabled states
- Maintain consistent corner radius (8-12px for cards, buttons)
- Use the logo on white backgrounds for best visibility

### Don'ts ❌
- Don't use arbitrary colors - always use AppColors constants
- Don't modify the logo colors or proportions
- Don't use low contrast color combinations
- Don't use the primary red for success states (use AppColors.success green instead)

## Color Reference Chart

| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Primary Red | #E30613 | Primary actions, branding, errors |
| Secondary Gold | #FDB813 | Highlights, secondary actions |
| Accent Black | #1A1A1A | Text, icons |
| Success Green | #4CAF50 | Success states, confirmations |
| Warning Orange | #FF9800 | Warnings, medium priority |
| Info Blue | #2196F3 | Informational messages |

## Example Implementations

### AppBar with Brand Colors

```dart
AppBar(
  title: Text('SIRA PRO'),
  backgroundColor: AppColors.primary,
  foregroundColor: AppColors.white,
)
```

### Card with Brand Accent

```dart
Card(
  child: Container(
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(
          color: AppColors.secondary,
          width: 4,
        ),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('Content'),
    ),
  ),
)
```

### Status Badge

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: AppColors.primary,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    'URGENT',
    style: TextStyle(
      color: AppColors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
)
```
