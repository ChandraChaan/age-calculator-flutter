# Flutter's engine references Play Core classes for deferred components,
# which this app does not use.
-dontwarn com.google.android.play.core.**

# Home screen widget, reminders and device-import code is reached from the
# manifest or by name from Dart over method channels.
-keep class com.chandra.agecalculator.** { *; }
