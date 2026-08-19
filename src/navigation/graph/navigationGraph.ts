import { NavNode, Vector3D, SAMPLE_NODES } from './nodes';
import { NavEdge, SAMPLE_EDGES } from './edges';

export interface NeighborInfo {
    node: NavNode;
    distance: number;
    edge: NavEdge;
}

export class NavigationGraph {
    private nodes: Map<string, NavNode> = new Map();
    private adjacency: Map<string, NeighborInfo[]> = new Map();
    private rawEdges: NavEdge[] = [];

    constructor(initialNodes: NavNode[] = SAMPLE_NODES, initialEdges: NavEdge[] = SAMPLE_EDGES) {
        this.loadGraph(initialNodes, initialEdges);
    }

    public clear(): void {
        this.nodes.clear();
        this.adjacency.clear();
        this.rawEdges = [];
    }

    public loadGraph(nodes: NavNode[], edges: NavEdge[]): void {
        this.clear();
        for (const node of nodes) {
            this.addNode(node);
        }
        for (const edge of edges) {
            this.addEdge(edge);
        }
    }

    public addNode(node: NavNode): void {
        this.nodes.set(node.id, node);
        if (!this.adjacency.has(node.id)) {
            this.adjacency.set(node.id, []);
        }
    }

    public addEdge(edge: NavEdge): void {
        const fromNode = this.nodes.get(edge.from);
        const toNode = this.nodes.get(edge.to);

        if (!fromNode || !toNode) {
            console.warn(`Cannot add edge: node '${edge.from}' or '${edge.to}' does not exist.`);
            return;
        }

        if (edge.walkable === false) {
            return;
        }

        const distance = edge.distance ?? this.calculateDistance(fromNode.position, toNode.position);
        const resolvedEdge: NavEdge = { ...edge, distance };
        this.rawEdges.push(resolvedEdge);

        this.addAdjacencyEntry(fromNode.id, toNode, distance, resolvedEdge);

        if (edge.bidirectional !== false) {
            this.addAdjacencyEntry(toNode.id, fromNode, distance, resolvedEdge);
        }
    }

    private addAdjacencyEntry(fromId: string, toNode: NavNode, distance: number, edge: NavEdge): void {
        const neighbors = this.adjacency.get(fromId) ?? [];
        neighbors.push({ node: toNode, distance, edge });
        this.adjacency.set(fromId, neighbors);
    }

    public getNode(id: string): NavNode | undefined {
        return this.nodes.get(id);
    }

    public getAllNodes(): NavNode[] {
        return Array.from(this.nodes.values());
    }

    public getAllEdges(): NavEdge[] {
        return [...this.rawEdges];
    }

    public getNeighbors(id: string): NeighborInfo[] {
        return this.adjacency.get(id) ?? [];
    }

    public findNearestNode(position: Vector3D, floor?: number): NavNode | null {
        let nearest: NavNode | null = null;
        let minDistance = Infinity;

        for (const node of this.nodes.values()) {
            if (floor !== undefined && node.floor !== floor) {
                continue;
            }

            const dist = this.calculateDistance(position, node.position);
            if (dist < minDistance) {
                minDistance = dist;
                nearest = node;
            }
        }

        return nearest;
    }

    public calculateDistance(p1: Vector3D, p2: Vector3D): number {
        const dx = p1.x - p2.x;
        const dy = p1.y - p2.y;
        const dz = p1.z - p2.z;
        return Math.hypot(dx, dy, dz);
    }
}
