import { NavNode, Vector3D } from '../graph/nodes';
import { PositionCallback, PositionProvider } from './positionProvider';
import { DEFAULT_USER_POSITION, UserPositionState } from './userPosition';

export class MockPositionProvider implements PositionProvider {
    private currentPosition: UserPositionState;
    private subscribers: Set<PositionCallback> = new Set();
    private activeRoute: NavNode[] = [];
    private routeIndex = 0;
    private segmentProgress = 0; // 0..1 along current segment
    private speedMetersPerSec = 1.2; // Walking speed
    private isRunning = false;
    private timerId: ReturnType<typeof setInterval> | null = null;
    private updateIntervalMs = 50; // 20 updates/sec

    constructor(initialPosition: UserPositionState = DEFAULT_USER_POSITION) {
        this.currentPosition = { ...initialPosition };
    }

    public onPositionUpdate(callback: PositionCallback): () => void {
        this.subscribers.add(callback);
        // Immediately notify subscriber with current state
        callback(this.currentPosition);
        return () => {
            this.subscribers.delete(callback);
        };
    }

    public getCurrentPosition(): UserPositionState {
        return { ...this.currentPosition };
    }

    public setSpeed(speedMetersPerSec: number): void {
        this.speedMetersPerSec = Math.max(0.1, speedMetersPerSec);
    }

    public setRoute(route: NavNode[]): void {
        this.activeRoute = route;
        this.routeIndex = 0;
        this.segmentProgress = 0;
        if (route.length > 0) {
            const first = route[0];
            this.updatePosition({
                position: { ...first.position },
                floor: first.floor,
                heading: this.currentPosition.heading,
                accuracy: 1.0,
            });
        }
    }

    public setCustomPosition(position: Vector3D, floor = 1, heading = 0): void {
        this.updatePosition({
            position: { ...position },
            floor,
            heading,
            accuracy: 1.0,
        });
    }

    public simulateOffRoute(offsetMeters = 4.0): void {
        // Shift position orthogonally to force off-route detection
        const curr = this.currentPosition.position;
        const offsetPosition: Vector3D = {
            x: curr.x + offsetMeters,
            y: curr.y,
            z: curr.z + offsetMeters,
        };
        this.updatePosition({
            ...this.currentPosition,
            position: offsetPosition,
            accuracy: 2.5,
        });
    }

    public start(): void {
        if (this.isRunning) return;
        this.isRunning = true;
        this.timerId = setInterval(() => this.tick(), this.updateIntervalMs);
    }

    public stop(): void {
        this.isRunning = false;
        if (this.timerId) {
            clearInterval(this.timerId);
            this.timerId = null;
        }
    }

    public reset(): void {
        this.stop();
        this.routeIndex = 0;
        this.segmentProgress = 0;
        if (this.activeRoute.length > 0) {
            const startNode = this.activeRoute[0];
            this.setCustomPosition(startNode.position, startNode.floor, 0);
        }
    }

    private tick(): void {
        if (!this.isRunning || this.activeRoute.length < 2) return;
        if (this.routeIndex >= this.activeRoute.length - 1) {
            return; // Reached end of route
        }

        const pA = this.activeRoute[this.routeIndex].position;
        const pB = this.activeRoute[this.routeIndex + 1].position;
        const segDistance = Math.hypot(pB.x - pA.x, pB.y - pA.y, pB.z - pA.z);

        if (segDistance === 0) {
            this.routeIndex++;
            return;
        }

        const distancePerTick = this.speedMetersPerSec * (this.updateIntervalMs / 1000);
        const progressIncrement = distancePerTick / segDistance;

        this.segmentProgress += progressIncrement;

        if (this.segmentProgress >= 1.0) {
            this.segmentProgress = 0;
            this.routeIndex++;
            if (this.routeIndex >= this.activeRoute.length - 1) {
                // Reached final node
                const lastNode = this.activeRoute[this.activeRoute.length - 1];
                this.updatePosition({
                    position: { ...lastNode.position },
                    floor: lastNode.floor,
                    heading: this.currentPosition.heading,
                    accuracy: 0.5,
                });
                return;
            }
        }

        // Interpolate current position along active segment
        const currA = this.activeRoute[this.routeIndex].position;
        const currB = this.activeRoute[this.routeIndex + 1].position;

        const x = currA.x + (currB.x - currA.x) * this.segmentProgress;
        const y = currA.y + (currB.y - currA.y) * this.segmentProgress;
        const z = currA.z + (currB.z - currA.z) * this.segmentProgress;

        // Calculate heading in degrees (Y-axis rotation angle in 3D scene)
        const dx = currB.x - currA.x;
        const dz = currB.z - currA.z;
        let headingDeg = (Math.atan2(dx, dz) * 180) / Math.PI;
        if (headingDeg < 0) headingDeg += 360;

        this.updatePosition({
            position: { x, y, z },
            floor: this.activeRoute[this.routeIndex].floor,
            heading: headingDeg,
            accuracy: 1.0,
        });
    }

    private updatePosition(newPos: UserPositionState): void {
        this.currentPosition = newPos;
        for (const sub of this.subscribers) {
            sub(newPos);
        }
    }
}
