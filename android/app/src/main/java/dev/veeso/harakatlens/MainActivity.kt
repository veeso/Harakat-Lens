package dev.veeso.harakatlens

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.veeso.biangbiangui.ui.BiangBiangRoot
import dev.veeso.harakatlens.arabic.arabicConfig

/**
 * Config-only entry point: the BiangBiangUI library renders every screen
 * and owns History, the rate prompt, TTS and the OCR pipeline. The app
 * supplies only [arabicConfig] (Arabic transliterator + Tesseract OCR seam
 * + Quran plugin).
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            BiangBiangRoot(arabicConfig(this))
        }
    }
}
