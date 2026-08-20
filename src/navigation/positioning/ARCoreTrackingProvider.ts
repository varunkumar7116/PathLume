import { Vector3D } from '../graph/nodes';
import { Quaternion } from '../../vps/vpsTypes';

export interface ARCorePose {
    position: Vector3D;
    rotation: Quaternion;
    heading: number;
    timestamp: number;
    trackingState: 'TRACKING' | 'PAUSED' | 'STOPPED';
}

export type ARCorePoseCallback = (pose: ARCorePose) => void;

export class ARCoreTrackingProvider {
    private currentPose: ARCorePose = {
        position: { x: 0, y: 0, z: 0 },
        rotation: { x: 0, y: 0, z: 0, w: 1 },
        heading: 0,
        timestamp: Date.now(),
        trackingState: 'STOPPED',
    };

    private subscribers: Set<ARCorePoseCallback> = new Set();
    private animationFrameId: any = null;
    private isRunning = false;
    private lastFrameTime = 0;

    public getLastFrameTime(): number {
        return this.lastFrameTime;
    }

    public onPoseUpdate(callback: ARCorePoseCallback): () => void {
        this.subscribers.add(callback);
        callback({ ...this.currentPose });
        return () => {
            this.subscribers.delete(callback);
        };
    }

    public getCurrentPose(): ARCorePose {
        return {
            position: { ...this.currentPose.position },
            rotation: { ...this.currentPose.rotation },
            heading: this.currentPose.heading,
            timestamp: this.currentPose.timestamp,
            trackingState: this.currentPose.trackingState,
        };
    }

    public start(): void {
        if (this.isRunning) return;
        this.isRunning = true;
        this.currentPose.trackingState = 'TRACKING';
        this.lastFrameTime = performance.now ? performance.now() : Date.now();
        this.loop();
    }

    public stop(): void {
        this.isRunning = false;
        this.currentPose.trackingState = 'STOPPED';
        if (this.animationFrameId) {
            if (typeof cancelAnimationFrame !== 'undefined') {
                cancelAnimationFrame(this.animationFrameId);
            } else {
                clearTimeout(this.animationFrameId);
            }
            this.animationFrameId = null;
        }
    }

    public updateRelativeMotion(deltaX: number, deltaY: number, deltaZ: number, deltaHeading = 0): void {
        if (!this.isRunning) return;
        this.currentPose.position.x += deltaX;
        this.currentPose.position.y += deltaY;
        this.currentPose.position.z += deltaZ;
        this.currentPose.heading = (this.currentPose.heading + deltaHeading + 360) % 360;
        this.currentPose.timestamp = Date.now();
        this.notifySubscribers();
    }

    private loop = (): void => {
        if (!this.isRunning) return;

        const now = performance.now ? performance.now() : Date.now();
        this.lastFrameTime = now;

        // Continuous high frequency local 6DoF tracking ping
        this.currentPose.timestamp = Date.now();
        this.notifySubscribers();

        if (typeof requestAnimationFrame !== 'undefined') {
            this.animationFrameId = requestAnimationFrame(this.loop);
        } else {
            this.animationFrameId = setTimeout(this.loop, 16);
        }
    };

    private notifySubscribers(): void {
        const poseCopy = this.getCurrentPose();
        for (const sub of this.subscribers) {
            sub(poseCopy);
        }
    }
}
