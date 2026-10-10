package com.negosmint.negosmint

import android.app.Activity
import android.content.Intent
import android.net.Uri
import org.json.JSONObject
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.negosmint.task/wallet_handoff"
    private val ownershipRequestCode = 7341
    private var pendingOwnershipResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchOwnershipRequest" -> {
                        if (pendingOwnershipResult != null) {
                            result.error("HANDOFF_IN_PROGRESS", "A wallet verification request is already active.", null)
                            return@setMethodCallHandler
                        }
                        val link = call.argument<String>("deepLink")
                        val uri = runCatching { Uri.parse(link ?: "") }.getOrNull()
                        if (uri == null || uri.scheme != "negosmintwallet" || uri.host != "ownership" || link.isNullOrBlank()) {
                            result.error("INVALID_HANDOFF_LINK", "Invalid wallet ownership request.", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        if (intent.resolveActivity(packageManager) == null) {
                            result.error("WALLET_NOT_INSTALLED", "NegosMint Wallet is not installed or cannot handle ownership requests.", null)
                            return@setMethodCallHandler
                        }
                        pendingOwnershipResult = result
                        try {
                            startActivityForResult(intent, ownershipRequestCode)
                        } catch (error: Exception) {
                            pendingOwnershipResult = null
                            result.error("HANDOFF_LAUNCH_FAILED", "Could not open NegosMint Wallet.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android, retained for Flutter activity-result compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ownershipRequestCode) return
        val result = pendingOwnershipResult ?: return
        pendingOwnershipResult = null
        if (resultCode != Activity.RESULT_OK) {
            result.error("HANDOFF_REJECTED", "Wallet ownership verification was cancelled or rejected.", null)
            return
        }
        val payload = data?.getStringExtra("negosmint_wallet_ownership_result")
        if (payload.isNullOrBlank() || payload.length > 8192) {
            result.error("INVALID_HANDOFF_RESULT", "Wallet returned no valid ownership proof.", null)
            return
        }
        try {
            val json = JSONObject(payload)
            val keys = json.keys()
            val map = mutableMapOf<String, Any?>()
            while (keys.hasNext()) {
                val key = keys.next()
                map[key] = json.get(key)
            }
            result.success(map)
        } catch (_: Exception) {
            result.error("INVALID_HANDOFF_RESULT", "Wallet returned malformed ownership proof.", null)
        }
    }
}
