import * as THREE from 'three';
import { VPSPose } from './vpsTypes';

export class WorldAnchorManager {
    private scene: THREE.Scene;
    private camera: THREE.PerspectiveCamera;
    private worldGroup: THREE.Group;
    private originPose: VPSPose | null = null;

    constructor(scene: THREE.Scene, camera: THREE.PerspectiveCamera) {
        this.scene = scene;
        this.camera = camera;
        this.worldGroup = new THREE.Group();
        this.worldGroup.name = 'ARWorldAnchorGroup';
        this.scene.add(this.worldGroup);
    }

    public getWorldGroup(): THREE.Group {
        return this.worldGroup;
    }

    public setOrigin(pose: VPSPose): void {
        this.originPose = { ...pose };
        this.worldGroup.position.set(pose.position.x, pose.position.y, pose.position.z);
        this.worldGroup.rotation.y = (pose.heading * Math.PI) / 180;
    }

    public applyVPSPose(pose: VPSPose): void {
        if (!this.originPose) {
            this.setOrigin(pose);
            return;
        }

        // Align camera / scene reference frame to live VPS pose
        const radY = (pose.heading * Math.PI) / 180;
        this.camera.position.set(pose.position.x, pose.position.y + 1.6, pose.position.z); // 1.6m eye level
        this.camera.rotation.set(0, radY, 0);
    }
}
