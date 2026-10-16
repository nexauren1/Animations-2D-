package com.nexauren.animpro

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val exportChannel = "animpro/native_video_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val sourcePath = call.argument<String>("sourcePath").orEmpty()
                    val requestedName = call.argument<String>("fileName").orEmpty()
                    val mimeType = call.argument<String>("mimeType").orEmpty()
                    if (sourcePath.isBlank() || requestedName.isBlank() || mimeType.isBlank()) {
                        result.error("INVALID_ARGUMENT", "Faltam os dados do ficheiro para guardar.", null)
                        return@setMethodCallHandler
                    }
                    Thread {
                        try {
                            val location = saveExportToDownloads(sourcePath, requestedName, mimeType)
                            Handler(Looper.getMainLooper()).post { result.success(location) }
                        } catch (error: Throwable) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("SAVE_EXPORT_FAILED", error.message ?: "Não foi possível guardar em Downloads.", null)
                            }
                        }
                    }.start()
                    return@setMethodCallHandler
                }

                if (call.method != "exportMp4") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val paths = call.argument<List<String>>("framePaths").orEmpty()
                val outputPath = call.argument<String>("outputPath").orEmpty()
                val fps = (call.argument<Int>("fps") ?: 12).coerceIn(1, 60)
                if (paths.isEmpty() || outputPath.isBlank()) {
                    result.error("INVALID_ARGUMENT", "Faltam frames ou o caminho de saída.", null)
                    return@setMethodCallHandler
                }

                Thread {
                    try {
                        NativeMp4Encoder.encode(paths, outputPath, fps)
                        Handler(Looper.getMainLooper()).post { result.success(outputPath) }
                    } catch (error: Throwable) {
                        Handler(Looper.getMainLooper()).post {
                            result.error(
                                "MP4_EXPORT_FAILED",
                                error.message ?: "O codificador H.264 do dispositivo não conseguiu criar o vídeo.",
                                null
                            )
                        }
                    }
                }.start()
            }
    }

    private fun saveExportToDownloads(sourcePath: String, requestedName: String, mimeType: String): String {
        val source = File(sourcePath)
        require(source.isFile && source.length() > 0L) { "O ficheiro exportado não existe ou está vazio." }
        val fileName = requestedName.substringAfterLast('/').substringAfterLast('\\')
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(120)
        require(fileName.isNotBlank()) { "Nome de ficheiro inválido." }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/AnimPro")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("O Android não criou o ficheiro em Downloads.")
            try {
                val output = contentResolver.openOutputStream(uri)
                    ?: throw IllegalStateException("O Android não abriu o ficheiro de destino.")
                output.use { stream -> source.inputStream().use { input -> input.copyTo(stream) } }
                contentResolver.update(
                    uri,
                    ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
                    null,
                    null,
                )
                return uri.toString()
            } catch (error: Throwable) {
                contentResolver.delete(uri, null, null)
                throw error
            }
        }

        // Android 7–9: save to the app-specific Downloads folder without asking
        // for broad storage permission. Android 10+ uses the public Downloads/AnimPro.
        val directory = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
            ?: throw IllegalStateException("O armazenamento externo não está disponível.")
        val targetDirectory = File(directory, "AnimPro")
        if (!targetDirectory.exists() && !targetDirectory.mkdirs()) {
            throw IllegalStateException("Não foi possível criar a pasta de exportações.")
        }
        val target = File(targetDirectory, fileName)
        source.copyTo(target, overwrite = true)
        return target.absolutePath
    }
}

private object NativeMp4Encoder {
    private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val COLOR_FLEXIBLE = MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
    private const val COLOR_PLANAR = MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Planar
    private const val COLOR_SEMIPLANAR = MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar

