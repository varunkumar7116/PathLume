package com.pathlume.app.domain.model

import kotlinx.serialization.Serializable

@Serializable
data class Site(
    val siteId: String,
    val name: String,
    val type: String = "generic",
    val description: String = "",
    val buildings: List<Building> = emptyList(),
    val destinations: List<Destination> = emptyList(),
    val vpsConfiguration: VPSConfiguration = VPSConfiguration(),
    val coordinateSystem: CoordinateSystemConfig = CoordinateSystemConfig()
)

@Serializable
data class Building(
    val id: String,
    val name: String,
    val floors: List<Floor> = emptyList()
)

@Serializable
data class Floor(
    val id: String,
    val floorNumber: Int,
    val name: String,
    val modelUrl: String? = null
)

@Serializable
data class Destination(
    val id: String,
    val name: String,
    val buildingId: String,
    val floorId: String,
    val position: Vector3D,
    val category: String = "general"
)

@Serializable
data class Vector3D(
    val x: Float,
    val y: Float,
    val z: Float
)

@Serializable
data class VPSConfiguration(
    val provider: String = "mock",
    val serverUrl: String = "https://pathlume.app/api/vps",
    val frameRateHz: Int = 5
)

@Serializable
data class CoordinateSystemConfig(
    val translation: Vector3D = Vector3D(0f, 0f, 0f),
    val rotation: Vector3D = Vector3D(0f, 0f, 0f),
    val scale: Float = 1.0f
)

@Serializable
data class QRPayload(
    val siteId: String,
    val anchorId: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)
