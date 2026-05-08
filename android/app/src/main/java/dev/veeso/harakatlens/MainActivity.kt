package dev.veeso.harakatlens

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import dev.veeso.harakatlens.ui.MainScreen
import dev.veeso.harakatlens.ui.theme.HarakatLensTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            HarakatLensTheme {
                MainScreen()
            }
        }
    }
}