    fun encode(framePaths: List<String>, outputPath: String, fps: Int) {
        require(framePaths.isNotEmpty()) { "O projeto não tem frames para exportar." }
        val firstFile = File(framePaths.first())
        require(firstFile.isFile) { "O primeiro frame não existe." }
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(firstFile.absolutePath, bounds)
        val width = bounds.outWidth and -2
        val height = bounds.outHeight and -2
        require(width >= 2 && height >= 2) { "Dimensões de vídeo inválidas." }

        val codecInfo = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.firstOrNull { info ->
            info.isEncoder &&
                info.supportedTypes.any { it.equals(MIME, ignoreCase = true) } &&
                runCatching {
                    val caps = info.getCapabilitiesForType(MIME)
                    caps.colorFormats.any {
                        it == COLOR_FLEXIBLE || it == COLOR_PLANAR || it == COLOR_SEMIPLANAR
                    } && caps.videoCapabilities.areSizeAndRateSupported(width, height, fps.toDouble())
                }.getOrDefault(false)
        } ?: throw IllegalStateException("Este dispositivo não disponibiliza um codificador H.264 compatível.")

        val capabilities = codecInfo.getCapabilitiesForType(MIME)
        // Flexible YUV is the most interoperable input format on modern Android codecs.
        // Some devices expose only this format; the previous implementation rejected them.
        val colorFormat = when {
            capabilities.colorFormats.contains(COLOR_FLEXIBLE) -> COLOR_FLEXIBLE
            capabilities.colorFormats.contains(COLOR_SEMIPLANAR) -> COLOR_SEMIPLANAR
            capabilities.colorFormats.contains(COLOR_PLANAR) -> COLOR_PLANAR
            else -> throw IllegalStateException("Formato de cor H.264 não suportado.")
        }

        val format = MediaFormat.createVideoFormat(MIME, width, height).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, colorFormat)
            setInteger(MediaFormat.KEY_BIT_RATE, (width.toLong() * height * fps * 0.08).toInt().coerceIn(500_000, 8_000_000))
            setInteger(MediaFormat.KEY_FRAME_RATE, fps)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
        }

        val codec = MediaCodec.createByCodecName(codecInfo.name)
        val target = File(outputPath)
        target.parentFile?.mkdirs()
        if (target.exists()) target.delete()
        val muxer = MediaMuxer(target.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var muxerStarted = false
        var trackIndex = -1
        var codecStarted = false

        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            codecStarted = true
            val info = MediaCodec.BufferInfo()
            var frameIndex = 0
            var eosQueued = false
            var outputDone = false
            var idleLoops = 0

            while (!outputDone) {
                if (idleLoops > 3000) {
                    throw IllegalStateException("O codificador demorou demasiado tempo. Tenta 540p ou menos frames.")
                }
                if (frameIndex < framePaths.size) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val bitmapOriginal = BitmapFactory.decodeFile(framePaths[frameIndex])
                            ?: throw IllegalStateException("Não foi possível abrir o frame ${frameIndex + 1}.")
                        val bitmap = if (bitmapOriginal.width != width || bitmapOriginal.height != height) {
                            Bitmap.createScaledBitmap(bitmapOriginal, width, height, true).also {
                                if (it !== bitmapOriginal) bitmapOriginal.recycle()
                            }
                        } else bitmapOriginal
                        try {
                            if (colorFormat == COLOR_FLEXIBLE) {
                                val inputImage = codec.getInputImage(inputIndex)
                                    ?: throw IllegalStateException("Imagem de entrada H.264 indisponível.")
                                try {
                                    bitmapToInputImage(bitmap, inputImage)
                                } finally {
                                    inputImage.close()
                                }
                                codec.queueInputBuffer(
                                    inputIndex, 0, inputImageWidthBytes(width, height),
                                    frameIndex * 1_000_000L / fps, 0
                                )
                            } else {
                                val yuv = bitmapToYuv420(bitmap, colorFormat)
                                val input = codec.getInputBuffer(inputIndex)
                                    ?: throw IllegalStateException("Buffer de entrada H.264 indisponível.")
                                input.clear()
                                require(yuv.size <= input.remaining()) { "Frame maior que o buffer H.264." }
                                input.put(yuv)
                                codec.queueInputBuffer(
                                    inputIndex, 0, yuv.size,
                                    frameIndex * 1_000_000L / fps, 0
                                )
                            }
                        } finally {
                            bitmap.recycle()
                        }
                        frameIndex++
                        idleLoops = 0
                    }
                } else if (!eosQueued) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        codec.queueInputBuffer(
                            inputIndex, 0, 0,
                            framePaths.size * 1_000_000L / fps,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        eosQueued = true
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(info, 10_000)
                when {
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (muxerStarted) throw IllegalStateException("Formato H.264 mudou durante a exportação.")
                        trackIndex = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxerStarted = true
                    }
                    outputIndex >= 0 -> {
                        val output = codec.getOutputBuffer(outputIndex)
                        if (output != null && info.size > 0 && muxerStarted &&
                            (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0) {
                            idleLoops = 0
                            output.position(info.offset)
                            output.limit(info.offset + info.size)
                            muxer.writeSampleData(trackIndex, output, info)
                        }
                        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                    }
                    else -> idleLoops++
                }
            }

            if (!muxerStarted) throw IllegalStateException("O encoder não produziu uma faixa de vídeo.")
        } finally {
            if (codecStarted) runCatching { codec.stop() }
            runCatching { codec.release() }
            if (muxerStarted) runCatching { muxer.stop() }
            runCatching { muxer.release() }
        }

        require(target.isFile && target.length() > 0L) { "O ficheiro MP4 ficou vazio." }
    }

    private fun inputImageWidthBytes(width: Int, height: Int): Int = width * height * 3 / 2

    private fun bitmapToInputImage(bitmap: Bitmap, image: android.media.Image) {
        val width = bitmap.width
        val height = bitmap.height
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val planes = image.planes
        require(planes.size >= 3) { "O codificador não disponibilizou planos YUV420." }
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]
        val yBuffer = yPlane.buffer
        val uBuffer = uPlane.buffer
        val vBuffer = vPlane.buffer

        for (row in 0 until height) {
            for (column in 0 until width) {
                val pixel = pixels[row * width + column]
                val r = (pixel shr 16) and 0xff
                val g = (pixel shr 8) and 0xff
                val b = pixel and 0xff
                val y = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).coerceIn(0, 255)
                yBuffer.put(row * yPlane.rowStride + column * yPlane.pixelStride, y.toByte())

                if (row % 2 == 0 && column % 2 == 0) {
                    val u = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).coerceIn(0, 255)
                    val v = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).coerceIn(0, 255)
                    val chromaRow = row / 2
                    val chromaColumn = column / 2
                    uBuffer.put(chromaRow * uPlane.rowStride + chromaColumn * uPlane.pixelStride, u.toByte())
                    vBuffer.put(chromaRow * vPlane.rowStride + chromaColumn * vPlane.pixelStride, v.toByte())
                }
            }
        }
    }

    private fun bitmapToYuv420(bitmap: Bitmap, colorFormat: Int): ByteArray {
        val width = bitmap.width
        val height = bitmap.height
        val frameSize = width * height
        val pixels = IntArray(frameSize)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val output = ByteArray(frameSize * 3 / 2)
        var yIndex = 0
        var chromaIndex = 0
        val uStart = frameSize
        val vStart = frameSize + frameSize / 4

        for (row in 0 until height) {
            for (column in 0 until width) {
                val pixel = pixels[row * width + column]
                val r = (pixel shr 16) and 0xff
                val g = (pixel shr 8) and 0xff
                val b = pixel and 0xff
                val y = (((66 * r + 129 * g + 25 * b + 128) shr 8) + 16).coerceIn(0, 255)
                output[yIndex++] = y.toByte()

                if (row % 2 == 0 && column % 2 == 0) {
                    val u = (((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128).coerceIn(0, 255)
                    val v = (((112 * r - 94 * g - 18 * b + 128) shr 8) + 128).coerceIn(0, 255)
                    if (colorFormat == COLOR_SEMIPLANAR) {
                        val index = uStart + chromaIndex * 2
                        output[index] = u.toByte()
                        output[index + 1] = v.toByte()
                    } else {
                        output[uStart + chromaIndex] = u.toByte()
                        output[vStart + chromaIndex] = v.toByte()
                    }
                    chromaIndex++
                }
            }
        }
        return output
    }
}
