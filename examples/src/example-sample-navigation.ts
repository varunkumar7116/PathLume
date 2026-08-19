import GUI from 'lil-gui';
import type { Vec3 } from 'mathcat';
import {
    createFindNearestPolyResult,
    DEFAULT_QUERY_FILTER,
    FindStraightPathResultFlags,
    findNearestPoly,
    findPath,
} from 'navcat';
import { generateSoloNavMesh, type SoloNavMeshInput, type SoloNavMeshOptions } from 'navcat/blocks';
import {
    createNavMeshHelper,
    createNavMeshPolyHelper,
    createSearchNodesHelper,
    getPositionsAndIndices,
    type DebugObject,
} from 'navcat/three';
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/Addons.js';
import { LineGeometry } from 'three/examples/jsm/lines/LineGeometry.js';
import { Line2 } from 'three/examples/jsm/lines/Line2.js';
import { LineMaterial } from 'three/examples/jsm/lines/LineMaterial.js';
import { createExample } from './common/example-base';
import { loadGLTF } from './common/load-gltf';
import { createFlag } from './common/flag';
import {
    NavigationGraph,
    NavigationEngine,
    MockPositionProvider,
    RouteVisualizer,
    UserMarker,
    DebugVisualizer,
    SAMPLE_NODES,
    SAMPLE_EDGES,
} from '../../src/navigation';

/* Define global test output object for automated inspection */
(window as any).__NAVCAT_TEST_RESULTS__ = {
    modelUrl: './models/sample1.glb',
    loaded: false,
    meshCount: 0,
    vertexCount: 0,
    triangleCount: 0,
    upwardTriangles: 0,
    downwardTriangles: 0,
    verticalTriangles: 0,
    boundingBox: { min: [0, 0, 0], max: [0, 0, 0], size: [0, 0, 0] },
    stageDiagnostics: {
        walkableTrianglesMarked: 0,
        heightfieldSpans: 0,
        compactSpans: 0,
        contourCount: 0,
        polyMeshPolys: 0,
    },
    navMeshGenerated: false,
    navMeshPolyCount: 0,
    generationTimeMs: 0,
    startRaw: null as Vec3 | null,
    startSnapped: null as Vec3 | null,
    startPolyId: null as number | null,
    destRaw: null as Vec3 | null,
    destSnapped: null as Vec3 | null,
    destPolyId: null as number | null,
    findNearestPolyWorked: false,
    findPathWorked: false,
    pathDistance: 0,
    pathPointsCount: 0,
    errors: [] as string[],
};

const testResults = (window as any).__NAVCAT_TEST_RESULTS__;

/* Setup example 3D scene */
const container = document.getElementById('root')!;
const { scene, camera, renderer } = await createExample(container);

camera.position.set(0, 15, 25);

const orbitControls = new OrbitControls(camera, renderer.domElement);
orbitControls.enableDamping = true;

// Grid helper
const gridHelper = new THREE.GridHelper(50, 50, 0x444444, 0x222222);
scene.add(gridHelper);

/* State management */
let modelGroup: THREE.Group | null = null;
let walkableMeshes: THREE.Mesh[] = [];
let rawPositions: number[] = [];
let rawIndices: number[] = [];

let startPoint: Vec3 | null = null;
let destPoint: Vec3 | null = null;
let startSnappedPoint: Vec3 | null = null;
let destSnappedPoint: Vec3 | null = null;
let startPolyId: number | null = null;
let destPolyId: number | null = null;

let clickMode: 'start' | 'dest' | 'inspect' = 'inspect';

/* Visual elements tracking */
type Visual = { object: THREE.Object3D; dispose: () => void };
let pathVisuals: Visual[] = [];
let navMeshHelper: DebugObject | null = null;
let candidateTrianglesObject: THREE.Object3D | null = null;

function clearPathVisuals() {
    for (const visual of pathVisuals) {
        scene.remove(visual.object);
        visual.dispose();
    }
    pathVisuals = [];
}

function addPathVisual(visual: Visual) {
    pathVisuals.push(visual);
    scene.add(visual.object);
}

/* NavMesh Generation Configuration */
const config = {
    cellSize: 0.10,
    cellHeight: 0.08,
    walkableRadiusWorld: 0.08,
    walkableClimbWorld: 0.4,
    walkableHeightWorld: 1.0,
    walkableSlopeAngleDegrees: 60,
    borderSize: 0,
    minRegionArea: 1,
    mergeRegionArea: 4,
    maxSimplificationError: 1.3,
    maxEdgeLength: 12,
    maxVerticesPerPoly: 6,
    detailSampleDistance: 6,
    detailSampleMaxError: 1,
    usePhotogrammetryFilter: true,
};

const debugConfig = {
    showModel: true,
    showNavMesh: true,
    showCandidateTriangles: false,
    selectedModel: './models/sample1.glb',
};

