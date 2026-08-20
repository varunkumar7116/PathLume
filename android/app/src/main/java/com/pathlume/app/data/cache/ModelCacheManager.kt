package com.pathlume.app.data.cache

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class ModelCacheManager(private val context: Context) {

    private val modelsDir = File(context.cacheDir, "site_models").also {
        if (!it.exists()) it.mkdirs()
    }

    /**
     * Gets or downloads the GLB model for a site version.
     * Returns local File reference.
     */
    suspend fun getOrFetchModel(siteId: String, version: Int, modelUrl: String?): File? = withContext(Dispatchers.IO) {
        val safeModelName = "${siteId}_v${version}.glb"
        val cachedFile = File(modelsDir, safeModelName)

        // 1. Return cached file if valid and non-empty
        if (cachedFile.exists() && cachedFile.length() > 0) {
            return@withContext cachedFile
        }

        // 2. Check bundled app assets for fallback (e.g. models/sample1.glb)
        val assetPath = when {
            siteId == "sample1" -> "models/sample1.glb"
            modelUrl != null && modelUrl.contains("sample1.glb") -> "models/sample1.glb"
            else -> null
        }

        if (assetPath != null) {
            try {
                context.assets.open(assetPath).use { input ->
                    FileOutputStream(cachedFile).use { output ->
                        input.copyTo(output)
                    }
                }
                if (cachedFile.exists() && cachedFile.length() > 0) {
                    return@withContext cachedFile
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 3. Network download if URL provided
        if (!modelUrl.isNullOrEmpty()) {
            val urlStr = modelUrl!!
            if (urlStr.startsWith("http://") || urlStr.startsWith("https://")) {
                try {
                    val url = URL(urlStr)
                    val connection = url.openConnection() as HttpURLConnection
                    connection.connectTimeout = 10000
                    connection.readTimeout = 15000
                    connection.connect()

                    if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                        connection.inputStream.use { input ->
                            FileOutputStream(cachedFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                        if (cachedFile.exists() && cachedFile.length() > 0) {
                            return@withContext cachedFile
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        return@withContext if (cachedFile.exists()) cachedFile else null
    }
}
