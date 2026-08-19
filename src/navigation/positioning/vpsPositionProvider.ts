import { PositionCallback, PositionProvider, ProviderStatusCallback } from './positionProvider';
import { DEFAULT_USER_POSITION, UserPositionState } from './userPosition';
import { VPSAdapter } from '../../vps/vpsAdapter';
import { VPSCameraView } from '../../vps/vpsCameraView';
import { VPSPose, VPSStatus } from '../../vps/vpsTypes';

export class VPSPositionProvider implements PositionProvider {
    private adapter: VPSAdapter;
    private cameraView: VPSCameraView;
    private currentPositionState: UserPositionState = DEFAULT_USER_POSITION;
    private positionSubscribers: Set<PositionCallback> = new Set();
    private statusSubscribers: Set<ProviderStatusCallback> = new Set();
    private isRunning = false;
    private currentPose: VPSPose | null = null;
    private activeMapId = 'building_01';

    constructor(adapter: VPSAdapter, cameraView: VPSCameraView) {
        this.adapter = adapter;
        this.cameraView = cameraView;

        // Listen for frame capture from camera
        this.cameraView.onFrame(async (frameBase64) => {
            if (this.isRunning) {
                await this.processFrame(frameBase64);
            }
        });

        // Listen for adapter status updates
        this.adapter.onStatusUpdate((status, pose, latencyMs) => {
            this.notifyStatus(status, { pose, latencyMs });
        });
    }

    public setActiveMapId(mapId: string): void {
        this.activeMapId = mapId;
    }

    public onPositionUpdate(callback: PositionCallback): () => void {
        this.positionSubscribers.add(callback);
        callback(this.currentPositionState);
        return () => {
            this.positionSubscribers.delete(callback);
        };
    }

    public subscribe(callback: PositionCallback): () => void {
        return this.onPositionUpdate(callback);
    }

    public onStatusUpdate(callback: ProviderStatusCallback): () => void {
        this.statusSubscribers.add(callback);
        return () => {
            this.statusSubscribers.delete(callback);
        };
    }

    public getCurrentPosition(): UserPositionState {
        return { ...this.currentPositionState };
    }

    public getCurrentPose(): VPSPose | null {
        return this.currentPose ? { ...this.currentPose } : null;
    }

    public async start(videoContainer?: HTMLElement): Promise<void> {
        if (this.isRunning) return;
        this.isRunning = true;
        await this.cameraView.startCamera(videoContainer);
    }

    public stop(): void {
        this.isRunning = false;
        this.cameraView.stopCamera();
    }

    private async processFrame(frameBase64: string): Promise<void> {
        const pose = await this.adapter.localize(frameBase64, this.activeMapId);
        if (pose) {
            this.currentPose = pose;
            this.currentPositionState = {
                position: { ...pose.position },
                floor: pose.floor,
                heading: pose.heading,
                accuracy: pose.accuracy,
            };

            for (const sub of this.positionSubscribers) {
                sub(this.currentPositionState);
            }
        }
    }

    private notifyStatus(status: VPSStatus, details?: any): void {
        for (const sub of this.statusSubscribers) {
            sub(status, details);
        }
    }
}