/* Presets Definition */
function applyPreset(presetNum: number) {
    if (presetNum === 1) {
        // Preset 1: Default NavCat Settings
        config.cellSize = 0.15;
        config.cellHeight = 0.15;
        config.walkableRadiusWorld = 0.2;
        config.walkableClimbWorld = 0.4;
        config.walkableHeightWorld = 1.8;
        config.walkableSlopeAngleDegrees = 45;
        config.minRegionArea = 8;
        config.mergeRegionArea = 20;
        config.usePhotogrammetryFilter = false;
    } else if (presetNum === 2) {
        // Preset 2: Indoor Conservative
        config.cellSize = 0.10;
        config.cellHeight = 0.10;
        config.walkableRadiusWorld = 0.12;
        config.walkableClimbWorld = 0.3;
        config.walkableHeightWorld = 1.4;
        config.walkableSlopeAngleDegrees = 50;
        config.minRegionArea = 3;
        config.mergeRegionArea = 8;
        config.usePhotogrammetryFilter = true;
    } else if (presetNum === 3) {
        // Preset 3: Indoor Photogrammetry / Permissive
        config.cellSize = 0.10;
        config.cellHeight = 0.08;
        config.walkableRadiusWorld = 0.08;
        config.walkableClimbWorld = 0.4;
        config.walkableHeightWorld = 1.0;
        config.walkableSlopeAngleDegrees = 60;
        config.minRegionArea = 1;
        config.mergeRegionArea = 4;
        config.usePhotogrammetryFilter = true;
    }
    gui.controllersRecursive().forEach((c) => c.updateDisplay());
    generateNavMesh();
    runAutoTest();
}

/* Load & Analyze GLB Model */
let navMeshResult: ReturnType<typeof generateSoloNavMesh> | null = null;

async function loadModel(url: string) {
    testResults.modelUrl = url;
    testResults.loaded = false;
    testResults.findNearestPolyWorked = false;
    testResults.findPathWorked = false;
    clearNavigation();

    if (modelGroup) {
        scene.remove(modelGroup);
        modelGroup = null;
    }
    walkableMeshes = [];

    if (navMeshHelper) {
        scene.remove(navMeshHelper.object);
        navMeshHelper.dispose();
        navMeshHelper = null;
    }
    if (candidateTrianglesObject) {
        scene.remove(candidateTrianglesObject);
        candidateTrianglesObject.geometry?.dispose?.();
        candidateTrianglesObject = null;
    }

    try {
        console.log(`Loading ${url}...`);
        const sampleGLTF = await loadGLTF(url);
        modelGroup = sampleGLTF.scene;
        scene.add(modelGroup);
        testResults.loaded = true;
        console.log(`Successfully loaded ${url}`);
    } catch (err: any) {
        console.error(`Failed to load ${url}:`, err);
        testResults.errors.push(`Failed to load GLB (${url}): ${err.message || err}`);
        return;
    }

    if (modelGroup) {
        let meshCount = 0;
        let vertexCount = 0;
        let triangleCount = 0;

        modelGroup.traverse((child) => {
            if (child instanceof THREE.Mesh) {
                meshCount++;
                walkableMeshes.push(child);

                const geometry = child.geometry;
                const posAttr = geometry.attributes.position;
                if (posAttr) {
                    vertexCount += posAttr.count;
                }

                const indexAttr = geometry.getIndex();
                if (indexAttr) {
                    triangleCount += indexAttr.count / 3;
                } else if (posAttr) {
                    triangleCount += posAttr.count / 3;
                }
            }
        });

        // Extract global positions and indices
        [rawPositions, rawIndices] = getPositionsAndIndices(walkableMeshes);

        // Analyze Normals
        let upTriangles = 0;
        let downTriangles = 0;
        let vertTriangles = 0;

        const cosSlopeThreshold = Math.cos((config.walkableSlopeAngleDegrees * Math.PI) / 180);

        for (let i = 0; i < rawIndices.length; i += 3) {
            const i0 = rawIndices[i] * 3;
            const i1 = rawIndices[i + 1] * 3;
            const i2 = rawIndices[i + 2] * 3;

            const ax = rawPositions[i0], ay = rawPositions[i0 + 1], az = rawPositions[i0 + 2];
            const bx = rawPositions[i1], by = rawPositions[i1 + 1], bz = rawPositions[i1 + 2];
            const cx = rawPositions[i2], cy = rawPositions[i2 + 1], cz = rawPositions[i2 + 2];

            // Edge vectors
            const e1x = bx - ax, e1y = by - ay, e1z = bz - az;
            const e2x = cx - ax, e2y = cy - ay, e2z = cz - az;

            // Cross product
            const nx = e1y * e2z - e1z * e2y;
            const ny = e1z * e2x - e1x * e2z;
            const nz = e1x * e2y - e1y * e2x;

            const len = Math.sqrt(nx * nx + ny * ny + nz * nz);
            if (len > 0) {
                const normY = ny / len;
                if (normY >= cosSlopeThreshold) {
                    upTriangles++;
                } else if (normY <= -cosSlopeThreshold) {
                    downTriangles++;
                } else {
                    vertTriangles++;
                }
            }
        }

        const bbox = new THREE.Box3().setFromObject(modelGroup);
        const size = new THREE.Vector3();
        bbox.getSize(size);

        testResults.meshCount = meshCount;
        testResults.vertexCount = vertexCount;
        testResults.triangleCount = Math.floor(triangleCount);
        testResults.upwardTriangles = upTriangles;
        testResults.downwardTriangles = downTriangles;
        testResults.verticalTriangles = vertTriangles;
        testResults.boundingBox = {
            min: [bbox.min.x, bbox.min.y, bbox.min.z],
            max: [bbox.max.x, bbox.max.y, bbox.max.z],
            size: [size.x, size.y, size.z],
        };

        // Center camera on model bounding box
        const center = new THREE.Vector3();
        bbox.getCenter(center);
        orbitControls.target.copy(center);
        camera.position.set(center.x, center.y + size.y * 1.5 + 5, center.z + size.z * 1.5 + 5);
        orbitControls.update();

        // Update UI Stats
        document.getElementById('stat-meshes')!.textContent = meshCount.toString();
        document.getElementById('stat-vertices')!.textContent = vertexCount.toLocaleString();
        document.getElementById('stat-triangles')!.textContent = Math.floor(triangleCount).toLocaleString();
        document.getElementById('stat-up-triangles')!.textContent = upTriangles.toLocaleString();
        document.getElementById('stat-down-triangles')!.textContent = downTriangles.toLocaleString();
        document.getElementById('stat-vertical-triangles')!.textContent = vertTriangles.toLocaleString();
        document.getElementById('stat-bbox')!.textContent = `${size.x.toFixed(2)} × ${size.y.toFixed(2)} × ${size.z.toFixed(2)}m`;
        // Align Navigation Graph node Y elevations to model floor level
        if (typeof navigationGraph !== 'undefined' && navigationGraph) {
            const floorY = bbox.min.y + 0.1;
            for (const node of navigationGraph.getAllNodes()) {
                node.position.y = floorY;
            }
            if (typeof debugVisualizer !== 'undefined' && debugVisualizer) {
                debugVisualizer.renderGraph(navigationGraph);
            }
        }
    }

    generateNavMesh();
    runAutoTest();
}

