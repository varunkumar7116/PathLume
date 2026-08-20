package com.pathlume.app.data.remote

import com.pathlume.app.domain.model.Destination
import com.pathlume.app.domain.model.Site
import com.pathlume.app.domain.model.VPSConfiguration
import kotlinx.serialization.Serializable
import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path

@Serializable
data class LocalizeRequest(
    val siteId: String,
    val image: String, // base64 encoded frame
    val timestamp: Long = System.currentTimeMillis()
)

@Serializable
data class LocalizeResponse(
    val localized: Boolean,
    val position: com.pathlume.app.domain.model.Vector3D? = null,
    val heading: Float? = null,
    val floor: Int? = null,
    val accuracy: Float? = null,
    val message: String? = null
)

@Serializable
data class NavigationGraphData(
    val nodes: List<NavigationNodeData> = emptyList(),
    val edges: List<NavigationEdgeData> = emptyList()
)

@Serializable
data class NavigationNodeData(
    val id: String,
    val x: Float,
    val y: Float,
    val z: Float,
    val floorId: String,
    val buildingId: String,
    val type: String = "walkable"
)

@Serializable
data class NavigationEdgeData(
    val from: String,
    val to: String,
    val distance: Float,
    val walkable: Boolean = true,
    val transitionType: String = "walk"
)

@Serializable
data class ModelReferenceData(
    val buildingId: String,
    val floorId: String,
    val modelUrl: String
)

interface PathLumeApiService {
    @GET("api/sites/{siteId}")
    suspend fun getSiteConfig(@Path("siteId") siteId: String): Response<Site>

    @GET("api/sites/{siteId}/destinations")
    suspend fun getDestinations(@Path("siteId") siteId: String): Response<List<Destination>>

    @GET("api/sites/{siteId}/navigation")
    suspend fun getNavigationGraph(@Path("siteId") siteId: String): Response<NavigationGraphData>

    @GET("api/sites/{siteId}/models")
    suspend fun getModelReferences(@Path("siteId") siteId: String): Response<List<ModelReferenceData>>

    @GET("api/sites/{siteId}/vps/config")
    suspend fun getVPSConfig(@Path("siteId") siteId: String): Response<VPSConfiguration>

    @POST("api/vps/localize")
    suspend fun localizeFrame(@Body request: LocalizeRequest): Response<LocalizeResponse>
}

object PathLumeApiClient {
    fun create(baseUrl: String = "https://pathlume-9d8e9.web.app/"): PathLumeApiService {
        val formattedUrl = if (baseUrl.endsWith("/")) baseUrl else "$baseUrl/"
        val retrofit = retrofit2.Retrofit.Builder()
            .baseUrl(formattedUrl)
            .addConverterFactory(retrofit2.converter.gson.GsonConverterFactory.create())
            .build()
        return retrofit.create(PathLumeApiService::class.java)
    }
}
