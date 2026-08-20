package com.pathlume.app.data.qr

import com.pathlume.app.domain.model.QRPayload
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.net.URI

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
        if (rawInput.isNullOrBlank()) return null
        val trimmed = rawInput.trim()

        // 1. Try parsing JSON
        if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
            try {
                val jsonObject = json.parseToJsonElement(trimmed).jsonObject
                val siteId = jsonObject["siteId"]?.jsonPrimitive?.content
                    ?: jsonObject["mapId"]?.jsonPrimitive?.content
                val anchorId = jsonObject["anchorId"]?.jsonPrimitive?.content
                if (!siteId.isNullOrEmpty()) {
                    return QRPayload(siteId = siteId, anchorId = anchorId)
                }
            } catch (e: Exception) {
                // Ignore JSON parse errors and fall through
            }
        }

        // 2. Try parsing URI using java.net.URI (JVM & Android compatible)
        try {
            if (trimmed.contains("://")) {
                val uri = URI.create(trimmed)
                val scheme = uri.scheme?.lowercase()
                val host = uri.host?.lowercase()
                val rawPath = uri.path ?: ""
                val segments = rawPath.split("/").filter { it.isNotEmpty() }

                // 2a. HTTP / HTTPS URLs: http(s)://domain/s/{siteId} or http(s)://domain/site/{siteId}
                if (scheme == "https" || scheme == "http") {
                    if (segments.size >= 2 && (segments[0] == "s" || segments[0] == "site")) {
                        return QRPayload(siteId = sanitizeId(segments[1]))
                    } else if (segments.isNotEmpty()) {
                        return QRPayload(siteId = sanitizeId(segments.last()))
                    }
                }

                // 2b. pathlume://site/{siteId}
                if (scheme == "pathlume" && host == "site") {
                    if (segments.isNotEmpty()) {
                        return QRPayload(siteId = sanitizeId(segments[0]))
                    }
                }

                // 2c. Legacy format: navcat://map/{siteId}/{anchorId}
                if (scheme == "navcat" && host == "map") {
                    if (segments.isNotEmpty()) {
                        val siteId = sanitizeId(segments[0])
                        val anchorId = if (segments.size > 1) segments[1] else null
                        return QRPayload(siteId = siteId, anchorId = anchorId)
                    }
                }
            }
        } catch (e: Exception) {
            // Fall through to plain string check
        }

        // 3. Fallback: treat raw string as direct siteId if valid alphanumeric/slug
        if (!trimmed.contains(" ") && trimmed.length < 128) {
            return QRPayload(siteId = sanitizeId(trimmed))
        }

        return null
    }

    private fun sanitizeId(input: String): String {
        return input.replace('/', '_').trim()
    }
}