/* Update Candidate Floor Triangles Visualizer */
function updateCandidateTrianglesVisualizer() {
    if (candidateTrianglesObject) {
        scene.remove(candidateTrianglesObject);
        candidateTrianglesObject.geometry?.dispose?.();
        candidateTrianglesObject = null;
    }

    if (!debugConfig.showCandidateTriangles || !rawPositions.length) return;

    const cosSlopeThreshold = Math.cos((config.walkableSlopeAngleDegrees * Math.PI) / 180);
    const candidatePositions: number[] = [];

    const bbox = new THREE.Box3().setFromObject(modelGroup!);
    const floorMaxY = bbox.min.y + Math.max(1.8, (bbox.max.y - bbox.min.y) * 0.5);

    for (let i = 0; i < rawIndices.length; i += 3) {
        const i0 = rawIndices[i] * 3;
        const i1 = rawIndices[i + 1] * 3;
        const i2 = rawIndices[i + 2] * 3;

        const ax = rawPositions[i0], ay = rawPositions[i0 + 1], az = rawPositions[i0 + 2];
        const bx = rawPositions[i1], by = rawPositions[i1 + 1], bz = rawPositions[i1 + 2];
        const cx = rawPositions[i2], cy = rawPositions[i2 + 1], cz = rawPositions[i2 + 2];

        // Check normal
        const e1x = bx - ax, e1y = by - ay, e1z = bz - az;
        const e2x = cx - ax, e2y = cy - ay, e2z = cz - az;
        const nx = e1y * e2z - e1z * e2y;
        const ny = e1z * e2x - e1x * e2z;
        const nz = e1x * e2y - e1y * e2x;
        const len = Math.sqrt(nx * nx + ny * ny + nz * nz);

        if (len > 0 && (ny / len) >= cosSlopeThreshold) {
            const maxTriY = Math.max(ay, by, cy);
            if (!config.usePhotogrammetryFilter || maxTriY <= floorMaxY) {
                // Add triangle edges for line visualization
                candidatePositions.push(ax, ay + 0.04, az, bx, by + 0.04, bz);
                candidatePositions.push(bx, by + 0.04, bz, cx, cy + 0.04, cz);
                candidatePositions.push(cx, cy + 0.04, cz, ax, ay + 0.04, az);
            }
        }
    }

    if (candidatePositions.length > 0) {
        const geom = new THREE.BufferGeometry();
        geom.setAttribute('position', new THREE.Float32BufferAttribute(candidatePositions, 3));
        const mat = new THREE.LineBasicMaterial({ color: 0x00ffff, linewidth: 2 });
        candidateTrianglesObject = new THREE.LineSegments(geom, mat);
        scene.add(candidateTrianglesObject);
    }
}

