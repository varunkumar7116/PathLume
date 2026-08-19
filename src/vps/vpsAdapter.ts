import { VPSClient } from './vpsClient';

import {
    VPSBackendResponse,
    VPSPose,
    VPSStatus,
    VPSTransformConfig,
} from './vpsTypes';

import { DEFAULT_TRANSFORM_CONFIG, vpsToWorldPose } from './vpsTransform';

export type VPSStatusCallback = (status: VPSStatus, pose: VPSPose | null, latencyMs: number) => void;

export class VPSAdapter {
    private client: VPSClient;
    private status: VPSStatus = 'VPS_SEARCHING';
    private lastValidPose: VPSPose | null = null;
    private lastPoseTimestamp = 0;
    private statusSubscribers: Set<VPSStatusCallback> = new Set();
    private transformConfig: VPSTransformConfig = DEFAULT_TRANSFORM_CONFIG;
    private lostTimeoutMs = 8000;
    private confidenceThresholdMeters = 2.0;

    constructor(client: VPSClient) {
        this.client = client;
    }

    public setTransformConfig(config: VPSTransformConfig): void {
        this.transformConfig = config;
    }

    public getStatus(): VPSStatus {
        return this.status;
    }

    public getLastValidPose(): VPSPose | null {
        return this.lastValidPose;
    }

    public onStatusUpdate(callback: VPSStatusCallback): () => void {
        this.statusSubscribers.add(callback);
        callback(this.status, this.lastValidPose, this.client.getLastLatencyMs());
        return () => {
            this.statusSubscribers.delete(callback);
        };
    }

    /**
     * Accepts a camera image frame, calls VPS backend, validates, transforms coordinates,
     * updates VPSStatus state, and returns standard VPSPose.
     */
    public async localize(imageFrameBase64: string, mapId = 'building_01'): Promise<VPSPose | null> {
        const response = await this.client.localizeFrame(imageFrameBase64, mapId);

        if (!response || !response.localized || !response.position) {
            this.handleFailure(response?.message || 'Unlocalized frame');
            return this.lastValidPose; // Keep last known pose during temporary failure
        }

        const rawPose: VPSPose = {
            position: response.position,
            rotation: response.rotation || { x: 0, y: 0, z: 0, w: 1 },
            heading: response.heading ?? 0,
            floor: response.floor ?? 1,
            accuracy: response.accuracy ?? 0.5,
            timestamp: Date.now(),
        };

        // Convert raw VPS pose to GLB world coordinates
        const transformedPose = vpsToWorldPose(rawPose, this.transformConfig);

        this.lastValidPose = transformedPose;
        this.lastPoseTimestamp = Date.now();

        // Check confidence threshold
        if (transformedPose.accuracy > this.confidenceThresholdMeters) {
            this.setStatus('VPS_LOW_CONFIDENCE', transformedPose);
        } else {
            this.setStatus('VPS_LOCALIZED', transformedPose);
        }

        return transformedPose;
    }

    private handleFailure(reason: string): void {
        const now = Date.now();
        const timeSinceLastPose = now - this.lastPoseTimestamp;

        if (this.lastValidPose && timeSinceLastPose < this.lostTimeoutMs) {
            this.setStatus('VPS_LOST', this.lastValidPose);
        } else if (reason.includes('Network') || reason.includes('Error')) {
            this.setStatus('VPS_ERROR', null);
        } else {
            this.setStatus('VPS_SEARCHING', null);
        }
    }

    private setStatus(newStatus: VPSStatus, pose: VPSPose | null): void {
        this.status = newStatus;
        const latency = this.client.getLastLatencyMs();
        for (const sub of this.statusSubscribers) {
            sub(newStatus, pose, latency);
        }
    }
}
