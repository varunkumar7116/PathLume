import * as THREE from 'three';
import { NavigationGraph } from '../graph/navigationGraph';

export class DebugVisualizer {
    private scene: THREE.Scene;
    private debugGroup: THREE.Group;
    private isEnabled = false;

    constructor(scene: THREE.Scene) {
        this.scene = scene;
        this.debugGroup = new THREE.Group();
        this.debugGroup.name = 'NavigationDebugOverlay';
        this.debugGroup.visible = false;
        this.scene.add(this.debugGroup);
    }

    public setEnabled(enabled: boolean): void {
        this.isEnabled = enabled;
        this.debugGroup.visible = enabled;
    }

    public toggle(): boolean {
        this.setEnabled(!this.isEnabled);
        return this.isEnabled;
    }

    public renderGraph(graph: NavigationGraph): void {
        this.clear();

        const nodes = graph.getAllNodes();
        const edges = graph.getAllEdges();

        // 1. Render Edges (Lines)
        const linePositions: number[] = [];
        for (const edge of edges) {
            const n1 = graph.getNode(edge.from);
            const n2 = graph.getNode(edge.to);
            if (n1 && n2) {
                linePositions.push(n1.position.x, n1.position.y + 0.08, n1.position.z);
                linePositions.push(n2.position.x, n2.position.y + 0.08, n2.position.z);
            }
        }

        if (linePositions.length > 0) {
            const lineGeom = new THREE.BufferGeometry();
            lineGeom.setAttribute('position', new THREE.Float32BufferAttribute(linePositions, 3));
            const lineMat = new THREE.LineBasicMaterial({
                color: 0x94a3b8, // Slate gray
                linewidth: 2,
                transparent: true,
                opacity: 0.6,
            });
            const edgeLines = new THREE.LineSegments(lineGeom, lineMat);
            this.debugGroup.add(edgeLines);
        }

        // 2. Render Nodes (Spheres)
        const sphereGeom = new THREE.SphereGeometry(0.2, 12, 12);

        for (const node of nodes) {
            let color = 0x38bdf8; // default corridor cyan
            if (node.type === 'entrance') color = 0x4ade80; // green
            if (node.type === 'room') color = 0xf43f5e; // red/pink
            if (node.type === 'stairs' || node.type === 'elevator') color = 0xa855f7; // purple

            const mat = new THREE.MeshStandardMaterial({
                color,
                emissive: color,
                emissiveIntensity: 0.3,
            });
            const mesh = new THREE.Mesh(sphereGeom, mat);
            mesh.position.set(node.position.x, node.position.y + 0.1, node.position.z);
            this.debugGroup.add(mesh);
        }
    }

    public clear(): void {
        while (this.debugGroup.children.length > 0) {
            const child = this.debugGroup.children[0];
            this.debugGroup.remove(child);
            if ('geometry' in child) (child as THREE.Mesh).geometry.dispose();
            if ('material' in child) {
                const mat = (child as THREE.Mesh).material;
                if (Array.isArray(mat)) mat.forEach((m) => m.dispose());
                else mat.dispose();
            }
        }
    }

    public dispose(): void {
        this.clear();
        this.scene.remove(this.debugGroup);
    }
}
