import { PositionCallback, PositionProvider, ProviderStatusCallback } from './positionProvider';
import { UserPositionState } from './userPosition';
import { VPSPose, VPSStatus } from '../../vps/vpsTypes';
import { ARCorePose, ARCoreTrackingProvider } from './ARCoreTrackingProvider';

export interface FusedPose extends UserPositionState {
    timestamp: number;
    vpsLastUpdatedMs: number;
    driftMeters: number;
    status: 'ACTIVE' | 'DRIFTING' | 'WEAK_SIGNAL' | 'LOST';
}

export type FusedPoseCallback = (fusedPose: FusedPose) => void;

export class PoseFusion implements PositionProvider {
    private arCoreProvider: ARCoreTrackingProvider;
    private lastArCorePose: ARCorePose | null = null;
    private isRunning = false;

    private fusedPose: FusedPose = {
        position: { x: 0, y: 0, z: 0 },
        heading: 0,
        floor: 1,
        accuracy: 1.0,
        timestamp: Date.now(),
        vpsLastUpdatedMs: 0,
        driftMeters: 0,
        status: 'WEAK_SIGNAL',
    };

    private positionSubscribers: Set<PositionCallback> = new Set();
    private fusedPoseSubscribers: Set<FusedPoseCallback> = new Set();
    private statusSubscribers: Set<ProviderStatusCallback> = new Set();

    // Blend / Drift Correction Configuration
    private blendFactor = 0.3; // Weight of VPS pose correction (0.0 to 1.0)
    private maxTeleportDistanceMeters = 5.0; // Distance beyond which immediate snap occurs
    private confidenceThresholdMeters = 2.0;

    constructor(arCoreProvider: ARCoreTrackingProvider) {
        this.arCoreProvider = arCoreProvider;

        // Subscribe to high-frequency ARCore relative poses
        this.arCoreProvider.onPoseUpdate((arPose) => {
            this.handleARCoreUpdate(arPose);
        });
    }

    public async start(videoContainer?: HTMLElement): Promise<void> {
        this.isRunning = true;
        this.arCoreProvider.start();
    }

    public stop(): void {
        this.isRunning = false;
        this.arCoreProvider.stop();
    }

    public onPositionUpdate(callback: PositionCallback): () => void {
        this.positionSubscribers.add(callback);
        callback(this.getCurrentPosition());
        return () => {
            this.positionSubscribers.delete(callback);
        };
    }

    public onFusedPoseUpdate(callback: FusedPoseCallback): () => void {
        this.fusedPoseSubscribers.add(callback);
        callback({ ...this.fusedPose });
        return () => {
            this.fusedPoseSubscribers.delete(callback);
        };
    }

    public onStatusUpdate(callback: ProviderStatusCallback): () => void {
        this.statusSubscribers.add(callback);
        return () => {
            this.statusSubscribers.delete(callback);
        };
    }

    public getCurrentPosition(): UserPositionState {
        return {
            position: { ...this.fusedPose.position },
            heading: this.fusedPose.heading,
            floor: this.fusedPose.floor,
            accuracy: this.fusedPose.accuracy,
        };
    }

    public getFusedPose(): FusedPose {
        return { ...this.fusedPose };
    }

    /**
     * Called when a low-frequency VPS absolute pose arrives.
     * Fuses VPS pose into fusedPose with smooth drift correction.
     */
    public applyVPSCorrection(vpsPose: VPSPose | null, vpsStatus: VPSStatus = 'VPS_LOCALIZED'): void {
        if (!vpsPose) {
            const timeSinceVPS = Date.now() - this.fusedPose.vpsLastUpdatedMs;
            if (timeSinceVPS > 10000) {
                this.fusedPose.status = 'WEAK_SIGNAL';
            }
            this.notifySubscribers();
            return;
        }

        const now = Date.now();
        const isFirstUpdate = this.fusedPose.vpsLastUpdatedMs === 0;
        this.fusedPose.vpsLastUpdatedMs = now;
        this.fusedPose.floor = vpsPose.floor;
        this.fusedPose.accuracy = vpsPose.accuracy;

        const currentPos = this.fusedPose.position;
        const targetPos = vpsPose.position;

        const dx = targetPos.x - currentPos.x;
        const dy = targetPos.y - currentPos.y;
        const dz = targetPos.z - currentPos.z;
        const drift = Math.sqrt(dx * dx + dy * dy + dz * dz);
        this.fusedPose.driftMeters = Math.round(drift * 100) / 100;

        if (vpsPose.accuracy <= this.confidenceThresholdMeters) {
            if (drift > this.maxTeleportDistanceMeters || isFirstUpdate) {
                // Large discrepancy or initial localization: snap directly
                this.fusedPose.position = { ...targetPos };
                this.fusedPose.heading = vpsPose.heading;
            } else {
                // Smooth blending correction (lerp)
                this.fusedPose.position.x += dx * this.blendFactor;
                this.fusedPose.position.y += dy * this.blendFactor;
                this.fusedPose.position.z += dz * this.blendFactor;

                // Blend heading smoothly
                let dh = vpsPose.heading - this.fusedPose.heading;
                if (dh > 180) dh -= 360;
                if (dh < -180) dh += 360;
                this.fusedPose.heading = (this.fusedPose.heading + dh * this.blendFactor + 360) % 360;
            }
            this.fusedPose.status = 'ACTIVE';
        } else {
            // Low confidence update
            this.fusedPose.status = 'DRIFTING';
        }

        // Sync last relative ARCore pose reference frame
        this.lastArCorePose = this.arCoreProvider.getCurrentPose();
        this.fusedPose.timestamp = now;
        this.notifySubscribers();
    }

    private handleARCoreUpdate(arPose: ARCorePose): void {
        if (!this.lastArCorePose) {
            this.lastArCorePose = { ...arPose };
            return;
        }

        // Calculate relative delta from last ARCore update
        const dx = arPose.position.x - this.lastArCorePose.position.x;
        const dy = arPose.position.y - this.lastArCorePose.position.y;
        const dz = arPose.position.z - this.lastArCorePose.position.z;
        let dh = arPose.heading - this.lastArCorePose.heading;

        this.lastArCorePose = { ...arPose };

        // Apply continuous relative delta directly to current fused pose
        this.fusedPose.position.x += dx;
        this.fusedPose.position.y += dy;
        this.fusedPose.position.z += dz;
        this.fusedPose.heading = (this.fusedPose.heading + dh + 360) % 360;
        this.fusedPose.timestamp = Date.now();

        this.notifySubscribers();
    }

    private notifySubscribers(): void {
        const userState = this.getCurrentPosition();
        for (const sub of this.positionSubscribers) {
            sub(userState);
        }
        for (const sub of this.fusedPoseSubscribers) {
            sub({ ...this.fusedPose });
        }
    }
}
