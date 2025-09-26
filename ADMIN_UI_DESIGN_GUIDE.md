# دليل تصميم واجهة تطبيق الإدارة - الإصدار الشامل
## Admin UI Design Guide - Material Dark Dashboard Pro (Complete Version)

---

## 📖 فهرس المحتويات
1. [نظام الألوان الشامل](#colors)
2. [التايبوغرافي والخطوط](#typography) 
3. [المسافات والتخطيطات](#spacing)
4. [مكونات الواجهة](#components)
5. [الأيقونات والصور](#icons)
6. [الحركات والتأثيرات](#animations)
7. [حالات التطبيق](#states)
8. [الاستجابة والتكيف](#responsive)
9. [إمكانية الوصول](#accessibility)
10. [أفضل الممارسات](#best-practices)

---

## 🎨 نظام الألوان الشامل (Complete Color System) {#colors}

### الألوان الأساسية (Primary Palette)
```dart
// الألوان الرئيسية
const Color primaryDark = Color(0xFF1E1E2E);      // الخلفية الرئيسية
const Color surfaceDark = Color(0xFF2D2D44);      // خلفية المكونات
const Color cardDark = Color(0xFF363654);         // خلفية الكروت المرفوعة
const Color accentPurple = Color(0xFF6C63FF);     // البنفسجي الأساسي
const Color accentPurpleLight = Color(0xFF8A84FF); // بنفسجي فاتح
const Color accentPurpleDark = Color(0xFF5048E5);  // بنفسجي داكن
```

### ألوان الحالة (Status Colors)
```dart
// ألوان الحالات المختلفة
const Color successGreen = Color(0xFF4CAF50);     // الأخضر للنجاح
const Color successLight = Color(0xFF66BB6A);     // أخضر فاتح
const Color successDark = Color(0xFF388E3C);      // أخضر داكن

const Color errorRed = Color(0xFFE53E3E);         // الأحمر للخطأ
const Color errorLight = Color(0xFFEF5350);       // أحمر فاتح
const Color errorDark = Color(0xFFD32F2F);        // أحمر داكن

const Color warningOrange = Color(0xFFFF9800);    // البرتقالي للتحذير
const Color warningLight = Color(0xFFFFB74D);     // برتقالي فاتح
const Color warningDark = Color(0xFFF57C00);      // برتقالي داكن

const Color infoBlue = Color(0xFF2196F3);         // الأزرق للمعلومات
const Color infoLight = Color(0xFF42A5F5);        // أزرق فاتح
const Color infoDark = Color(0xFF1976D2);         // أزرق داكن
```

### ألوان النصوص (Text Colors Hierarchy)
```dart
const Color textPrimary = Color(0xFFFFFFFF);      // النص الأساسي
const Color textSecondary = Color(0xFFB3B3B3);    // النص الثانوي (70% opacity)
const Color textTertiary = Color(0xFF8A8A8A);     // النص المساعد (54% opacity)
const Color textDisabled = Color(0xFF666666);     // النص المعطل (38% opacity)
const Color textPlaceholder = Color(0xFF5A5A5A);  // نص التلميح
```

### ألوان الحدود والفواصل (Border & Divider Colors)
```dart
const Color borderLight = Color(0xFF404040);      // حدود فاتحة
const Color borderMedium = Color(0xFF555555);     // حدود متوسطة
const Color borderStrong = Color(0xFF6C63FF);     // حدود قوية (ملونة)
const Color divider = Color(0xFF333333);          // خطوط الفاصل
```

### ألوان الخلفيات التفاعلية (Interactive Backgrounds)
```dart
const Color hoverBackground = Color(0xFF3D3D5C);  // خلفية عند التمرير
const Color pressedBackground = Color(0xFF4A4A6B); // خلفية عند الضغط
const Color focusedBackground = Color(0xFF5757A1); // خلفية عند التركيز
const Color selectedBackground = Color(0xFF6C63FF).withOpacity(0.2); // الخلفية المحددة
```

---

## ✍️ التايبوغرافي والخطوط الشامل (Complete Typography) {#typography}

### هيكل الخطوط (Font Hierarchy)
```dart
class AppTextStyles {
  // العناوين الرئيسية
  static const TextStyle headline1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );
  
  static const TextStyle headline2 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.25,
    height: 1.3,
  );
  
  static const TextStyle headline3 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );
  
  static const TextStyle headline4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.25,
    height: 1.4,
  );
  
  // النصوص الأساسية
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    letterSpacing: 0.15,
    height: 1.5,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    letterSpacing: 0.25,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textTertiary,
    letterSpacing: 0.4,
    height: 1.4,
  );
  
  // نصوص الأزرار والتسميات
  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 1.25,
    height: 1.2,
  );
  
  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 1.25,
    height: 1.2,
  );
  
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 1.5,
    height: 1.2,
  );
  
  // نصوص التسميات والحقول
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );
  
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.5,
    height: 1.3,
  );
  
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textTertiary,
    letterSpacing: 0.5,
    height: 1.3,
  );
}
```

---

## 📏 نظام المسافات والتخطيطات الشامل (Complete Spacing & Layout) {#spacing}

### وحدات المسافات (Spacing Units)
```dart
class AppSpacing {
  // وحدات المسافات الأساسية (بالبكسل)
  static const double xs = 4;      // صغير جداً
  static const double sm = 8;      // صغير
  static const double md = 16;     // متوسط (القياسي)
  static const double lg = 24;     // كبير
  static const double xl = 32;     // كبير جداً
  static const double xxl = 48;    // ضخم
  static const double xxxl = 64;   // ضخم جداً
  
  // مسافات مخصصة للاستخدامات المحددة
  static const double cardPadding = 20;
  static const double screenPadding = 20;
  static const double sectionSpacing = 32;
  static const double itemSpacing = 12;
  static const double iconSpacing = 8;
}

// أمثلة الاستخدام
EdgeInsets.all(AppSpacing.md)                    // 16 من كل الجهات
EdgeInsets.symmetric(
  horizontal: AppSpacing.lg, 
  vertical: AppSpacing.md
)                                                // 24 أفقي، 16 عمودي
EdgeInsets.only(
  top: AppSpacing.xl,
  bottom: AppSpacing.lg,
  left: AppSpacing.md,
  right: AppSpacing.md
)                                               // مسافات مختلفة
```

### نظام الشبكة (Grid System)
```dart
class AppGrid {
  // عدد الأعمدة حسب حجم الشاشة
  static int getColumnCount(double screenWidth) {
    if (screenWidth > 1200) return 4;      // شاشات كبيرة
    if (screenWidth > 800) return 3;       // شاشات متوسطة
    if (screenWidth > 600) return 2;       // شاشات صغيرة
    return 1;                              // هواتف
  }
  
  // المسافات بين عناصر الشبكة
  static const double gridSpacing = 16;
  static const double gridRunSpacing = 16;
  
  // نسب العرض إلى الارتفاع
  static const double cardAspectRatio = 0.75;    // للكروت العادية
  static const double wideCardAspectRatio = 1.5; // للكروت العريضة
  static const double squareAspectRatio = 1.0;   // للكروت المربعة
}
```

### نقاط الكسر (Breakpoints)
```dart
class AppBreakpoints {
  static const double mobile = 600;      // الهواتف
  static const double tablet = 900;      // الأجهزة اللوحية
  static const double desktop = 1200;    // أجهزة المكتب
  static const double largeDesktop = 1800; // شاشات كبيرة
  
  // دالة للتحقق من نوع الجهاز
  static String getDeviceType(double width) {
    if (width >= largeDesktop) return 'largeDesktop';
    if (width >= desktop) return 'desktop';
    if (width >= tablet) return 'tablet';
    return 'mobile';
  }
}
```

---

## 🧩 مكونات الواجهة الشاملة (Complete UI Components) {#components}

### 1. الكروت المتقدمة (Advanced Cards)
```dart
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  
  const AppCard({
    Key? key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.border,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? surfaceDark,
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      elevation: elevation ?? 4,
      shadowColor: Colors.black.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: Container(
          padding: padding ?? EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            border: border,
            gradient: backgroundColor == null ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                surfaceDark,
                surfaceDark.withOpacity(0.8),
              ],
            ) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### 2. نظام الأزرار المتكامل (Complete Button System)
```dart
enum AppButtonType { primary, secondary, danger, success, warning, info, outline, ghost }
enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool disabled;
  final double? width;
  
  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.loading = false,
    this.disabled = false,
    this.width,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final colors = _getButtonColors(type);
    final sizes = _getButtonSizes(size);
    
    return SizedBox(
      width: width,
      height: sizes['height'],
      child: ElevatedButton(
        onPressed: (disabled || loading) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors['background'],
          foregroundColor: colors['foreground'],
          elevation: type == AppButtonType.ghost ? 0 : 3,
          shadowColor: colors['background']?.withOpacity(0.3),
          padding: EdgeInsets.symmetric(
            horizontal: sizes['horizontalPadding'],
            vertical: sizes['verticalPadding'],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizes['borderRadius']),
            side: type == AppButtonType.outline 
              ? BorderSide(color: colors['background']!, width: 2)
              : BorderSide.none,
          ),
        ),
        child: loading 
          ? SizedBox(
              width: sizes['iconSize'],
              height: sizes['iconSize'],
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors['foreground'],
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: sizes['iconSize']),
                  SizedBox(width: AppSpacing.sm),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: sizes['fontSize'],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
      ),
    );
  }
  
  Map<String, dynamic> _getButtonColors(AppButtonType type) {
    switch (type) {
      case AppButtonType.primary:
        return {'background': accentPurple, 'foreground': Colors.white};
      case AppButtonType.secondary:
        return {'background': surfaceDark, 'foreground': textPrimary};
      case AppButtonType.danger:
        return {'background': errorRed, 'foreground': Colors.white};
      case AppButtonType.success:
        return {'background': successGreen, 'foreground': Colors.white};
      case AppButtonType.warning:
        return {'background': warningOrange, 'foreground': Colors.white};
      case AppButtonType.info:
        return {'background': infoBlue, 'foreground': Colors.white};
      case AppButtonType.outline:
        return {'background': accentPurple, 'foreground': accentPurple};
      case AppButtonType.ghost:
        return {'background': Colors.transparent, 'foreground': textPrimary};
    }
  }
  
  Map<String, double> _getButtonSizes(AppButtonSize size) {
    switch (size) {
      case AppButtonSize.small:
        return {
          'height': 32,
          'horizontalPadding': 12,
          'verticalPadding': 6,
          'fontSize': 12,
          'iconSize': 16,
          'borderRadius': 16,
        };
      case AppButtonSize.medium:
        return {
          'height': 40,
          'horizontalPadding': 16,
          'verticalPadding': 8,
          'fontSize': 14,
          'iconSize': 18,
          'borderRadius': 20,
        };
      case AppButtonSize.large:
        return {
          'height': 48,
          'horizontalPadding': 24,
          'verticalPadding': 12,
          'fontSize': 16,
          'iconSize': 20,
          'borderRadius': 24,
        };
    }
  }
}
```

### 3. حقول الإدخال المتقدمة (Advanced Input Fields)
```dart
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool obscureText;
  final bool enabled;
  final bool required;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? maxLength;
  final FocusNode? focusNode;
  
  const AppTextField({
    Key? key,
    this.label,
    this.hint,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.controller,
    this.onChanged,
    this.onTap,
    this.obscureText = false,
    this.enabled = true,
    this.required = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
  }) : super(key: key);
  
  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _isFocused = false;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          RichText(
            text: TextSpan(
              text: widget.label,
              style: AppTextStyles.labelMedium,
              children: [
                if (widget.required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: errorRed),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.sm),
        ],
        
        Focus(
          onFocusChange: (focused) {
            setState(() {
              _isFocused = focused;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.enabled ? surfaceDark : surfaceDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.errorText != null 
                  ? errorRed
                  : _isFocused 
                    ? accentPurple 
                    : borderLight,
                width: _isFocused ? 2 : 1,
              ),
              boxShadow: _isFocused ? [
                BoxShadow(
                  color: accentPurple.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ] : null,
            ),
            child: TextField(
              controller: widget.controller,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
              obscureText: widget.obscureText,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              focusNode: widget.focusNode,
              style: AppTextStyles.bodyMedium.copyWith(color: textPrimary),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: textPlaceholder),
                prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, color: accentPurple, size: 20)
                  : null,
                suffixIcon: widget.suffixIcon != null
                  ? IconButton(
                      onPressed: widget.onSuffixIconTap,
                      icon: Icon(widget.suffixIcon, color: textSecondary, size: 20),
                    )
                  : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                counterText: '',
              ),
            ),
          ),
        ),
        
        if (widget.errorText != null) ...[
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.error_outline, color: errorRed, size: 16),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  widget.errorText!,
                  style: AppTextStyles.labelSmall.copyWith(color: errorRed),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
```