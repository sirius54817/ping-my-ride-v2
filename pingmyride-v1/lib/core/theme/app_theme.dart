import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Backward compatibility - exposed color constants
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color accentColor = Color(0xFF3B82F6); // Blue accent color
  static const Color secondaryColor = Color(0xFF64748B);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF10B981);

  // Shadcn-inspired color palette - Light theme
  static const _lightBackground = Color(0xFFFFFFFF);
  static const _lightForeground = Color(0xFF020817);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightCardForeground = Color(0xFF020817);
  static const _lightPrimary = Color(0xFF0F172A);
  static const _lightPrimaryForeground = Color(0xFFF8FAFC);
  static const _lightSecondary = Color(0xFFF1F5F9);
  static const _lightSecondaryForeground = Color(0xFF0F172A);
  static const _lightMuted = Color(0xFFF1F5F9);
  static const _lightMutedForeground = Color(0xFF64748B);
  static const _lightAccent = Color(0xFFF1F5F9);
  static const _lightBorder = Color(0xFFE2E8F0);
  static const _lightInput = Color(0xFFE2E8F0);
  static const _lightRing = Color(0xFF020817);

  // Shadcn-inspired color palette - Dark theme
  static const _darkBackground = Color(0xFF020817);
  static const _darkForeground = Color(0xFFF8FAFC);
  static const _darkCard = Color(0xFF020817);
  static const _darkCardForeground = Color(0xFFF8FAFC);
  static const _darkPrimary = Color(0xFFF8FAFC);
  static const _darkPrimaryForeground = Color(0xFF0F172A);
  static const _darkSecondary = Color(0xFF1E293B);
  static const _darkSecondaryForeground = Color(0xFFF8FAFC);
  static const _darkMuted = Color(0xFF1E293B);
  static const _darkMutedForeground = Color(0xFF94A3B8);
  static const _darkAccent = Color(0xFF1E293B);
  static const _darkBorder = Color(0xFF1E293B);
  static const _darkInput = Color(0xFF1E293B);
  static const _darkRing = Color(0xFFD4D4D8);

  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBackground,
      pageTransitionsTheme: _pageTransitionsTheme,
      
      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        onPrimary: _lightPrimaryForeground,
        secondary: _lightSecondary,
        onSecondary: _lightSecondaryForeground,
        surface: _lightCard,
        onSurface: _lightCardForeground,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        outline: _lightBorder,
        surfaceContainerHighest: _lightMuted,
      ),

      // Typography - Inter font family
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _lightForeground,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _lightForeground,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _lightForeground,
          height: 1.3,
          letterSpacing: -0.25,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
          height: 1.5,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: _lightForeground,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: _lightForeground,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: _lightMutedForeground,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightForeground,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: _lightBackground,
        foregroundColor: _lightForeground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
        ),
        iconTheme: const IconThemeData(color: _lightForeground),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Cards - with subtle borders
      cardTheme: CardThemeData(
        color: _lightCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _lightPrimary,
          foregroundColor: _lightPrimaryForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48), // Better touch targets
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          // Hover and pressed states
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return _lightPrimaryForeground.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return _lightPrimaryForeground.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightForeground,
          side: const BorderSide(color: _lightBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return _lightForeground.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return _lightForeground.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightForeground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        
        // Default border
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightInput, width: 1),
        ),
        
        // Enabled border
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightInput, width: 1),
        ),
        
        // Focused border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _lightRing, width: 2),
        ),
        
        // Error border
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        
        // Focused error border
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        
        // Label style
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _lightMutedForeground,
          fontWeight: FontWeight.w400,
        ),
        
        // Floating label style
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _lightForeground,
          fontWeight: FontWeight.w500,
        ),
        
        // Hint style
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _lightMutedForeground,
          fontWeight: FontWeight.w400,
        ),
        
        // Error style
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFFEF4444),
        ),
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightCard,
        indicatorColor: _lightAccent,
        height: 72,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _lightForeground,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _lightMutedForeground,
          );
        }),
        
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              size: 24,
              color: _lightForeground,
            );
          }
          return const IconThemeData(
            size: 24,
            color: _lightMutedForeground,
          );
        }),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _lightForeground,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _lightForeground,
          height: 1.5,
        ),
      ),

      // Divider
      dividerColor: _lightBorder,
      dividerTheme: const DividerThemeData(
        color: _lightBorder,
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: _lightSecondary,
        selectedColor: _lightPrimary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightSecondaryForeground,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightPrimaryForeground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _lightBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _lightPrimaryForeground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lightPrimaryForeground;
          }
          return _lightMutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lightPrimary;
          }
          return _lightMuted;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lightPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_lightPrimaryForeground),
        side: const BorderSide(color: _lightBorder, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lightPrimary;
          }
          return _lightMutedForeground;
        }),
      ),

      // Slider
      sliderTheme: const SliderThemeData(
        activeTrackColor: _lightPrimary,
        inactiveTrackColor: _lightMuted,
        thumbColor: _lightPrimary,
        overlayColor: Color(0x1F0F172A),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _lightPrimary,
        linearTrackColor: _lightMuted,
        circularTrackColor: _lightMuted,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightPrimary,
        foregroundColor: _lightPrimaryForeground,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _lightForeground,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 12,
          color: _lightMutedForeground,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: _lightForeground,
        size: 24,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _lightPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          color: _lightPrimaryForeground,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBackground,
      pageTransitionsTheme: _pageTransitionsTheme,
      
      // Color scheme
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        onPrimary: _darkPrimaryForeground,
        secondary: _darkSecondary,
        onSecondary: _darkSecondaryForeground,
        surface: _darkCard,
        onSurface: _darkCardForeground,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        outline: _darkBorder,
        surfaceContainerHighest: _darkMuted,
      ),

      // Typography - Inter font family
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _darkForeground,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: _darkForeground,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: _darkForeground,
          height: 1.3,
          letterSpacing: -0.25,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.4,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.4,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
          height: 1.5,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: _darkForeground,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: _darkForeground,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: _darkMutedForeground,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkForeground,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: _darkBackground,
        foregroundColor: _darkForeground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
        ),
        iconTheme: const IconThemeData(color: _darkForeground),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Cards - with subtle borders
      cardTheme: CardThemeData(
        color: _darkCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
        margin: const EdgeInsets.all(0),
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkPrimary,
          foregroundColor: _darkPrimaryForeground,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return _darkPrimaryForeground.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return _darkPrimaryForeground.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkForeground,
          side: const BorderSide(color: _darkBorder, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.pressed)) {
                return _darkForeground.withValues(alpha: 0.12);
              }
              if (states.contains(WidgetState.hovered)) {
                return _darkForeground.withValues(alpha: 0.08);
              }
              return null;
            },
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkForeground,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        
        // Default border
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkInput, width: 1),
        ),
        
        // Enabled border
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkInput, width: 1),
        ),
        
        // Focused border
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _darkRing, width: 2),
        ),
        
        // Error border
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        
        // Focused error border
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        
        // Label style
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _darkMutedForeground,
          fontWeight: FontWeight.w400,
        ),
        
        // Floating label style
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _darkForeground,
          fontWeight: FontWeight.w500,
        ),
        
        // Hint style
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _darkMutedForeground,
          fontWeight: FontWeight.w400,
        ),
        
        // Error style
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: const Color(0xFFEF4444),
        ),
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkCard,
        indicatorColor: _darkAccent,
        height: 72,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _darkForeground,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _darkMutedForeground,
          );
        }),
        
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              size: 24,
              color: _darkForeground,
            );
          }
          return const IconThemeData(
            size: 24,
            color: _darkMutedForeground,
          );
        }),
      ),

      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        elevation: 0,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _darkForeground,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _darkForeground,
          height: 1.5,
        ),
      ),

      // Divider
      dividerColor: _darkBorder,
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: _darkSecondary,
        selectedColor: _darkPrimary,
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkSecondaryForeground,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkPrimaryForeground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _darkPrimaryForeground,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkPrimaryForeground;
          }
          return _darkMutedForeground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkPrimary;
          }
          return _darkMuted;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkPrimary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_darkPrimaryForeground),
        side: const BorderSide(color: _darkBorder, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Radio
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkPrimary;
          }
          return _darkMutedForeground;
        }),
      ),

      // Slider
      sliderTheme: const SliderThemeData(
        activeTrackColor: _darkPrimary,
        inactiveTrackColor: _darkMuted,
        thumbColor: _darkPrimary,
        overlayColor: Color(0x1FF8FAFC),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _darkPrimary,
        linearTrackColor: _darkMuted,
        circularTrackColor: _darkMuted,
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkPrimary,
        foregroundColor: _darkPrimaryForeground,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // List tile
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _darkForeground,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 12,
          color: _darkMutedForeground,
        ),
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: _darkForeground,
        size: 24,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _darkPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          color: _darkPrimaryForeground,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}