/* Extract Geometry & Generate NavMesh */
function generateNavMesh() {
    if (walkableMeshes.length === 0) return;

    if (navMeshHelper) {
        scene.remove(navMeshHelper.object);
        navMeshHelper.dispose();
        navMeshHelper = null;
    }

    let finalPositions = rawPositions;
    let finalIndices = rawIndices;

    // Optional Photogrammetry Preprocessing Filter
    if (config.usePhotogrammetryFilter && modelGroup) {
        const bbox = new THREE.Box3().setFromObject(modelGroup);
        // Floor candidate height threshold
        const floorMaxY = bbox.min.y + Math.max(1.8, (bbox.max.y - bbox.min.y) * 0.45);
        const cosSlopeThreshold = Math.cos((config.walkableSlopeAngleDegrees * Math.PI) / 180);

        const filteredIndices: number[] = [];
        for (let i = 0; i < rawIndices.length; i += 3) {
            const i0 = rawIndices[i] * 3;
            const i1 = rawIndices[i + 1] * 3;
            const i2 = rawIndices[i + 2] * 3;

            const ax = rawPositions[i0], ay = rawPositions[i0 + 1], az = rawPositions[i0 + 2];
            const bx = rawPositions[i1], by = rawPositions[i1 + 1], bz = rawPositions[i1 + 2];
            const cx = rawPositions[i2], cy = rawPositions[i2 + 1], cz = rawPositions[i2 + 2];

            const e1x = bx - ax, e1y = by - ay, e1z = bz - az;
            const e2x = cx - ax, e2y = cy - ay, e2z = cz - az;
            const nx = e1y * e2z - e1z * e2y;
            const ny = e1z * e2x - e1x * e2z;
            const nz = e1x * e2y - e1y * e2x;
            const len = Math.sqrt(nx * nx + ny * ny + nz * nz);

            if (len > 0) {
                const normY = ny / len;
                const maxTriY = Math.max(ay, by, cy);
                if (normY >= (cosSlopeThreshold - 0.25) && maxTriY <= floorMaxY) {
                    filteredIndices.push(rawIndices[i], rawIndices[i + 1], rawIndices[i + 2]);
                }
            }
        }

        if (filteredIndices.length > 0) {
            finalIndices = filteredIndices;
        }
    }

    const navMeshInput: SoloNavMeshInput = {
        positions: finalPositions,
        indices: finalIndices,
    };

    const walkableRadiusVoxels = Math.ceil(config.walkableRadiusWorld / config.cellSize);
    const walkableClimbVoxels = Math.ceil(config.walkableClimbWorld / config.cellHeight);
    const walkableHeightVoxels = Math.ceil(config.walkableHeightWorld / config.cellHeight);

    const detailSampleDistance = config.detailSampleDistance < 0.9 ? 0 : config.cellSize * config.detailSampleDistance;
    const detailSampleMaxError = config.cellHeight * config.detailSampleMaxError;

    const navMeshConfig: SoloNavMeshOptions = {
        cellSize: config.cellSize,
        cellHeight: config.cellHeight,
        walkableRadiusWorld: config.walkableRadiusWorld,
        walkableRadiusVoxels,
        walkableClimbWorld: config.walkableClimbWorld,
        walkableClimbVoxels,
        walkableHeightWorld: config.walkableHeightWorld,
        walkableHeightVoxels,
        walkableSlopeAngleDegrees: config.walkableSlopeAngleDegrees,
        borderSize: config.borderSize,
        minRegionArea: config.minRegionArea,
        mergeRegionArea: config.mergeRegionArea,
        maxSimplificationError: config.maxSimplificationError,
        maxEdgeLength: config.maxEdgeLength,
        maxVerticesPerPoly: config.maxVerticesPerPoly,
        detailSampleDistance,
        detailSampleMaxError,
    };

    const startTime = performance.now();
    navMeshResult = generateSoloNavMesh(navMeshInput, navMeshConfig);
    const endTime = performance.now();
    const duration = endTime - startTime;

    testResults.navMeshGenerated = true;
    testResults.generationTimeMs = Math.round(duration);

    // Record Stage Diagnostics
    if (navMeshResult && navMeshResult.intermediates) {
        const inter = navMeshResult.intermediates;
        let walkableMarked = 0;
        for (let i = 0; i < inter.triAreaIds.length; i++) {
            if (inter.triAreaIds[i] !== 0) walkableMarked++;
        }

        testResults.stageDiagnostics = {
            walkableTrianglesMarked: walkableMarked,
            heightfieldSpans: inter.heightfield?.spans?.length || 0,
            compactSpans: inter.compactHeightfield?.spanCount || 0,
            contourCount: inter.contourSet?.contours?.length || 0,
            polyMeshPolys: inter.polyMesh?.nPolys || 0,
        };
        console.log('Stage Diagnostics:', testResults.stageDiagnostics);
    }

    // Count polygons in NavMesh correctly via Object.values
    let polyCount = 0;
    if (navMeshResult && navMeshResult.navMesh) {
        const tiles = navMeshResult.navMesh.tiles;
        for (const tile of Object.values(tiles)) {
            if (tile && tile.polys) {
                polyCount += tile.polys.length;
            }
        }
    }
    testResults.navMeshPolyCount = polyCount;

    const statNavGenEl = document.getElementById('stat-nav-gen')!;
    const statPolysEl = document.getElementById('stat-polys')!;
    const statBuildTimeEl = document.getElementById('stat-build-time')!;

    if (polyCount > 0) {
        statNavGenEl.textContent = 'Yes (Valid NavMesh)';
        statNavGenEl.className = 'hud-value highlight';
        statPolysEl.textContent = polyCount.toString();
        statPolysEl.className = 'hud-value highlight';
    } else {
        statNavGenEl.textContent = 'Failed (0 Polygons)';
        statNavGenEl.className = 'hud-value danger';
        statPolysEl.textContent = '0';
        statPolysEl.className = 'hud-value danger';
    }
    statBuildTimeEl.textContent = `${duration.toFixed(1)} ms`;

    if (debugConfig.showNavMesh && navMeshResult && polyCount > 0) {
        navMeshHelper = createNavMeshHelper(navMeshResult.navMesh);
        navMeshHelper.object.position.y += 0.05; // Slight Y-offset to prevent z-fighting
        scene.add(navMeshHelper.object);
    }

    updateCandidateTrianglesVisualizer();
}

