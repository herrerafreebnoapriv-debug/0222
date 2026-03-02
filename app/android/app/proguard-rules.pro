# Flutter 与插件保留规则，避免 R8/ProGuard 误删
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 保留 native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}
