import * as THREE from 'three';
import { UserPositionState } from '../positioning/userPosition';

export class UserMarker {
    private scene: THREE.Scene;
    public markerGroup: THREE.Group;
    private coneMesh: THREE.Mesh;
    private ringMesh: THREE.Mesh;
    private targetPosition: THREE.Vector3 = new THREE.Vector3();
    private targetHeading = 0; // degrees

    constructor(scene: THREE.Scene) {
        this.scene = scene;
        this.markerGroup = new THREE.Group();
        this.markerGroup.name = 'UserPositionMarker';

        // 3D Directional Cone Arrow Pointer
        const coneGeom = new THREE.ConeGeometry(0.3, 0.7, 16);
        coneGeom.rotateX(Math.PI / 2); // Point forward along Z axis
        const coneMat = new THREE.MeshStandardMaterial({
            color: 0x0284c7, // AR Cyan/Blue
            emissive: 0x0369a1,
            metalness: 0.2,
            roughness: 0.3,
        });
        this.coneMesh = new THREE.Mesh(coneGeom, coneMat);
        this.coneMesh.position.set(0, 0.4, 0);

        // Accuracy Ring Disk
        const ringGeom = new THREE.RingGeometry(0.6, 0.8, 32);
        ringGeom.rotateX(-Math.PI / 2);
        const ringMat = new THREE.MeshBasicMaterial({
            color: 0x38bdf8,
            side: THREE.DoubleSide,
            transparent: true,
            opacity: 0.5,
        });
        this.ringMesh = new THREE.Mesh(ringGeom, ringMat);
        this.ringMesh.position.set(0, 0.05, 0);

        this.markerGroup.add(this.coneMesh);
        this.markerGroup.add(this.ringMesh);
        this.scene.add(this.markerGroup);
    }

    public setPosition(userPos: UserPositionState): void {
        this.targetPosition.set(userPos.position.x, userPos.position.y, userPos.position.z);
        this.targetHeading = userPos.heading;
        this.markerGroup.position.copy(this.targetPosition);
        this.markerGroup.rotation.y = (userPos.heading * Math.PI) / 180;

        // Scale accuracy ring based on accuracy meters
        const scale = Math.max(0.5, userPos.accuracy);
        this.ringMesh.scale.set(scale, scale, scale);
    }

    public update(deltaTime = 0.016): void {
        // Smooth lerp interpolation for marker movement
        this.markerGroup.position.lerp(this.targetPosition, 0.15);

        // Smooth rotation lerp
        const targetRad = (this.targetHeading * Math.PI) / 180;
        this.markerGroup.rotation.y += (targetRad - this.markerGroup.rotation.y) * 0.15;
    }

    public setVisible(visible: boolean): void {
        this.markerGroup.visible = visible;
    }

    public dispose(): void {
        this.scene.remove(this.markerGroup);
        this.coneMesh.geometry.dispose();
        (this.coneMesh.material as THREE.Material).dispose();
        this.ringMesh.geometry.dispose();
        (this.ringMesh.material as THREE.Material).dispose();
    }
}
