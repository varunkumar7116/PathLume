import { PositionCallback, PositionProvider, ProviderStatusCallback } from './positionProvider';
import { DEFAULT_USER_POSITION, UserPositionState } from './userPosition';

export class MobilePositionProvider implements PositionProvider {
    private currentPosition: UserPositionState = DEFAULT_USER_POSITION;
    private positionSubscribers: Set<PositionCallback> = new Set();
    private statusSubscribers: Set<ProviderStatusCallback> = new Set();
    private isRunning = false;
    private deviceOrientationListener: ((event: DeviceOrientationEvent) => void) | null = null;

    public onPositionUpdate(callback: PositionCallback): () => void {
        this.positionSubscribers.add(callback);
        callback(this.currentPosition);
        return () => {
            this.positionSubscribers.delete(callback);
        };
    }

    public onStatusUpdate(callback: ProviderStatusCallback): () => void {
        this.statusSubscribers.add(callback);
        return () => {
            this.statusSubscribers.delete(callback);
        };
    }

    public getCurrentPosition(): UserPositionState {
        return { ...this.currentPosition };
    }

    public start(): void {
        if (this.isRunning) return;
        this.isRunning = true;

        if (typeof window !== 'undefined' && 'DeviceOrientationEvent' in window) {
            this.deviceOrientationListener = (event: DeviceOrientationEvent) => {
                // Read compass heading if available
                const heading = event.alpha ?? 0;
                this.updateHeading(heading);
            };
            window.addEventListener('deviceorientation', this.deviceOrientationListener, true);
        }
    }

    public stop(): void {
        this.isRunning = false;
        if (this.deviceOrientationListener && typeof window !== 'undefined') {
            window.removeEventListener('deviceorientation', this.deviceOrientationListener, true);
            this.deviceOrientationListener = null;
        }
    }

    public setPosition(pos: UserPositionState): void {
        this.currentPosition = { ...pos };
        this.notifySubscribers();
    }

    private updateHeading(heading: number): void {
        this.currentPosition.heading = Math.round(heading);
        this.notifySubscribers();
    }

    private notifySubscribers(): void {
        for (const sub of this.positionSubscribers) {
            sub(this.currentPosition);
        }
    }
}
