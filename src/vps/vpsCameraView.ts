export type FrameCallback = (imageFrameBase64: string) => void;

export class VPSCameraView {
    private videoElement: HTMLVideoElement | null = null;
    private canvasElement: HTMLCanvasElement | null = null;
    private canvasCtx: CanvasRenderingContext2D | null = null;
    private mediaStream: MediaStream | null = null;
    private frameIntervalId: ReturnType<typeof setInterval> | null = null;
    private frameRate = 5; // default 5 FPS
    private frameCallback: FrameCallback | null = null;
    private isStreaming = false;

    constructor(frameRate = 5) {
        this.frameRate = frameRate;
    }

    public setFrameRate(fps: number): void {
        this.frameRate = Math.max(1, Math.min(30, fps));
        if (this.isStreaming) {
            this.stopFrameCapture();
            this.startFrameCapture();
        }
    }

    public onFrame(callback: FrameCallback): void {
        this.frameCallback = callback;
    }

    public async startCamera(videoElementContainer?: HTMLElement): Promise<boolean> {
        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: {
                    facingMode: { ideal: 'environment' }, // Rear camera
                    width: { ideal: 640 },
                    height: { ideal: 480 },
                },
                audio: false,
            });

            this.mediaStream = stream;

            if (!this.videoElement) {
                this.videoElement = document.createElement('video');
                this.videoElement.autoplay = true;
                this.videoElement.playsInline = true; // Essential for iOS/Android WebView
                this.videoElement.muted = true;
                this.videoElement.style.width = '100%';
                this.videoElement.style.height = '100%';
                this.videoElement.style.objectFit = 'cover';
            }

            this.videoElement.srcObject = stream;
            await this.videoElement.play();

            if (videoElementContainer && !videoElementContainer.contains(this.videoElement)) {
                videoElementContainer.appendChild(this.videoElement);
            }

            // Create offscreen capture canvas
            if (!this.canvasElement) {
                this.canvasElement = document.createElement('canvas');
                this.canvasElement.width = 480;
                this.canvasElement.height = 360;
                this.canvasCtx = this.canvasElement.getContext('2d');
            }

            this.isStreaming = true;
            this.startFrameCapture();
            return true;
        } catch (err) {
            console.warn('Camera access unavailable or rejected:', err);
            this.isStreaming = false;
            return false;
        }
    }

    public stopCamera(): void {
        this.stopFrameCapture();
        if (this.mediaStream) {
            for (const track of this.mediaStream.getTracks()) {
                track.stop();
            }
            this.mediaStream = null;
        }
        if (this.videoElement && this.videoElement.parentElement) {
            this.videoElement.parentElement.removeChild(this.videoElement);
        }
        this.isStreaming = false;
    }

    private startFrameCapture(): void {
        const intervalMs = Math.round(1000 / this.frameRate);
        this.frameIntervalId = setInterval(() => this.captureFrame(), intervalMs);
    }

    private stopFrameCapture(): void {
        if (this.frameIntervalId) {
            clearInterval(this.frameIntervalId);
            this.frameIntervalId = null;
        }
    }

    public captureFrame(): string | null {
        if (!this.videoElement || !this.canvasCtx || !this.canvasElement || !this.isStreaming) {
            return null;
        }

        if (this.videoElement.readyState < 2) {
            return null; // Not ready yet
        }

        // Draw current video frame to canvas
        this.canvasCtx.drawImage(
            this.videoElement,
            0,
            0,
            this.canvasElement.width,
            this.canvasElement.height
        );

        // Export compressed JPEG base64 frame
        const frameBase64 = this.canvasElement.toDataURL('image/jpeg', 0.6);

        if (this.frameCallback) {
            this.frameCallback(frameBase64);
        }

        return frameBase64;
    }
}