/* Preset Buttons Event Listeners */
document.getElementById('btn-preset-1')?.addEventListener('click', () => applyPreset(1));
document.getElementById('btn-preset-2')?.addEventListener('click', () => applyPreset(2));
document.getElementById('btn-preset-3')?.addEventListener('click', () => applyPreset(3));

/* Connect HTML Model Dropdown */
const selectModelEl = document.getElementById('select-model') as HTMLSelectElement;
if (selectModelEl) {
    selectModelEl.addEventListener('change', () => {
        debugConfig.selectedModel = selectModelEl.value;
        loadModel(selectModelEl.value);
    });
}

/* GUI Controls */
const gui = new GUI({ title: 'NavMesh Options' });
const modelFolder = gui.addFolder('Model & Debug');
modelFolder
    .add(debugConfig, 'selectedModel', { 'sample1.glb': './models/sample1.glb', 'sample.glb': './models/sample.glb' })
    .name('Model')
    .onChange((url: string) => {
        if (selectModelEl) selectModelEl.value = url;
        loadModel(url);
    });

modelFolder
    .add(debugConfig, 'showModel')
    .name('Show Model')
    .onChange((val: boolean) => {
        if (modelGroup) modelGroup.visible = val;
    });
modelFolder
    .add(debugConfig, 'showNavMesh')
    .name('Show NavMesh')
    .onChange((val: boolean) => {
        if (navMeshHelper) navMeshHelper.object.visible = val;
    });
modelFolder
    .add(debugConfig, 'showCandidateTriangles')
    .name('Show Candidate Triangles')
    .onChange(() => updateCandidateTrianglesVisualizer());

const navFolder = gui.addFolder('NavMesh Config');
navFolder.add(config, 'cellSize', 0.05, 0.5, 0.01).onChange(generateNavMesh);
navFolder.add(config, 'cellHeight', 0.05, 0.5, 0.01).onChange(generateNavMesh);
navFolder.add(config, 'walkableRadiusWorld', 0.01, 1.0, 0.01).onChange(generateNavMesh);
navFolder.add(config, 'walkableClimbWorld', 0.1, 1.0, 0.05).onChange(generateNavMesh);
navFolder.add(config, 'walkableHeightWorld', 0.5, 3.0, 0.1).onChange(generateNavMesh);
navFolder.add(config, 'walkableSlopeAngleDegrees', 0, 90, 5).onChange(generateNavMesh);
navFolder.add(config, 'minRegionArea', 0, 50, 1).onChange(generateNavMesh);
navFolder.add(config, 'usePhotogrammetryFilter').name('Filter Floor Triangles').onChange(generateNavMesh);
gui.add({ generateNavMesh }, 'generateNavMesh').name('Re-generate NavMesh');

