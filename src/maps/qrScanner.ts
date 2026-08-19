import { QRPayload } from './mapTypes';
import { MapManager } from './mapManager';

export type QRScanCallback = (payload: QRPayload, rawString: string) => void;
export type QRErrorCallback = (error: string) => void;

export class QRScanner {
    private mapManager: MapManager;
    private videoElement: HTMLVideoElement | null = null;
    private stream: MediaStream | null = null;
    private isScanning = false;
    private scanIntervalId: any = null;
    private barcodeDetector: any = null;

    constructor(mapManager: MapManager) {
        this.mapManager = mapManager;
        if ('BarcodeDetector' in window) {
            try {
                this.barcodeDetector = new (window as any).BarcodeDetector({
                    formats: ['qr_code'],
                });
            } catch {
                this.barcodeDetector = null;
            }
        }
    }

    public async startScanning(
        videoContainer: HTMLElement,
        onSuccess: QRScanCallback,
        onError?: QRErrorCallback
    ): Promise<void> {
        if (this.isScanning) return;

        try {
            this.stream = await navigator.mediaDevices.getUserMedia({
                video: { facingMode: 'environment' },
            });

            this.videoElement = document.createElement('video');
            this.videoElement.srcObject = this.stream;
            this.videoElement.setAttribute('playsinline', 'true');
            this.videoElement.style.width = '100%';
            this.videoElement.style.height = '100%';
            this.videoElement.style.objectFit = 'cover';

            videoContainer.appendChild(this.videoElement);
            await this.videoElement.play();
            this.isScanning = true;

            this.scanIntervalId = setInterval(async () => {
                if (!this.isScanning || !this.videoElement) return;

                if (this.barcodeDetector && this.videoElement.readyState === 4) {
                    try {
                        const barcodes = await this.barcodeDetector.detect(this.videoElement);
                        if (barcodes && barcodes.length > 0) {
                            const rawValue = barcodes[0].rawValue;
                            const payload = this.mapManager.parseQRPayload(rawValue);
                            if (payload) {
                                this.stopScanning();
                                onSuccess(payload, rawValue);
                            }
                        }
                    } catch {
                        // Detection frame skip
                    }
                }
            }, 300);
        } catch (err: any) {
            if (onError) {
                onError(err.message || 'Camera permission denied or camera not found');
            }
        }
    }

    public stopScanning(): void {
        this.isScanning = false;
        if (this.scanIntervalId) {
            clearInterval(this.scanIntervalId);
            this.scanIntervalId = null;
        }
        if (this.stream) {
            for (const track of this.stream.getTracks()) {
                track.stop();
            }
            this.stream = null;
        }
        if (this.videoElement && this.videoElement.parentNode) {
            this.videoElement.parentNode.removeChild(this.videoElement);
            this.videoElement = null;
        }
    }

    public simulateScan(qrInput: string | object, onSuccess: QRScanCallback): boolean {
        const payload = this.mapManager.parseQRPayload(qrInput);
        if (payload) {
            onSuccess(payload, typeof qrInput === 'string' ? qrInput : JSON.stringify(qrInput));
            return true;
        }
        return false;
    }
}
