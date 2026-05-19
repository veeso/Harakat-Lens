package dev.veeso.harakatlens

import android.content.Context
import dev.veeso.harakatlens.arabic.ArabicTransliterator
import dev.veeso.harakatlens.arabic.Vocalizer
import dev.veeso.harakatlens.arabic.VocalizationDictionary
import dev.veeso.harakatlens.arabic.arabicConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment

/**
 * App-side seam assertions, mirroring the BiangBiangUI example
 * `ConfigSeamTest` Arabic cases. Runs under Robolectric so the config can
 * load its JSON assets via `Context.assets` and `ArabicTransliterator` can
 * use the bundled `com.ibm.icu` Any-Latin transform.
 */
@RunWith(RobolectricTestRunner::class)
class ArabicConfigSeamTest {

    private val context: Context get() = RuntimeEnvironment.getApplication()

    @Test fun arabicConfigHasQuranPluginAndDescriptor() {
        val cfg = arabicConfig(context)
        assertEquals(1, cfg.plugins.size)
        assertTrue(cfg.extraSettings.any { it.key == "quranMode" })
        assertEquals("ar", cfg.languages[0].variants[0].ttsLanguageCode)
        assertTrue(cfg.languages[0].scriptRanges.first().contains(0x0628u))
    }

    @Test fun arabicTransliteratorRomanises() {
        val transliterator = ArabicTransliterator(
            Vocalizer(VocalizationDictionary.get(context)),
        )
        assertFalse(transliterator.transliterate("السلام").isEmpty())
    }
}
