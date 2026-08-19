import * as THREE from 'three';
import { Line2 } from 'three/examples/jsm/lines/Line2.js';
import { LineGeometry } from 'three/examples/jsm/lines/LineGeometry.js';
import { LineMaterial } from 'three/examples/jsm/lines/LineMaterial.js';
import { NavNode } from '../graph/nodes';

export class RouteVisualizer {
    private scene: THREE.Scene;
    private containerGroup: THREE.Group;
    private pathLine: Line2 | null = null;
    private waypointMeshes: THREE.Mesh[] = [];

    constructor(scene: THREE.Scene) {
        this.scene = scene;
        this.containerGroup = new THREE.Group();
        this.containerGroup.name = 'NavigationRouteGroup';
        this.scene.add(this.containerGroup);
    }

    public updateRoute(routeNodes: NavNode[], yOffset = 0.15): void {
        this.clear();

        if (!routeNodes || routeNodes.length < 2) return;

        const positions: number[] = [];

        for (let i = 0; i < routeNodes.length; i++) {
            const pos = routeNodes[i].position;
            const y = pos.y + yOffset;
            positions.push(pos.x, y, pos.z);

            // Add waypoint sphere markers at nodes
            const isStart = i === 0;
            const isEnd = i === routeNodes.length - 1;
            const color = isStart ? 0x38bdf8 : isEnd ? 0x4ade80 : 0xfbbf24;

            const sphereGeom = new THREE.SphereGeometry(0.18, 16, 16);
            const sphereMat = new THREE.MeshBasicMaterial({ color });
            const sphere = new THREE.Mesh(sphereGeom, sphereMat);
            sphere.position.set(pos.x, y, pos.z);

            this.containerGroup.add(sphere);
            this.waypointMeshes.push(sphere);
        }

        // Create 3D Thick Path Line
        const lineGeometry = new LineGeometry();
        lineGeometry.setPositions(positions);

        const lineMaterial = new LineMaterial({
            color: 0x00e5ff, // Vibrant AR Cyan
            linewidth: 8, // line width in pixels
            resolution: new THREE.Vector2(window.innerWidth, window.innerHeight),
        });

        this.pathLine = new Line2(lineGeometry, lineMaterial);
        this.containerGroup.add(this.pathLine);
    }

    public clear(): void {
        if (this.pathLine) {
            this.containerGroup.remove(this.pathLine);
            this.pathLine.geometry.dispose();
            (this.pathLine.material as THREE.Material).dispose();
            this.pathLine = null;
        }

        for (const mesh of this.waypointMeshes) {
            this.containerGroup.remove(mesh);
            mesh.geometry.dispose();
            (mesh.material as THREE.Material).dispose();
        }
        this.waypointMeshes = [];
    }

    public dispose(): void {
        this.clear();
        this.scene.remove(this.containerGroup);
    }
}
