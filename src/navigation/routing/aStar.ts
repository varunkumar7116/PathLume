import { NavigationGraph } from '../graph/navigationGraph';
import { NavNode, Vector3D } from '../graph/nodes';

export interface AStarResult {
    success: boolean;
    path: NavNode[];
    totalDistance: number;
    nodesExplored: number;
}

export function euclideanHeuristic(p1: Vector3D, p2: Vector3D): number {
    return Math.hypot(p1.x - p2.x, p1.y - p2.y, p1.z - p2.z);
}

/**
 * A* Pathfinding Algorithm over NavigationGraph.
 */
export function findAStarPath(
    graph: NavigationGraph,
    startInput: NavNode | string,
    destInput: NavNode | string
): AStarResult {
    const startNode = typeof startInput === 'string' ? graph.getNode(startInput) : startInput;
    const destNode = typeof destInput === 'string' ? graph.getNode(destInput) : destInput;

    if (!startNode || !destNode) {
        return { success: false, path: [], totalDistance: 0, nodesExplored: 0 };
    }

    if (startNode.id === destNode.id) {
        return { success: true, path: [startNode], totalDistance: 0, nodesExplored: 1 };
    }

    const openSet: Set<string> = new Set([startNode.id]);
    const cameFrom: Map<string, string> = new Map();

    const gScore: Map<string, number> = new Map();
    const hScore: Map<string, number> = new Map();
    const fScore: Map<string, number> = new Map();

    gScore.set(startNode.id, 0);
    const startH = euclideanHeuristic(startNode.position, destNode.position);
    hScore.set(startNode.id, startH);
    fScore.set(startNode.id, startH);

    let nodesExplored = 0;

    while (openSet.size > 0) {
        // Find node in openSet with lowest fScore
        let currentId: string | null = null;
        let lowestF = Infinity;

        for (const nodeId of openSet) {
            const f = fScore.get(nodeId) ?? Infinity;
            if (f < lowestF) {
                lowestF = f;
                currentId = nodeId;
            }
        }

        if (!currentId) break;

        nodesExplored++;

        if (currentId === destNode.id) {
            // Reconstruct path
            const path: NavNode[] = [];
            let curr: string | undefined = currentId;
            while (curr) {
                const node = graph.getNode(curr);
                if (node) path.unshift(node);
                curr = cameFrom.get(curr);
            }

            const totalDistance = gScore.get(destNode.id) ?? 0;
            return {
                success: true,
                path,
                totalDistance,
                nodesExplored,
            };
        }

        openSet.delete(currentId);
        const currentG = gScore.get(currentId) ?? Infinity;

        const neighbors = graph.getNeighbors(currentId);

        for (const neighborInfo of neighbors) {
            const neighbor = neighborInfo.node;
            const tentativeG = currentG + neighborInfo.distance;

            if (tentativeG < (gScore.get(neighbor.id) ?? Infinity)) {
                cameFrom.set(neighbor.id, currentId);
                gScore.set(neighbor.id, tentativeG);
                
                const h = euclideanHeuristic(neighbor.position, destNode.position);
                hScore.set(neighbor.id, h);
                fScore.set(neighbor.id, tentativeG + h);

                if (!openSet.has(neighbor.id)) {
                    openSet.add(neighbor.id);
                }
            }
        }
    }

    return {
        success: false,
        path: [],
        totalDistance: 0,
        nodesExplored,
    };
}
