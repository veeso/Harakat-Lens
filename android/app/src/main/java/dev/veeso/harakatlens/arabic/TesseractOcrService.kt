package dev.veeso.harakatlens.arabic

import android.content.Context
import android.graphics.Bitmap
import android.util.Log
import com.googlecode.tesseract.android.TessBaseAPI
import dev.veeso.biangbiangui.config.OcrRecognizer
import dev.veeso.biangbiangui.protocols.OcrService
import dev.veeso.biangbiangui.protocols.OcrTextBox
import dev.veeso.biangbiangui.services.camera.DefaultOcrService
import java.io.File
import kotlin.math.max
import kotlin.math.roundToInt
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Arabic OCR via Tesseract4Android. ML Kit ships no Arabic script model, so
 * the Arabic example plugs this in through the library's OcrService seam.
 * Non-Arabic recognizers delegate to the built-in ML Kit default.
 *
 * Accuracy on camera frames depends almost entirely on three things, applied
 * here: (1) light preprocessing — software-bitmap copy, upscale, grayscale —
 * leaving binarisation to Leptonica; (2) LSTM-only engine with an explicit
 * DPI so layout analysis behaves; (3) a single cached [TessBaseAPI] reused
 * across frames (model load is expensive; the legacy code reloaded it every
 * call).
 */
class TesseractOcrService(context: Context) : OcrService {
    private val fallback = DefaultOcrService()
    private val appContext = context.applicationContext
    private val dataParent: File = File(appContext.filesDir, "tess")

    @Volatile private var assetCopied = false

    /** Serialises access to the single cached, non-thread-safe API. */
    private val apiLock = Mutex()
    private var api: TessBaseAPI? = null

    private suspend fun ensureTraineddata() {
        if (assetCopied) return
        withContext(Dispatchers.IO) {
            synchronized(this@TesseractOcrService) {
                if (assetCopied) return@synchronized
                dataParent.mkdirs()
                val tessdata = File(dataParent, "tessdata").apply { mkdirs() }
                val target = File(tessdata, "ara.traineddata")
                if (!target.exists()) {
                    val tmp = File(tessdata, "ara.traineddata.tmp")
                    appContext.assets.open("tessdata/ara.traineddata").use { input ->
                        tmp.outputStream().use { input.copyTo(it) }
                    }
                    check(tmp.renameTo(target)) {
                        "Failed to install ara.traineddata"
                    }
                }
                assetCopied = true
            }
        }
    }

    /** Lazily inits the LSTM-only engine once and keeps it warm. */
    private fun obtainApi(): TessBaseAPI {
        api?.let { return it }
        val created = TessBaseAPI()
        val ok = created.init(
            dataParent.absolutePath,
            "ara",
            TessBaseAPI.OEM_LSTM_ONLY,
        )
        Log.i(TAG, "init(ara, LSTM_ONLY) -> $ok, dataParent=$dataParent")
        check(ok) { "Tesseract init failed for 'ara'" }
        // The frame is cropped to a text band before recognition, so treat it
        // as one uniform block instead of running full page-layout analysis
        // (PSM_AUTO over a noisy camera frame mis-segments badly).
        created.pageSegMode = TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK
        // Camera frames carry no DPI metadata; without this Tesseract guesses
        // wrong and layout analysis collapses.
        created.setVariable("user_defined_dpi", "300")
        created.setVariable("preserve_interword_spaces", "1")
        api = created
        return created
    }

    override suspend fun recognize(
        bitmap: Bitmap?,
        recognizer: OcrRecognizer,
    ): List<OcrTextBox> {
        if (recognizer != OcrRecognizer.ARABIC || bitmap == null) {
            return fallback.recognize(bitmap, recognizer)
        }
        ensureTraineddata()
        Log.i(
            TAG,
            "in bitmap ${bitmap.width}x${bitmap.height} cfg=${bitmap.config}",
        )
        val prep = preprocess(bitmap)
        val processed = prep.bitmap
        return withContext(Dispatchers.Default) {
            apiLock.withLock {
                val tess = obtainApi()
                try {
                    tess.setImage(processed)
                    val raw = tess.getUTF8Text() // forces recognition
                    // Boxes come back in processed (cropped + upscaled) space;
                    // the library validates them against the input bitmap size
                    // (OcrRotation.isSane), so map them back to input space.
                    val lines = tess.readTextLines().map { it.mapToInput(prep) }
                    Log.i(
                        TAG,
                        "processed ${processed.width}x${processed.height} " +
                            "off=${prep.offsetX},${prep.offsetY} " +
                            "scale=${prep.scale} psm=${tess.pageSegMode} " +
                            "rawLen=${raw?.length} lines=${lines.size} sample=" +
                            (raw?.take(40)?.replace("\n", "\\n")),
                    )
                    lines
                } catch (t: Throwable) {
                    // The library's analyzer swallows failures, so a thrown
                    // init/recognize error otherwise shows up only as "no
                    // text". Surface it here before rethrowing.
                    Log.e(TAG, "recognize failed", t)
                    throw t
                } finally {
                    tess.clear()
                    if (processed !== bitmap) processed.recycle()
                }
            }
        }
    }

