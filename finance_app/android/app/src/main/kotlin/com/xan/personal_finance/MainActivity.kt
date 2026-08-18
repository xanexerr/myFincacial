package com.xan.personal_finance

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.charset.StandardCharsets
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.xan.personal_finance/files"
    private val exportRequest = 1001
    private val importRequest = 1002
    private val imageRequest = 1003
    private var pendingResult: MethodChannel.Result? = null
    private var pendingMethod: String? = null
    private var pendingContent: String = ""
    private var pendingAttachments: List<Map<*, *>> = emptyList()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportBackup" -> startExport(call, result)
                "importBackup" -> startImport(result)
                "pickImage" -> startPickImage(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun startExport(call: MethodCall, result: MethodChannel.Result) {
        pendingResult = result
        pendingMethod = "export"
        pendingContent = call.argument<String>("content") ?: "{}"
        pendingAttachments = call.argument<List<*>>("attachments")?.mapNotNull { it as? Map<*, *> } ?: emptyList()
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, "xan_finance_backup.xanbackup")
        }
        startActivityForResult(intent, exportRequest)
    }

    private fun startImport(result: MethodChannel.Result) {
        pendingResult = result
        pendingMethod = "import"
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "application/octet-stream"
        }
        startActivityForResult(intent, importRequest)
    }

    private fun startPickImage(result: MethodChannel.Result) {
        pendingResult = result
        pendingMethod = "image"
        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        startActivityForResult(intent, imageRequest)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pendingResult ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            clearPending()
            return
        }
        try {
            when (requestCode) {
                exportRequest -> writeBackup(uri, result)
                importRequest -> readBackup(uri, result)
                imageRequest -> copyAndCompressImage(uri, result)
            }
        } catch (error: Exception) {
            result.error("FILE_ERROR", error.message, null)
            clearPending()
        }
    }

    private fun writeBackup(uri: Uri, result: MethodChannel.Result) {
        contentResolver.openOutputStream(uri)?.use { output ->
            ZipOutputStream(output).use { zip ->
                zip.putNextEntry(ZipEntry("finance_data.json"))
                zip.write(pendingContent.toByteArray(StandardCharsets.UTF_8))
                zip.closeEntry()
                for (attachment in pendingAttachments) {
                    val path = attachment["path"] as? String ?: continue
                    val fileName = attachment["fileName"] as? String ?: continue
                    val file = File(path)
                    if (!file.exists()) continue
                    zip.putNextEntry(ZipEntry("receipts/$fileName"))
                    file.inputStream().use { it.copyTo(zip) }
                    zip.closeEntry()
                }
            }
        }
        result.success(true)
        clearPending()
    }

    private fun readBackup(uri: Uri, result: MethodChannel.Result) {
        val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: error("อ่านไฟล์ไม่ได้")
        val content = if (bytes.size >= 2 && bytes[0].toInt() == 0x50 && bytes[1].toInt() == 0x4b) {
            extractBackup(bytes)
        } else {
            String(bytes, StandardCharsets.UTF_8)
        }
        result.success(content)
        clearPending()
    }

    private fun extractBackup(bytes: ByteArray): String {
        val receipts = File(filesDir, "app_flutter/receipts")
        receipts.mkdirs()
        var json = "{}"
        ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                if (!entry.isDirectory && entry.name == "finance_data.json") {
                    json = String(zip.readBytes(), StandardCharsets.UTF_8)
                } else if (!entry.isDirectory && entry.name.startsWith("receipts/")) {
                    val name = File(entry.name).name
                    FileOutputStream(File(receipts, name)).use { zip.copyTo(it) }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        return json
    }

    private fun copyAndCompressImage(uri: Uri, result: MethodChannel.Result) {
        val receipts = File(filesDir, "app_flutter/receipts")
        receipts.mkdirs()
        val fileName = "receipt_${System.currentTimeMillis()}.jpg"
        val destination = File(receipts, fileName)
        val bitmap = contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
        if (bitmap != null) {
            val maxSize = 1600
            val scale = minOf(1f, maxSize.toFloat() / maxOf(bitmap.width, bitmap.height).toFloat())
            val scaled = if (scale < 1f) Bitmap.createScaledBitmap(bitmap, (bitmap.width * scale).toInt(), (bitmap.height * scale).toInt(), true) else bitmap
            FileOutputStream(destination).use { scaled.compress(Bitmap.CompressFormat.JPEG, 70, it) }
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
        } else {
            contentResolver.openInputStream(uri)?.use { input -> FileOutputStream(destination).use { input.copyTo(it) } }
        }
        result.success(fileName)
        clearPending()
    }

    private fun clearPending() {
        pendingResult = null
        pendingMethod = null
        pendingContent = ""
        pendingAttachments = emptyList()
    }
}
