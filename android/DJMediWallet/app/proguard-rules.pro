# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Keep data classes for FHIR models
-keep class com.djmediwallet.models.** { *; }

# Keep credential classes
-keep class com.djmediwallet.models.credential.** { *; }

# Keep GSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }

# Keep security classes
-keep class com.djmediwallet.core.SecurityManager { *; }
-keep class com.djmediwallet.core.WalletManager { *; }
