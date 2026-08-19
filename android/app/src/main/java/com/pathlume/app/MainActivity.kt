package com.pathlume.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.rememberNavController
import com.pathlume.app.data.qr.QRPayloadParser
import com.pathlume.app.navigation.PathLumeNavGraph
import com.pathlume.app.navigation.Screen
import com.pathlume.app.presentation.theme.NavyDark
import com.pathlume.app.presentation.theme.PathLumeTheme

class MainActivity : ComponentActivity() {

    private var initialDeepLinkSiteId by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate()

        // Handle initial deep link intent if app opened via URL / URI scheme
        handleDeepLinkIntent(intent)

        setContent {
            PathLumeTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = NavyDark
                ) {
                    val navController = rememberNavController()
                    val startDestination = initialDeepLinkSiteId?.let { siteId ->
                        Screen.SiteLoading.createRoute(siteId)
                    } ?: Screen.Splash.route

                    PathLumeNavGraph(
                        navController = navController,
                        startDestination = startDestination
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLinkIntent(intent)
    }

    private fun handleDeepLinkIntent(intent: Intent?) {
        val dataUri = intent?.data?.toString()
        if (!dataUri.isNull_or_empty()) {
            val payload = QRPayloadParser.parse(dataUri)
            if (payload != null && payload.siteId.isNotEmpty()) {
                initialDeepLinkSiteId = payload.siteId
            }
        }
    }

    private fun String?.isNull_or_empty(): Boolean = this == null || this.isEmpty()
}