/* Navigation Control Buttons */
const btnSetStart = document.getElementById('btn-set-start')!;
const btnSetDest = document.getElementById('btn-set-dest')!;
const btnClearNav = document.getElementById('btn-clear-nav')!;
const instructionBadge = document.getElementById('mode-instruction')!;

function setMode(mode: 'start' | 'dest' | 'inspect') {
    clickMode = mode;
    btnSetStart.classList.toggle('active', mode === 'start');
    btnSetDest.classList.toggle('active', mode === 'dest');

    if (mode === 'start') {
        instructionBadge.textContent = '📍 Click on the floor to set START point';
    } else if (mode === 'dest') {
        instructionBadge.textContent = '🏁 Click on the floor to set DESTINATION point';
    } else {
        instructionBadge.textContent = 'Click "Set Start" or "Set Destination", then click floor';
    }
}

function clearNavigation() {
    startPoint = null;
    destPoint = null;
    startSnappedPoint = null;
    destSnappedPoint = null;
    startPolyId = null;
    destPolyId = null;

    testResults.startRaw = null;
    testResults.startSnapped = null;
    testResults.startPolyId = null;
    testResults.destRaw = null;
    testResults.destSnapped = null;
    testResults.destPolyId = null;
    testResults.findPathWorked = false;
    testResults.pathDistance = 0;
    testResults.pathPointsCount = 0;

    clearPathVisuals();

    document.getElementById('start-raw')!.textContent = '-';
    document.getElementById('start-poly-id')!.textContent = '-';
    document.getElementById('start-snapped')!.textContent = '-';
    document.getElementById('dest-raw')!.textContent = '-';
    document.getElementById('dest-poly-id')!.textContent = '-';
    document.getElementById('dest-snapped')!.textContent = '-';

    document.getElementById('path-found')!.textContent = '-';
    document.getElementById('path-found')!.className = 'hud-value';
    document.getElementById('path-distance')!.textContent = '-';
    document.getElementById('path-waypoints')!.textContent = '-';

    setMode('inspect');
}

btnSetStart.addEventListener('click', () => setMode(clickMode === 'start' ? 'inspect' : 'start'));
btnSetDest.addEventListener('click', () => setMode(clickMode === 'dest' ? 'inspect' : 'dest'));
btnClearNav.addEventListener('click', clearNavigation);

/* Raycasting */
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

renderer.domElement.addEventListener('pointerdown', (event: PointerEvent) => {
    if (event.button !== 0) return;

    const rect = renderer.domElement.getBoundingClientRect();
    pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    raycaster.setFromCamera(pointer, camera);
    const intersects = raycaster.intersectObjects(walkableMeshes, true);

    if (intersects.length > 0) {
        const hitPoint = intersects[0].point;
        const clickedPos: Vec3 = [hitPoint.x, hitPoint.y, hitPoint.z];

        if (clickMode === 'start') {
            startPoint = clickedPos;
            testResults.startRaw = clickedPos;
            document.getElementById('start-raw')!.textContent = `${clickedPos[0].toFixed(2)}, ${clickedPos[1].toFixed(2)}, ${clickedPos[2].toFixed(2)}`;
            setMode('inspect');
            updateNavigation();
        } else if (clickMode === 'dest') {
            destPoint = clickedPos;
            testResults.destRaw = clickedPos;
            document.getElementById('dest-raw')!.textContent = `${clickedPos[0].toFixed(2)}, ${clickedPos[1].toFixed(2)}, ${clickedPos[2].toFixed(2)}`;
            setMode('inspect');
            updateNavigation();
        }
    }
});

