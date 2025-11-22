package com.nexus.app

import android.app.Activity
import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** SecureStoragePlugin */
class SecureStoragePlugin: FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private val KEY_ALIAS = "nexus_master_key"
  private val KEY_ALIAS_BIOMETRIC = "nexus_biometric_key"
  private val ANDROID_KEYSTORE = "AndroidKeyStore"
  private val FILE_NAME = "nexus_identity.enc"
  private val FILE_NAME_BIO = "nexus_identity_bio.enc"
  private val FILE_NAME_META = "nexus_meta.json"

  override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "nexus.secure_storage")
    channel.setMethodCallHandler(this)
    context = binding.applicationContext
  }

  // ActivityAware callbacks to capture the current Activity for BiometricPrompt
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "storeIdentity" -> {
        val blob = call.argument<ByteArray>("blob")
        if (blob == null) { result.error("arg", "missing blob", null); return }
        val ok = storeIdentity(blob)
        result.success(ok)
      }
      "storeIdentityBiometric" -> {
        val blob = call.argument<ByteArray>("blob")
        if (blob == null) { result.error("arg", "missing blob", null); return }
        // Start biometric prompt and on success store encrypted blob
        storeWithBiometric(blob, result)
      }
      "importIdentity" -> {
        val blob = call.argument<ByteArray>("blob")
        if (blob == null) { result.error("arg", "missing blob", null); return }
        val ok = storeIdentity(blob)
        result.success(ok)
      }
      "getIdentityBiometric" -> {
        getIdentityWithBiometric(result)
      }
      "getIdentity" -> {
        try {
          val f = File(context.filesDir, FILE_NAME)
          if (!f.exists()) { result.success(null); return }
          val data = f.readBytes()
          result.success(data)
        } catch (e: Exception) {
          result.error("read_error", e.message, null)
        }
      }
      "storeMetadata" -> {
        val json = call.argument<String>("json")
        if (json == null) { result.error("arg", "missing json", null); return }
        try {
          val f = File(context.filesDir, FILE_NAME_META)
          f.writeText(json)
          result.success(true)
        } catch (e: Exception) {
          result.error("write_error", e.message, null)
        }
      }
      "getMetadata" -> {
        try {
          val f = File(context.filesDir, FILE_NAME_META)
          if (!f.exists()) { result.success(null); return }
          val txt = f.readText()
          result.success(txt)
        } catch (e: Exception) {
          result.error("read_meta_error", e.message, null)
        }
      }
      "wipeDevice" -> {
        val ok = wipeIdentity()
        result.success(ok)
      }
      else -> result.notImplemented()
    }
  }
  private fun storeWithBiometric(blob: ByteArray, result: MethodChannel.Result) {
    // Use a biometric-bound key for encryption. Show BiometricPrompt with a CryptoObject.
    val key = getOrCreateBiometricKey()
    if (key == null) {
      result.error("key_error", "Unable to create biometric key", null)
      return
    }

    val activity = this.activity
    if (activity == null) {
      result.error("no_activity", "Activity not available for biometric prompt", null)
      return
    }

    try {
      val cipher = Cipher.getInstance("AES/GCM/NoPadding")
      cipher.init(Cipher.ENCRYPT_MODE, key)

      val executor = activity.mainExecutor
      val prompt = androidx.biometric.BiometricPrompt(activity, executor,
        object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
          override fun onAuthenticationSucceeded(resultAuth: androidx.biometric.BiometricPrompt.AuthenticationResult) {
            try {
              val authCipher = resultAuth.cryptoObject?.cipher
              val finalCipher = authCipher ?: cipher
              val ct = finalCipher.doFinal(blob)
              val iv = finalCipher.iv
              val out = ByteArray(iv.size + ct.size)
              System.arraycopy(iv, 0, out, 0, iv.size)
              System.arraycopy(ct, 0, out, iv.size, ct.size)
              val f = File(context.filesDir, FILE_NAME_BIO)
              f.writeBytes(out)
              result.success(true)
            } catch (e: Exception) {
              result.error("encrypt_error", e.message, null)
            }
          }

          override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
            result.error("auth_error", errString.toString(), null)
          }
        })

      val info = androidx.biometric.BiometricPrompt.PromptInfo.Builder()
        .setTitle("Authenticate to store identity")
        .setNegativeButtonText("Cancel")
        .build()

      prompt.authenticate(info, androidx.biometric.BiometricPrompt.CryptoObject(cipher))
    } catch (e: Exception) {
      result.error("biometric_error", e.message, null)
    }
  }

  private fun getOrCreateBiometricKey(): SecretKey? {
    try {
      val ks = KeyStore.getInstance(ANDROID_KEYSTORE)
      ks.load(null)
      if (ks.containsAlias(KEY_ALIAS_BIOMETRIC)) {
        val entry = ks.getEntry(KEY_ALIAS_BIOMETRIC, null) as KeyStore.SecretKeyEntry
        return entry.secretKey
      }
      val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
      val builder = KeyGenParameterSpec.Builder(
        KEY_ALIAS_BIOMETRIC,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
      )
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(256)
        .setUserAuthenticationRequired(true)
        .setUserAuthenticationValidityDurationSeconds(-1)
      kg.init(builder.build())
      return kg.generateKey()
    } catch (e: Exception) {
      Log.e("SecureStorage", "biometric key error", e)
      return null
    }
  }

  private fun getIdentityWithBiometric(result: MethodChannel.Result) {
    val key = getOrCreateBiometricKey()
    if (key == null) {
      result.error("key_error", "Unable to load biometric key", null)
      return
    }

    val activity = this.activity
    if (activity == null) {
      result.error("no_activity", "Activity not available for biometric prompt", null)
      return
    }

    try {
      val f = File(context.filesDir, FILE_NAME_BIO)
      if (!f.exists()) { result.error("not_found", "No biometric-stored identity", null); return }
      val data = f.readBytes()
      val iv = data.copyOfRange(0, 12)
      val ct = data.copyOfRange(12, data.size)

      val cipher = Cipher.getInstance("AES/GCM/NoPadding")
      val spec = GCMParameterSpec(128, iv)
      cipher.init(Cipher.DECRYPT_MODE, key, spec)

      val executor = activity.mainExecutor
      val prompt = androidx.biometric.BiometricPrompt(activity, executor,
        object : androidx.biometric.BiometricPrompt.AuthenticationCallback() {
          override fun onAuthenticationSucceeded(resultAuth: androidx.biometric.BiometricPrompt.AuthenticationResult) {
            try {
              val authCipher = resultAuth.cryptoObject?.cipher
              val finalCipher = authCipher ?: cipher
              val pt = finalCipher.doFinal(ct)
              result.success(pt)
            } catch (e: Exception) {
              result.error("decrypt_error", e.message, null)
            }
          }

          override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
            result.error("auth_error", errString.toString(), null)
          }
        })

      val info = androidx.biometric.BiometricPrompt.PromptInfo.Builder()
        .setTitle("Authenticate to access identity")
        .setNegativeButtonText("Cancel")
        .build()

      prompt.authenticate(info, androidx.biometric.BiometricPrompt.CryptoObject(cipher))
    } catch (e: Exception) {
      result.error("biometric_error", e.message, null)
    }
  }

  private fun getOrCreateKey(): SecretKey? {
    try {
      val ks = KeyStore.getInstance(ANDROID_KEYSTORE)
      ks.load(null)
      if (ks.containsAlias(KEY_ALIAS)) {
        val entry = ks.getEntry(KEY_ALIAS, null) as KeyStore.SecretKeyEntry
        return entry.secretKey
      }
      val kg = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
      val spec = KeyGenParameterSpec.Builder(
        KEY_ALIAS,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
      )
        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
        .setKeySize(256)
        .setUserAuthenticationRequired(false)
        .build()
      kg.init(spec)
      return kg.generateKey()
    } catch (e: Exception) {
      Log.e("SecureStorage", "key error", e)
      return null
    }
  }

  private fun storeIdentity(blob: ByteArray): Boolean {
    try {
      val key = getOrCreateKey() ?: return false
      val cipher = Cipher.getInstance("AES/GCM/NoPadding")
      cipher.init(Cipher.ENCRYPT_MODE, key)
      val iv = cipher.iv
      val ct = cipher.doFinal(blob)
      val out = ByteArray(iv.size + ct.size)
      System.arraycopy(iv, 0, out, 0, iv.size)
      System.arraycopy(ct, 0, out, iv.size, ct.size)
      val f = File(context.filesDir, FILE_NAME)
      f.writeBytes(out)
      return true
    } catch (e: Exception) {
      Log.e("SecureStorage", "store error", e)
      return false
    }
  }

  private fun wipeIdentity(): Boolean {
    try {
      // delete stored file
      val f = File(context.filesDir, FILE_NAME)
      if (f.exists()) f.delete()
      // delete key
      val ks = KeyStore.getInstance(ANDROID_KEYSTORE)
      ks.load(null)
      if (ks.containsAlias(KEY_ALIAS)) {
        ks.deleteEntry(KEY_ALIAS)
      }
      return true
    } catch (e: Exception) {
      Log.e("SecureStorage", "wipe error", e)
      return false
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
