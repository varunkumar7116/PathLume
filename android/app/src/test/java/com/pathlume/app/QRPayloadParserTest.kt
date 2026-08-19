package com.pathlume.app

import com.pathlume.app.data.qr.QRPayloadParser
import org.junit.Assert.*
import org.junit.Test

class QRPayloadParserTest {

    @Test
    fun parse_httpUrl_extractsSiteId() {
        val payload = QRPayloadParser.parse("https://pathlume.app/s/site_001")
        assertNotNull(payload)
        assertEquals("site_001", payload?.siteId)
    }

    @Test
    fun parse_customScheme_extractsSiteId() {
        val payload = QRPayloadParser.parse("pathlume://site/site_001")
        assertNotNull(payload)
        assertEquals("site_001", payload?.siteId)
    }

    @Test
    fun parse_legacyScheme_extractsSiteId() {
        val payload = QRPayloadParser.parse("navcat://map/college_block_a/entrance_01")
        assertNotNull(payload)
        assertEquals("college_block_a", payload?.siteId)
        assertEquals("entrance_01", payload?.anchorId)
    }

    @Test
    fun parse_jsonPayload_extractsSiteId() {
        val payload = QRPayloadParser.parse("""{"siteId": "demo_site", "anchorId": "front_door"}""")
        assertNotNull(payload)
        assertEquals("demo_site", payload?.siteId)
        assertEquals("front_door", payload?.anchorId)
    }

    @Test
    fun parse_plainString_extractsSiteId() {
        val payload = QRPayloadParser.parse("demo_site")
        assertNotNull(payload)
        assertEquals("demo_site", payload?.siteId)
    }
}
