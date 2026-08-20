import { NavigationGraph } from './graph/navigationGraph';
import { NavNode } from './graph/nodes';
import { PositionProvider } from './positioning/positionProvider';
import { DEFAULT_USER_POSITION, UserPositionState } from './positioning/userPosition';
import { findAStarPath } from './routing/aStar';
import {
    calculateDistanceRemaining,
    checkArrival,
    checkOffRoute,
} from './routing/routeUtils';

export type NavigationStatus = 'idle' | 'navigating' | 'off-route' | 'arrived';

export interface NavigationState {
    status: NavigationStatus;
    userPosition: UserPositionState;
    startNode: NavNode | null;
    destinationNode: NavNode | null;
    route: NavNode[];
    distanceRemaining: number;
    currentFloor: number;
}

export type NavigationStateCallback = (state: NavigationState) => void;

export class NavigationEngine {
    private graph: NavigationGraph;
    private positionProvider: PositionProvider | null = null;
    private stateListeners: Set<NavigationStateCallback> = new Set();
    private positionUnsubscribe: (() => void) | null = null;

    private state: NavigationState = {
        status: 'idle',
        userPosition: DEFAULT_USER_POSITION,
        startNode: null,
        destinationNode: null,
        route: [],
        distanceRemaining: 0,
        currentFloor: 1,
    };

    private arrivalThresholdMeters = 1.5;
    private offRouteThresholdMeters = 2.5;

    constructor(graph: NavigationGraph) {
        this.graph = graph;
    }

    public getGraph(): NavigationGraph {
        return this.graph;
    }

    public getState(): NavigationState {
        return { ...this.state };
    }

    public onStateChange(callback: NavigationStateCallback): () => void {
        this.stateListeners.add(callback);
        callback(this.getState());
        return () => {
            this.stateListeners.delete(callback);
        };
    }

    public setPositionProvider(provider: PositionProvider): void {
        if (this.positionUnsubscribe) {
            this.positionUnsubscribe();
        }
        this.positionProvider = provider;
        this.positionUnsubscribe = provider.onPositionUpdate((pos) => {
            this.updateUserPosition(pos);
        });
    }

    public getPositionProvider(): PositionProvider | null {
        return this.positionProvider;
    }

    public setStartNode(nodeOrId: NavNode | string | null): void {
        const node = typeof nodeOrId === 'string' ? this.graph.getNode(nodeOrId) ?? null : nodeOrId;
        this.state.startNode = node;
        if (node) {
            this.state.userPosition = {
                position: { ...node.position },
                floor: node.floor,
                heading: this.state.userPosition.heading,
                accuracy: 1.0,
            };
        }
        this.recalculateRouteIfPossible();
    }

    public setDestinationNode(nodeOrId: NavNode | string | null): void {
        const node = typeof nodeOrId === 'string' ? this.graph.getNode(nodeOrId) ?? null : nodeOrId;
        this.state.destinationNode = node;
        this.recalculateRouteIfPossible();
    }

    public updateUserPosition(userPos: UserPositionState): void {
        this.state.userPosition = userPos;
        this.state.currentFloor = userPos.floor;

        if (this.state.status === 'idle' || !this.state.destinationNode) {
            this.notifyListeners();
            return;
        }

        const destPos = this.state.destinationNode.position;

        // 1. Check Arrival
        if (checkArrival(userPos.position, destPos, this.arrivalThresholdMeters)) {
            this.state.status = 'arrived';
            this.state.distanceRemaining = 0;
            this.notifyListeners();
            return;
        }

        // 2. Check Off-Route & Reroute if needed
        if (this.state.route.length > 0 && checkOffRoute(userPos.position, this.state.route, this.offRouteThresholdMeters)) {
            this.state.status = 'off-route';
            this.notifyListeners();

            // Perform automatic rerouting from nearest node to user
            this.rerouteFromUserPosition();
            return;
        }

        // 3. Update remaining distance along route
        if (this.state.route.length > 0) {
            this.state.distanceRemaining = Math.round(
                calculateDistanceRemaining(userPos.position, this.state.route) * 10
            ) / 10;
        }

        this.notifyListeners();
    }

    public recalculateRouteIfPossible(): void {
        if (!this.state.destinationNode) {
            this.state.status = 'idle';
            this.state.route = [];
            this.state.distanceRemaining = 0;
            this.notifyListeners();
            return;
        }

        let startNode = this.state.startNode;
        if (!startNode) {
            // Find nearest node to current user position
            startNode = this.graph.findNearestNode(this.state.userPosition.position, this.state.currentFloor);
            this.state.startNode = startNode;
        }

        if (!startNode) {
            this.state.status = 'idle';
            this.state.route = [];
            this.state.distanceRemaining = 0;
            this.notifyListeners();
            return;
        }

        const result = findAStarPath(this.graph, startNode, this.state.destinationNode);

        if (result.success && result.path.length > 0) {
            this.state.route = result.path;
            this.state.status = 'navigating';
            this.state.distanceRemaining = Math.round(
                calculateDistanceRemaining(this.state.userPosition.position, result.path) * 10
            ) / 10;
        } else {
            this.state.route = [];
            this.state.status = 'idle';
            this.state.distanceRemaining = 0;
        }

        this.notifyListeners();
    }

    public rerouteFromUserPosition(): void {
        if (!this.state.destinationNode) return;

        const nearestNode = this.graph.findNearestNode(
            this.state.userPosition.position,
            this.state.currentFloor
        );

        if (!nearestNode) return;

        const result = findAStarPath(this.graph, nearestNode, this.state.destinationNode);

        if (result.success && result.path.length > 0) {
            // Prepend virtual position step if not already at nearest node
            const fullRoute = [
                {
                    id: 'user_temp_position',
                    name: 'Current Location',
                    type: 'corridor' as const,
                    floor: this.state.userPosition.floor,
                    position: { ...this.state.userPosition.position },
                },
                ...result.path,
            ];

            this.state.startNode = nearestNode;
            this.state.route = fullRoute;
            this.state.status = 'navigating';
            this.state.distanceRemaining = Math.round(
                calculateDistanceRemaining(this.state.userPosition.position, fullRoute) * 10
            ) / 10;
            this.notifyListeners();
        }
    }

    public clear(): void {
        this.state.status = 'idle';
        this.state.startNode = null;
        this.state.destinationNode = null;
        this.state.route = [];
        this.state.distanceRemaining = 0;
        this.notifyListeners();
    }

    private notifyListeners(): void {
        const stateCopy = this.getState();
        for (const listener of this.stateListeners) {
            listener(stateCopy);
        }
    }
}