/* STAGE B — STAGE B.1/B.2/B.3 Pathfinding & Poly Snapping */
function updateNavigation() {
    if (!navMeshResult || !navMeshResult.navMesh) return;

    clearPathVisuals();

    const navMesh = navMeshResult.navMesh;
    const polyCount = testResults.navMeshPolyCount;

    if (polyCount === 0) {
        const pathFoundEl = document.getElementById('path-found')!;
        pathFoundEl.textContent = 'Navigation unavailable — NavMesh contains 0 polygons';
        pathFoundEl.className = 'hud-value danger';
        return;
    }

    const halfExtents: Vec3 = [5, 5, 5]; // Generous search extent box for poly snapping

    // Process Start Point
    if (startPoint) {
        const startFlag = createFlag(0x38bdf8); // Cyan
        startFlag.object.position.set(...startPoint);
        addPathVisual(startFlag);

        const snapResult = createFindNearestPolyResult();
        findNearestPoly(snapResult, navMesh, startPoint, halfExtents, DEFAULT_QUERY_FILTER);

        if (snapResult.success) {
            startSnappedPoint = snapResult.position;
            startPolyId = snapResult.nodeRef;
            testResults.startSnapped = snapResult.position;
            testResults.startPolyId = snapResult.nodeRef;
            testResults.findNearestPolyWorked = true;

            document.getElementById('start-poly-id')!.textContent = snapResult.nodeRef.toString();
            document.getElementById('start-snapped')!.textContent = `${snapResult.position[0].toFixed(2)}, ${snapResult.position[1].toFixed(2)}, ${snapResult.position[2].toFixed(2)}`;

            const polyHelper = createNavMeshPolyHelper(navMesh, snapResult.nodeRef, [0, 0.8, 1]);
            polyHelper.object.position.y += 0.08;
            addPathVisual(polyHelper);
        } else {
            document.getElementById('start-poly-id')!.textContent = 'None';
            document.getElementById('start-snapped')!.textContent = 'Start is not on a navigable surface';
        }
    }

    // Process Destination Point
    if (destPoint) {
        const destFlag = createFlag(0x4ade80); // Green
        destFlag.object.position.set(...destPoint);
        addPathVisual(destFlag);

        const snapResult = createFindNearestPolyResult();
        findNearestPoly(snapResult, navMesh, destPoint, halfExtents, DEFAULT_QUERY_FILTER);

        if (snapResult.success) {
            destSnappedPoint = snapResult.position;
            destPolyId = snapResult.nodeRef;
            testResults.destSnapped = snapResult.position;
            testResults.destPolyId = snapResult.nodeRef;
            testResults.findNearestPolyWorked = true;

            document.getElementById('dest-poly-id')!.textContent = snapResult.nodeRef.toString();
            document.getElementById('dest-snapped')!.textContent = `${snapResult.position[0].toFixed(2)}, ${snapResult.position[1].toFixed(2)}, ${snapResult.position[2].toFixed(2)}`;

            const polyHelper = createNavMeshPolyHelper(navMesh, snapResult.nodeRef, [0.2, 1, 0.4]);
            polyHelper.object.position.y += 0.08;
            addPathVisual(polyHelper);
        } else {
            document.getElementById('dest-poly-id')!.textContent = 'None';
            document.getElementById('dest-snapped')!.textContent = 'Destination is not on a navigable surface';
        }
    }

    // Calculate Path if both start and destination points exist
    if (startPoint && destPoint && startSnappedPoint && destSnappedPoint) {
        console.time('findPath');
        const pathResult = findPath(navMesh, startSnappedPoint, destSnappedPoint, halfExtents, DEFAULT_QUERY_FILTER);
        console.timeEnd('findPath');

        const { path, nodePath } = pathResult;

        if (nodePath) {
            const searchNodesHelper = createSearchNodesHelper(nodePath.nodes);
            addPathVisual(searchNodesHelper);
        }

        if (path && path.length > 0) {
            testResults.findPathWorked = true;
            testResults.pathPointsCount = path.length;

            let totalDistance = 0;
            const linePositions: number[] = [];

            for (let i = 0; i < path.length; i++) {
                const pt = path[i].position;
                linePositions.push(pt[0], pt[1] + 0.15, pt[2]);

                // Render Waypoint Sphere
                const sphere = new THREE.Mesh(
                    new THREE.SphereGeometry(0.15, 12, 12),
                    new THREE.MeshBasicMaterial({ color: i === 0 ? 0x38bdf8 : i === path.length - 1 ? 0x4ade80 : 0xfbbf24 }),
                );
                sphere.position.set(pt[0], pt[1] + 0.15, pt[2]);
                addPathVisual({
                    object: sphere,
                    dispose: () => {
                        sphere.geometry.dispose();
                        (sphere.material as THREE.Material).dispose();
                    },
                });

                if (i > 0) {
                    const prevPt = path[i - 1].position;
                    const dx = pt[0] - prevPt[0];
                    const dy = pt[1] - prevPt[1];
                    const dz = pt[2] - prevPt[2];
                    totalDistance += Math.sqrt(dx * dx + dy * dy + dz * dz);
                }
            }

            testResults.pathDistance = Math.round(totalDistance * 100) / 100;

            // Draw Path Line
            const lineGeometry = new LineGeometry();
            lineGeometry.setPositions(linePositions);
            const lineMaterial = new LineMaterial({
                color: 0xfacc15, // Bright yellow
                linewidth: 6,
                resolution: new THREE.Vector2(window.innerWidth, window.innerHeight),
            });
            const line = new Line2(lineGeometry, lineMaterial);
            addPathVisual({
                object: line,
                dispose: () => {
                    lineGeometry.dispose();
                    lineMaterial.dispose();
                },
            });

            const pathFoundEl = document.getElementById('path-found')!;
            pathFoundEl.textContent = 'YES (Success)';
            pathFoundEl.className = 'hud-value highlight';
            document.getElementById('path-distance')!.textContent = `${totalDistance.toFixed(2)} meters`;
            document.getElementById('path-waypoints')!.textContent = path.length.toString();
        } else {
            testResults.findPathWorked = false;
            const pathFoundEl = document.getElementById('path-found')!;
            pathFoundEl.textContent = 'No Path Found between points';
            pathFoundEl.className = 'hud-value danger';
            document.getElementById('path-distance')!.textContent = '-';
            document.getElementById('path-waypoints')!.textContent = '0';
        }
    }
}