    /** Processed bitmap plus the transform back to input coordinates. */
    private data class Prepared(
        val bitmap: Bitmap,
        val offsetX: Int,
        val offsetY: Int,
        /** Processed pixels per input pixel (input = offset + processed / scale). */
        val scale: Float,
    )

    /**
     * Make the frame safe and friendly for Tesseract without doing its job
     * for it:
     *
     *  - The still-capture path decodes via [android.graphics.ImageDecoder],
     *    which yields a [Bitmap.Config.HARDWARE] bitmap; `getPixels` and the
     *    Tesseract JNI pixel lock both throw on those, so copy to a software
     *    ARGB_8888 bitmap first.
     *  - Crop to a central horizontal band: the user aims the camera at the
     *    text, and the clutter (hands, background) sits top and bottom.
     *    Dropping it removes most of what PSM_SINGLE_BLOCK would otherwise
     *    mis-segment.
     *  - Upscale the band so glyphs have enough strokes for the LSTM.
     *  - Convert to grayscale to drop chroma noise.
     *
     * Binarisation is intentionally NOT done here: Leptonica (inside
     * Tesseract) already binarises with background normalisation, which beats
     * a single global Otsu threshold over a full, unevenly lit camera frame.
     * Never recycles [src]; the library reuses it for the preview overlay.
     */
    private fun preprocess(src: Bitmap): Prepared {
        val software =
            if (src.config == Bitmap.Config.HARDWARE) {
                src.copy(Bitmap.Config.ARGB_8888, false)
            } else {
                src
            }

        val inset = (software.height * ROI_VERTICAL_INSET).toInt()
        val cropY = inset
        val cropH = (software.height - 2 * inset).coerceAtLeast(1)
        val crop =
            Bitmap.createBitmap(software, 0, cropY, software.width, cropH)
        if (software !== src) software.recycle()

        val maxDim = max(crop.width, crop.height)
        val f =
            if (maxDim in 1 until TARGET_LONG_EDGE) {
                TARGET_LONG_EDGE.toFloat() / maxDim
            } else {
                1f
            }
        val scaled =
            if (f != 1f) {
                Bitmap.createScaledBitmap(
                    crop,
                    (crop.width * f).toInt(),
                    (crop.height * f).toInt(),
                    true,
                )
            } else {
                crop
            }

        val w = scaled.width
        val h = scaled.height
        val pixels = IntArray(w * h)
        scaled.getPixels(pixels, 0, w, 0, 0, w, h)
        if (scaled !== crop) crop.recycle()
        scaled.recycle()

        for (i in pixels.indices) {
            val c = pixels[i]
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val b = c and 0xFF
            val y = (r * 299 + g * 587 + b * 114) / 1000
            pixels[i] = (0xFF shl 24) or (y shl 16) or (y shl 8) or y
        }
        val out =
            Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply {
                setPixels(pixels, 0, w, 0, 0, w, h)
            }
        return Prepared(out, offsetX = 0, offsetY = cropY, scale = f)
    }

    /** Maps box geometry from processed (cropped + scaled) space to input. */
    private fun OcrTextBox.mapToInput(p: Prepared): OcrTextBox {
        val s = p.scale
        return OcrTextBox(
            text,
            p.offsetX + (left / s).roundToInt(),
            p.offsetY + (top / s).roundToInt(),
            (width / s).roundToInt(),
            (height / s).roundToInt(),
        )
    }

    /** Walks the result iterator once, one [OcrTextBox] per non-blank line. */
    private fun TessBaseAPI.readTextLines(): List<OcrTextBox> {
        val it = getResultIterator() ?: return emptyList()
        return try {
            it.begin()
            buildList {
                do {
                    val text = it.getUTF8Text(LINE)?.trim()
                    val rect = it.getBoundingRect(LINE)
                    if (!text.isNullOrBlank() && rect != null) {
                        add(
                            OcrTextBox(
                                text,
                                rect.left,
                                rect.top,
                                rect.width(),
                                rect.height(),
                            ),
                        )
                    }
                } while (it.next(LINE))
            }
        } finally {
            it.delete()
        }
    }

    private companion object {
        private const val TAG = "TessOcr"
        private val LINE = TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
        private const val TARGET_LONG_EDGE = 1600

        /** Fraction of frame height trimmed from top and bottom for the ROI. */
        private const val ROI_VERTICAL_INSET = 0.3f
    }
}
