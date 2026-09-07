package com.pathlume.app.ar

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import com.google.ar.core.AugmentedImage
import com.google.ar.core.AugmentedImageDatabase
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Session

class ARAugmentedImageManager {
    companion object {
        private const val TAG = "PATHLUME_AR"
    }

    private var augmentedImageDatabase: AugmentedImageDatabase? = null
    @Volatile
    var latestImagePoseData: Map<String, Any>? = null
        private set

    fun setupAugmentedImageDatabase(session: Session, config: Config): Boolean {
        return try {
            val db = augmentedImageDatabase ?: AugmentedImageDatabase(session).also { augmentedImageDatabase = it }
            config.augmentedImageDatabase = db
            Log.i(TAG, "PATHLUME_AR AUGMENTED_IMAGE_DATABASE_CONFIGURED")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR AUGMENTED_IMAGE_DATABASE_FAILED", t)
            false
        }
    }

    fun addReferenceImage(session: Session, imageId: String, imageBytes: ByteArray, physicalWidthMeters: Float = 0.15f): Boolean {
        return try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size) ?: return false
            val db = augmentedImageDatabase ?: AugmentedImageDatabase(session).also { augmentedImageDatabase = it }
            db.addImage(imageId, bitmap, physicalWidthMeters)

            val config = session.config
            config.augmentedImageDatabase = db
            session.configure(config)
            Log.i(TAG, "PATHLUME_AR REFERENCE_IMAGE_ADDED imageId=$imageId width=$physicalWidthMeters")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR REFERENCE_IMAGE_ADD_FAILED imageId=$imageId", t)
            false
        }
    }

    fun processFrame(frame: Frame) {
        try {
            val updatedImages = frame.getUpdatedTrackables(AugmentedImage::class.java)
            for (image in updatedImages) {
                if (image.trackingState == com.google.ar.core.TrackingState.TRACKING) {
                    val pose = image.centerPose
                    latestImagePoseData = mapOf(
                        "imageDetected" to true,
                        "imageId" to image.name,
                        "trackingState" to image.trackingState.name,
                        "centerPose" to mapOf(
                            "position" to mapOf("x" to pose.tx(), "y" to pose.ty(), "z" to pose.tz()),
                            "rotation" to mapOf(
                                "x" to pose.qx(),
                                "y" to pose.qy(),
                                "z" to pose.qz(),
                                "w" to pose.qw()
                            )
                        ),
                        "extentX" to image.extentX,
                        "extentZ" to image.extentZ,
                        "timestamp" to System.currentTimeMillis()
                    )
                    Log.i(TAG, "PATHLUME_AR AUGMENTED_IMAGE_TRACKING imageId=${image.name} state=${image.trackingState.name} pos=(${pose.tx()}, ${pose.ty()}, ${pose.tz()})")
                    return
                } else if (image.trackingState == com.google.ar.core.TrackingState.PAUSED) {
                    latestImagePoseData = mapOf(
                        "imageDetected" to true,
                        "imageId" to image.name,
                        "trackingState" to image.trackingState.name,
                        "extentX" to image.extentX,
                        "extentZ" to image.extentZ,
                        "timestamp" to System.currentTimeMillis()
                    )
                }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "PATHLUME_AR AUGMENTED_IMAGE_PROCESS_FAILED", t)
        }
    }
}