/* Perform initial auto-test between surface points */
function runAutoTest() {
    if (!walkableMeshes.length || !navMeshResult || testResults.navMeshPolyCount === 0) return;

    const bbox = new THREE.Box3().setFromObject(modelGroup!);
    const center = new THREE.Vector3();
    bbox.getCenter(center);
    const size = new THREE.Vector3();
    bbox.getSize(size);

    const p1: Vec3 = [center.x - size.x * 0.15, bbox.min.y + 0.1, center.z - size.z * 0.15];
    const p2: Vec3 = [center.x + size.x * 0.15, bbox.min.y + 0.1, center.z + size.z * 0.15];

    startPoint = p1;
    destPoint = p2;
    testResults.startRaw = p1;
    testResults.destRaw = p2;

    document.getElementById('start-raw')!.textContent = `${p1[0].toFixed(2)}, ${p1[1].toFixed(2)}, ${p1[2].toFixed(2)}`;
    document.getElementById('dest-raw')!.textContent = `${p2[0].toFixed(2)}, ${p2[1].toFixed(2)}, ${p2[2].toFixed(2)}`;

    updateNavigation();
}

/* Indoor AR Navigation System Setup */
const navigationGraph = new NavigationGraph(SAMPLE_NODES, SAMPLE_EDGES);
const navigationEngine = new NavigationEngine(navigationGraph);
const mockPositionProvider = new MockPositionProvider();
navigationEngine.setPositionProvider(mockPositionProvider);

const routeVisualizer = new RouteVisualizer(scene);
const userMarker = new UserMarker(scene);
const debugVisualizer = new DebugVisualizer(scene);
debugVisualizer.renderGraph(navigationGraph);

// Synchronize state changes to 3D elements and HUD
navigationEngine.onStateChange((state) => {
    routeVisualizer.updateRoute(state.route);
    userMarker.setPosition(state.userPosition);

    const statusEl = document.getElementById('nav-engine-status');
    const destEl = document.getElementById('nav-engine-dest');
    const distEl = document.getElementById('nav-engine-dist-rem');
    const coordsEl = document.getElementById('nav-engine-coords');

    if (statusEl) {
        statusEl.textContent = state.status.toUpperCase();
        statusEl.className = `hud-value ${
            state.status === 'arrived'
                ? 'highlight'
                : state.status === 'off-route'
                ? 'danger'
                : state.status === 'navigating'
                ? 'warn'
                : ''
        }`;
    }
    if (destEl) destEl.textContent = state.destinationNode ? state.destinationNode.name : '-';
    if (distEl) distEl.textContent = state.status !== 'idle' ? `${state.distanceRemaining.toFixed(1)} m` : '-';
    if (coordsEl) {
        const p = state.userPosition.position;
        coordsEl.textContent = `${p.x.toFixed(2)}, ${p.y.toFixed(2)}, ${p.z.toFixed(2)}`;
    }
});

// Select Destination listener
const selectDestEl = document.getElementById('select-destination') as HTMLSelectElement | null;
if (selectDestEl) {
    selectDestEl.addEventListener('change', () => {
        const selectedId = selectDestEl.value;
        if (selectedId) {
            navigationEngine.setDestinationNode(selectedId);
            mockPositionProvider.setRoute(navigationEngine.getState().route);
        } else {
            navigationEngine.setDestinationNode(null);
            mockPositionProvider.stop();
        }
    });
}

// Mock Simulation controls
document.getElementById('btn-start-mock-walk')?.addEventListener('click', () => {
    const route = navigationEngine.getState().route;
    if (route.length > 0) {
        mockPositionProvider.setRoute(route);
        mockPositionProvider.start();
    }
});

document.getElementById('btn-pause-mock-walk')?.addEventListener('click', () => {
    mockPositionProvider.stop();
});

document.getElementById('btn-simulate-offroute')?.addEventListener('click', () => {
    mockPositionProvider.simulateOffRoute(4.0);
});

document.getElementById('btn-toggle-graph-debug')?.addEventListener('click', () => {
    debugVisualizer.toggle();
});

// Initial load of sample1.glb
loadModel('./models/sample1.glb');

/* Main Render Loop */
function animate() {
    requestAnimationFrame(animate);
    orbitControls.update();
    userMarker.update(0.016);
    renderer.render(scene, camera);
}
animate();
