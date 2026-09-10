package com.pathlume.app.ar

import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.Matrix
import com.google.ar.core.Anchor
import com.google.ar.core.Frame
import com.google.ar.core.Session
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.ShortBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class ARRenderer : GLSurfaceView.Renderer {
    private var session: Session? = null
    private var textureId: Int = -1
    private var isTextureInitialized = false

    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val modelMatrix = FloatArray(16)
    private val modelViewProjectionMatrix = FloatArray(16)

    // Camera Background Quad Shader & Buffers
    private val quadVertices = floatArrayOf(
        -1.0f, -1.0f, 0.0f,
         1.0f, -1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f,
         1.0f,  1.0f, 0.0f
    )
    private val quadTexCoords = floatArrayOf(
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f
    )

    private lateinit var quadVertexBuffer: FloatBuffer
    private lateinit var quadTexCoordBufferOriginal: FloatBuffer
    private lateinit var quadTexCoordBufferTransformed: FloatBuffer

    private var cameraProgramHandle: Int = -1
    private var cameraPositionHandle: Int = -1
    private var cameraTexCoordHandle: Int = -1

    var displayRotationSupplier: (() -> Int)? = null

    // 3D Node Marker (Diamond / Pyramid Beacon) Program & Buffers
    private var programHandle: Int = -1
    private var positionHandle: Int = -1
    private var colorHandle: Int = -1
    private var mvpMatrixHandle: Int = -1

    private lateinit var vertexBuffer: FloatBuffer
    private lateinit var indexBuffer: ShortBuffer

    // 3D Diamond / Pyramid Beacon Vertices (Height: 0.30m, Width: 0.16m)
    private val beaconVertices = floatArrayOf(
        // Top pyramid tip
         0.00f,  0.15f,  0.00f, // 0
        // Middle diamond equator
        -0.08f,  0.00f,  0.08f, // 1
         0.08f,  0.00f,  0.08f, // 2
         0.08f,  0.00f, -0.08f, // 3
        -0.08f,  0.00f, -0.08f, // 4
        // Bottom pyramid tip
         0.00f, -0.15f,  0.00f  // 5
    )

    private val beaconIndices = shortArrayOf(
        // Upper pyramid faces
        0, 1, 2,  0, 2, 3,  0, 3, 4,  0, 4, 1,
        // Lower pyramid faces
        5, 2, 1,  5, 3, 2,  5, 4, 3,  5, 1, 4
    )

    var activeAnchors: List<Anchor> = emptyList()
    var onFrameUpdateListener: ((Frame, Session) -> Unit)? = null

    fun setSession(arSession: Session?) {
        this.session = arSession
        if (isTextureInitialized && textureId != -1 && arSession != null) {
            try {
                arSession.setCameraTextureName(textureId)
                android.util.Log.i("PATHLUME_AR", "PATHLUME_AR setCameraTextureName applied in setSession textureId=$textureId")
            } catch (t: Throwable) {
                android.util.Log.e("PATHLUME_AR", "Failed to setCameraTextureName in setSession", t)
            }
        }
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)

        // Initialize Camera OES Texture with Linear Filtering
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        textureId = textures[0]
        GLES20.glBindTexture(36197 /* GL_TEXTURE_EXTERNAL_OES */, textureId)
        GLES20.glTexParameteri(36197, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(36197, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(36197, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(36197, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        isTextureInitialized = true

        session?.setCameraTextureName(textureId)

        // Camera Background Quad Buffers
        quadVertexBuffer = ByteBuffer.allocateDirect(quadVertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(quadVertices)
        quadVertexBuffer.position(0)

        quadTexCoordBufferOriginal = ByteBuffer.allocateDirect(quadTexCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(quadTexCoords)
        quadTexCoordBufferOriginal.position(0)

        quadTexCoordBufferTransformed = ByteBuffer.allocateDirect(quadTexCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()

        // Camera Background Shaders
        val cameraVertexShaderCode = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """.trimIndent()

        val cameraFragmentShaderCode = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 vTexCoord;
            uniform samplerExternalOES sTexture;
            void main() {
                gl_FragColor = texture2D(sTexture, vTexCoord);
            }
        """.trimIndent()

        val cameraVertexShader = loadShader(GLES20.GL_VERTEX_SHADER, cameraVertexShaderCode)
        val cameraFragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, cameraFragmentShaderCode)
        cameraProgramHandle = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, cameraVertexShader)
            GLES20.glAttachShader(it, cameraFragmentShader)
            GLES20.glLinkProgram(it)
        }

        // Initialize 3D Beacon Buffers
        vertexBuffer = ByteBuffer.allocateDirect(beaconVertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(beaconVertices)
        vertexBuffer.position(0)

        indexBuffer = ByteBuffer.allocateDirect(beaconIndices.size * 2)
            .order(ByteOrder.nativeOrder())
            .asShortBuffer()
            .put(beaconIndices)
        indexBuffer.position(0)

        // 3D Overlay Shaders
        val vertexShaderCode = """
            uniform mat4 uMVPMatrix;
            attribute vec4 vPosition;
            void main() {
                gl_Position = uMVPMatrix * vPosition;
            }
        """.trimIndent()

        val fragmentShaderCode = """
            precision mediump float;
            uniform vec4 vColor;
            void main() {
                gl_FragColor = vColor;
            }
        """.trimIndent()

        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, vertexShaderCode)
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentShaderCode)

        programHandle = GLES20.glCreateProgram().also {
            GLES20.glAttachShader(it, vertexShader)
            GLES20.glAttachShader(it, fragmentShader)
            GLES20.glLinkProgram(it)
        }
    }

    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var lastDisplayRotation = -1
    private var lastDisplayWidth = -1
    private var lastDisplayHeight = -1

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        surfaceWidth = width
        surfaceHeight = height
        GLES20.glViewport(0, 0, width, height)
        val rotation = displayRotationSupplier?.invoke() ?: 0
        session?.setDisplayGeometry(rotation, width, height)
        lastDisplayRotation = rotation
        lastDisplayWidth = width
        lastDisplayHeight = height
    }

    private var frameCount = 0L
    private var lastLoggedAnchorCount = -1

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        frameCount++

        val currentSession = session ?: return
        if (!isTextureInitialized) return

        try {
            val rotation = displayRotationSupplier?.invoke() ?: 0
            if (surfaceWidth > 0 && surfaceHeight > 0 &&
                (rotation != lastDisplayRotation || surfaceWidth != lastDisplayWidth || surfaceHeight != lastDisplayHeight)) {
                currentSession.setDisplayGeometry(rotation, surfaceWidth, surfaceHeight)
                lastDisplayRotation = rotation
                lastDisplayWidth = surfaceWidth
                lastDisplayHeight = surfaceHeight
            }
            currentSession.setCameraTextureName(textureId)
            val frame = currentSession.update()

            onFrameUpdateListener?.invoke(frame, currentSession)

            // Render live camera background feed
            drawCameraBackground(frame)

            try {
                val camera = frame.camera
                if (camera.trackingState == com.google.ar.core.TrackingState.TRACKING || camera.trackingState == com.google.ar.core.TrackingState.PAUSED) {
                    camera.getProjectionMatrix(projectionMatrix, 0, 0.1f, 100.0f)
                    camera.getViewMatrix(viewMatrix, 0)

                    val anchors = ArrayList(activeAnchors)
                    if (anchors.size != lastLoggedAnchorCount) {
                        lastLoggedAnchorCount = anchors.size
                        android.util.Log.i("PATHLUME_AR", "PATHLUME_AR RENDERER_ANCHOR_UPDATED count=${anchors.size} tracking=${camera.trackingState.name}")
                    }

                    val anchorPositions = mutableListOf<FloatArray>()

                    // Render active spatial anchors (3D Diamond Beacons)
                    for (anchor in anchors) {
                        if (anchor.trackingState != com.google.ar.core.TrackingState.STOPPED) {
                            val pose = anchor.pose
                            pose.toMatrix(modelMatrix, 0)
                            anchorPositions.add(floatArrayOf(pose.tx(), pose.ty(), pose.tz()))

                            Matrix.multiplyMM(modelViewProjectionMatrix, 0, viewMatrix, 0, modelMatrix, 0)
                            Matrix.multiplyMM(modelViewProjectionMatrix, 0, projectionMatrix, 0, modelViewProjectionMatrix, 0)

                            drawBeaconNode(modelViewProjectionMatrix, pose.tx(), pose.ty(), pose.tz())
                        }
                    }

                    // Render broad 3D board line ribbon connecting consecutive anchors
                    if (anchorPositions.size >= 2) {
                        drawBroadPathRibbon(anchorPositions, floatArrayOf(0.0f, 1.0f, 0.5f, 0.9f))
                    }

                    // Render 3D Active Navigation Route (Broad Ribbon Path + Directional Arrows + Destination Marker)
                    val routeSnapshot = navigationRoutePoints
                    val destSnapshot = destinationPoint
                    if (routeSnapshot.size >= 2) {
                        drawBroadPathRibbon(routeSnapshot, floatArrayOf(0.0f, 0.9f, 1.0f, 0.95f))
                        drawDirectionalArrows(routeSnapshot)
                    }
                    destSnapshot?.let { dest ->
                        drawDestinationMarker(dest)
                    }
                }
            } catch (renderError: Exception) {
                android.util.Log.e("PATHLUME_AR", "PATHLUME_AR 3D_OBJECT_RENDER_ERROR frame=$frameCount", renderError)
            }
        } catch (e: Exception) {
            android.util.Log.e("PATHLUME_AR", "PATHLUME_AR FRAME_UPDATE_ERROR frame=$frameCount", e)
        } finally {
            // Restore depth testing & default GL state safety after frame completion
            GLES20.glDepthMask(true)
            GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        }
    }

    private fun drawCameraBackground(frame: Frame) {
        quadTexCoordBufferOriginal.rewind()
        quadTexCoordBufferTransformed.rewind()
        frame.transformDisplayUvCoords(quadTexCoordBufferOriginal, quadTexCoordBufferTransformed)
        quadTexCoordBufferTransformed.rewind()

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(cameraProgramHandle)

        cameraPositionHandle = GLES20.glGetAttribLocation(cameraProgramHandle, "aPosition")
        GLES20.glEnableVertexAttribArray(cameraPositionHandle)
        GLES20.glVertexAttribPointer(cameraPositionHandle, 3, GLES20.GL_FLOAT, false, 0, quadVertexBuffer)

        cameraTexCoordHandle = GLES20.glGetAttribLocation(cameraProgramHandle, "aTexCoord")
        GLES20.glEnableVertexAttribArray(cameraTexCoordHandle)
        GLES20.glVertexAttribPointer(cameraTexCoordHandle, 2, GLES20.GL_FLOAT, false, 0, quadTexCoordBufferTransformed)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(36197 /* GL_TEXTURE_EXTERNAL_OES */, textureId)
        val samplerHandle = GLES20.glGetUniformLocation(cameraProgramHandle, "sTexture")
        GLES20.glUniform1i(samplerHandle, 0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(cameraPositionHandle)
        GLES20.glDisableVertexAttribArray(cameraTexCoordHandle)
        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
    }

    private fun drawBeaconNode(mvpMatrix: FloatArray, tx: Float, ty: Float, tz: Float) {
        GLES20.glUseProgram(programHandle)

        positionHandle = GLES20.glGetAttribLocation(programHandle, "vPosition")
        GLES20.glEnableVertexAttribArray(positionHandle)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 12, vertexBuffer)

        colorHandle = GLES20.glGetUniformLocation(programHandle, "vColor")
        // Vibrant Cyan / Aqua 3D Diamond Node Color
        GLES20.glUniform4f(colorHandle, 0.0f, 0.95f, 1.0f, 1.0f)

        mvpMatrixHandle = GLES20.glGetUniformLocation(programHandle, "uMVPMatrix")
        GLES20.glUniformMatrix4fv(mvpMatrixHandle, 1, false, mvpMatrix, 0)

        GLES20.glDrawElements(GLES20.GL_TRIANGLES, beaconIndices.size, GLES20.GL_UNSIGNED_SHORT, indexBuffer)

        GLES20.glDisableVertexAttribArray(positionHandle)
    }

    private fun drawBroadPathRibbon(positions: List<FloatArray>, rgbaColor: FloatArray) {
        if (positions.size < 2) return

        // Generate broad 3D quad ribbon geometry (width = 0.20m = 20cm broad board line)
        val ribbonWidth = 0.20f
        val halfWidth = ribbonWidth / 2.0f

        val quadCoords = mutableListOf<Float>()

        for (i in 0 until positions.size - 1) {
            val p1 = positions[i]
            val p2 = positions[i + 1]

            val dx = p2[0] - p1[0]
            val dz = p2[2] - p1[2]
            val len = Math.sqrt((dx * dx + dz * dz).toDouble()).toFloat()

            val nx = if (len > 0.001f) (-dz / len) * halfWidth else halfWidth
            val nz = if (len > 0.001f) (dx / len) * halfWidth else 0f

            val y1 = p1[1]
            val y2 = p2[1]

            // First triangle (V0, V1, V2)
            quadCoords.add(p1[0] + nx); quadCoords.add(y1); quadCoords.add(p1[2] + nz)
            quadCoords.add(p1[0] - nx); quadCoords.add(y1); quadCoords.add(p1[2] - nz)
            quadCoords.add(p2[0] + nx); quadCoords.add(y2); quadCoords.add(p2[2] + nz)

            // Second triangle (V1, V3, V2)
            quadCoords.add(p1[0] - nx); quadCoords.add(y1); quadCoords.add(p1[2] - nz)
            quadCoords.add(p2[0] - nx); quadCoords.add(y2); quadCoords.add(p2[2] - nz)
            quadCoords.add(p2[0] + nx); quadCoords.add(y2); quadCoords.add(p2[2] + nz)
        }

        val ribbonBuffer = ByteBuffer.allocateDirect(quadCoords.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
        for (f in quadCoords) {
            ribbonBuffer.put(f)
        }
        ribbonBuffer.position(0)

        val vpMatrix = FloatArray(16)
        Matrix.multiplyMM(vpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)

        GLES20.glDisable(GLES20.GL_CULL_FACE)
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

        GLES20.glUseProgram(programHandle)

        positionHandle = GLES20.glGetAttribLocation(programHandle, "vPosition")
        GLES20.glEnableVertexAttribArray(positionHandle)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 12, ribbonBuffer)

        colorHandle = GLES20.glGetUniformLocation(programHandle, "vColor")
        GLES20.glUniform4fv(colorHandle, 1, rgbaColor, 0)

        mvpMatrixHandle = GLES20.glGetUniformLocation(programHandle, "uMVPMatrix")
        GLES20.glUniformMatrix4fv(mvpMatrixHandle, 1, false, vpMatrix, 0)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, quadCoords.size / 3)

        GLES20.glDisableVertexAttribArray(positionHandle)
    }

    @Volatile
    var navigationRoutePoints: List<FloatArray> = emptyList()
    @Volatile
    var destinationPoint: FloatArray? = null

    fun setNavigationRoute(points: List<FloatArray>, dest: FloatArray?) {
        this.navigationRoutePoints = points
        this.destinationPoint = dest
    }

    fun clearNavigationRoute() {
        this.navigationRoutePoints = emptyList()
        this.destinationPoint = null
    }

    private fun drawDirectionalArrows(positions: List<FloatArray>) {
        for (i in 0 until positions.size - 1) {
            val p1 = positions[i]
            val p2 = positions[i + 1]

            val dx = p2[0] - p1[0]
            val dy = p2[1] - p1[1]
            val dz = p2[2] - p1[2]
            val dist = Math.sqrt((dx * dx + dy * dy + dz * dz).toDouble()).toFloat()

            if (dist < 0.1f) continue

            val midX = p1[0] + dx * 0.5f
            val midY = p1[1] + dy * 0.5f
            val midZ = p1[2] + dz * 0.5f

            Matrix.setIdentityM(modelMatrix, 0)
            Matrix.translateM(modelMatrix, 0, midX, midY, midZ)

            val angleDeg = Math.toDegrees(Math.atan2(dx.toDouble(), dz.toDouble())).toFloat()
            Matrix.rotateM(modelMatrix, 0, angleDeg, 0f, 1f, 0f)

            Matrix.multiplyMM(modelViewProjectionMatrix, 0, viewMatrix, 0, modelMatrix, 0)
            Matrix.multiplyMM(modelViewProjectionMatrix, 0, projectionMatrix, 0, modelViewProjectionMatrix, 0)

            drawBeaconNode(modelViewProjectionMatrix, midX, midY, midZ)
        }
    }

    private fun drawDestinationMarker(dest: FloatArray) {
        Matrix.setIdentityM(modelMatrix, 0)
        Matrix.translateM(modelMatrix, 0, dest[0], dest[1] + 0.1f, dest[2])

        Matrix.multiplyMM(modelViewProjectionMatrix, 0, viewMatrix, 0, modelMatrix, 0)
        Matrix.multiplyMM(modelViewProjectionMatrix, 0, projectionMatrix, 0, modelViewProjectionMatrix, 0)

        GLES20.glUseProgram(programHandle)

        positionHandle = GLES20.glGetAttribLocation(programHandle, "vPosition")
        GLES20.glEnableVertexAttribArray(positionHandle)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 12, vertexBuffer)

        colorHandle = GLES20.glGetUniformLocation(programHandle, "vColor")
        // Gold / Yellow 3D Destination Beacon Color
        GLES20.glUniform4f(colorHandle, 1.0f, 0.84f, 0.0f, 1.0f)

        mvpMatrixHandle = GLES20.glGetUniformLocation(programHandle, "uMVPMatrix")
        GLES20.glUniformMatrix4fv(mvpMatrixHandle, 1, false, modelViewProjectionMatrix, 0)

        GLES20.glDrawElements(GLES20.GL_TRIANGLES, beaconIndices.size, GLES20.GL_UNSIGNED_SHORT, indexBuffer)

        GLES20.glDisableVertexAttribArray(positionHandle)
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        return GLES20.glCreateShader(type).also { shader ->
            GLES20.glShaderSource(shader, shaderCode)
            GLES20.glCompileShader(shader)
        }
    }
}
