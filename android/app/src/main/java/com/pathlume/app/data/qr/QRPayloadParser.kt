package com.pathlume.app.data.qr

import android.net.Uri
import com.pathlume.app.domain.model.QRPayload
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

object QRPayloadParser {
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Parses any scanned QR string or deep link URI into a canonical QRPayload.
     * Supports:
     * 1. Canonical HTTP URL: https://pathlume.app/s/{siteId}
     * 2. Custom Scheme URI: pathlume://site/{siteId}
     * 3. Legacy URI: navcat://map/{siteId}/{anchorId}
     * 4. JSON Payload: { "siteId": "demo_site" }
     * 5. Plain Site ID String: demo_site
     */
    fun parse(rawInput: String?): QRPayload? {
        if (rawInput.isNull_or_blank()) return null
        val trimmed = rawInput.trim()

        // 1. Try parsing JSON
        if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
            try {
                val jsonObject = json.parseToJsonElement(trimmed).jsonObject
                val siteId = jsonObject["siteId"]?.jsonPrimitive?.content
                    ?: jsonObject["mapId"]?.jsonPrimitive?.content
                val anchorId = jsonObject["anchorId"]?.jsonPrimitive?.content
                if (!siteId.isNull_or_blank()) {
                    return QRPayload(siteId = siteId, anchorId = anchorId)
                }
            } catch (e: Exception) {
                // Ignore JSON parse errors and fall through to URI parser
            }
        }

        // 2. Try parsing URI / URL
        try {
            val uri = Uri.parse(trimmed)

            // 2a. https://pathlume.app/s/{siteId}
            if ((uri.scheme == "https" || uri.scheme == "http") &&
                (uri.host == "pathlume.app" || uri.host == "www.pathlume.app" || uri.host == "localhost" || uri.host == "10.0.2.2")
            ) {
                val segments = uri.pathSegments
                if (segments.size >= 2 && segments[0] == "s") {
                    return QRPayload(siteId = segments[1])
                }
            }

            // 2b. pathlume://site/{siteId}
            if (uri.scheme == "pathlume" && uri.host == "site") {
                val siteId = uri.lastPathSegment
                if (!siteId.isNull_or_blank()) {
                    return QRPayload(siteId = siteId)
                }
            }

            // 2c. Legacy format: navcat://map/{siteId}/{anchorId}
            if (uri.scheme == "navcat" && uri.host == "map") {
                val segments = uri.pathSegments
                if (segments.isNotEmpty()) {
                    val siteId = segments[0]
                    val anchorId = if (segments.size > 1) segments[1] else null
                    return QRPayload(siteId = siteId, anchorId = anchorId)
                }
            }
        } catch (e: Exception) {
            // Ignore URI parse exceptions
        }

        // 3. Fallback: treat raw string as direct siteId if non-empty
        if (!trimmed.contains(" ") && trimmed.length < 64) {
            return QRPayload(siteId = trimmed)
        }

        return null
    }

    private fun String?.isNull_or_blank(): Boolean = this == null || this.trim().isEmpty()
}
