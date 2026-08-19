import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/Addons.js';

import {
    MapManager,
    MapConfig,
    MapDestination,
    QRScanner,
    QRPayload,
} from '../../src/maps';

import {
    NavigationEngine,
    RouteVisualizer,
    UserMarker,
    DebugVisualizer,
    VPSPositionProvider,
    ARCoreTrackingProvider,
    PoseFusion,
    vpsToGLB,
} from '../../src/navigation';

import {
    VPSClient,
    VPSAdapter,
    VPSCameraView,
    WorldAnchorManager,
    MockVPSServer,
    getVPSConfig,
    VPSPose,
    VPSStatus,
} from '../../src/vps';

/* 1. Initialize 3D Graphics Scene */
const container = document.getElementById('three-canvas-container')!;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 100);
camera.position.set(0, 5, 12);
camera.lookAt(0, 0, 0);

const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
container.appendChild(renderer.domElement);

const orbitControls = new OrbitControls(camera, renderer.domElement);
orbitControls.enableDamping = true;

// Lighting
const ambientLight = new THREE.AmbientLight(0xffffff, 1.4);
scene.add(ambientLight);
const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
dirLight.position.set(5, 12, 7);
scene.add(dirLight);

/* 2. Initialize Core Architecture Modules */
const mapManager = new MapManager();
const qrScanner = new QRScanner(mapManager);

const vpsConfig = getVPSConfig();
// Clearly labeled MOCK VPS Server for development
const mockVPSServer = new MockVPSServer();
mockVPSServer.enableFetchInterceptor(vpsConfig.serverUrl);

const vpsClient = new VPSClient(vpsConfig.serverUrl);
const vpsAdapter = new VPSAdapter(vpsClient);
const vpsCameraView = new VPSCameraView(vpsConfig.frameRate);
const vpsPositionProvider = new VPSPositionProvider(vpsAdapter, vpsCameraView);

const arCoreProvider = new ARCoreTrackingProvider();
const poseFusion = new PoseFusion(arCoreProvider);

const worldAnchorManager = new WorldAnchorManager(scene, camera);
const routeVisualizer = new RouteVisualizer(scene);
const userMarker = new UserMarker(scene);
const debugVisualizer = new DebugVisualizer(scene);

let activeMapConfig: MapConfig | null = null;
let activeGraph: any = null;
let navigationEngine: NavigationEngine | null = null;
let selectedDestination: MapDestination | null = null;
let walkSimulationInterval: any = null;

/* 3. Screen Management */
function showScreen(screenNum: number) {
    for (let i = 1; i <= 3; i++) {
        const el = document.getElementById(`screen-${i}`);
        if (el) el.classList.toggle('hidden', i !== screenNum);
    }
    const hud4 = document.getElementById('screen-4-hud');
    if (hud4) hud4.style.display = screenNum === 4 ? 'block' : 'none';
}

/* ==================================================
   PHASE 1 & 2 — QR CODE SCANNING & MAP INITIALIZATION
   ================================================== */
function handleQRScanSuccess(payload: QRPayload) {
    const { config, graph } = mapManager.loadMapFromQR(payload);
    activeMapConfig = config;
    activeGraph = graph;

    // Apply coordinate transformation config to VPS adapter
    vpsAdapter.setTransformConfig(config.transformConfig);
    vpsPositionProvider.setActiveMapId(config.vpsMapId);

    // Build Navigation Engine
    navigationEngine = new NavigationEngine(activeGraph);
    navigationEngine.setPositionProvider(poseFusion);

    debugVisualizer.renderGraph(activeGraph);

    // Update UI Elements
    const anchor = config.anchors[payload.anchorId] || Object.values(config.anchors)[0];
    document.getElementById('qr-building-name')!.textContent = config.name;
    document.getElementById('qr-entrance-name')!.textContent = anchor ? anchor.name : payload.anchorId;
    document.getElementById('qr-floor-val')!.textContent = config.floor.toString();

    document.getElementById('qr-result-card')!.style.display = 'block';
    const continueBtn = document.getElementById('btn-screen1-continue')!;
    continueBtn.style.display = 'flex';
}

document.getElementById('btn-scan-qr')?.addEventListener('click', async () => {
    const cameraContainer = document.getElementById('camera-container')!;
    await qrScanner.startScanning(cameraContainer, (payload) => {
        handleQRScanSuccess(payload);
    }, (err) => {
        alert(`Camera QR scan info: ${err}. Triggering sample site scan.`);
        const fallback = mapManager.parseQRPayload('https://pathlume.app/s/demo_site')!;
        handleQRScanSuccess(fallback);
    });
});

document.getElementById('preset-url')?.addEventListener('click', () => {
    qrScanner.simulateScan('https://pathlume.app/s/demo_site', (payload) => {
        handleQRScanSuccess(payload);
    });
});

document.getElementById('preset-uri')?.addEventListener('click', () => {
    qrScanner.simulateScan('pathlume://site/demo_site', (payload) => {
        handleQRScanSuccess(payload);
    });
});

document.getElementById('preset-json')?.addEventListener('click', () => {
    qrScanner.simulateScan({ siteId: 'demo_site' }, (payload) => {
        handleQRScanSuccess(payload);
    });
});

document.getElementById('btn-screen1-continue')?.addEventListener('click', () => {
    showScreen(2);
    startVPSLocalization();
});

/* ==================================================
   PHASE 3 & 4 — VPS LOCALIZATION & TRANSFORMATION
   ================================================== */
async function startVPSLocalization() {
    const cameraContainer = document.getElementById('camera-container')!;
    await vpsPositionProvider.start(cameraContainer);
    arCoreProvider.start();

    vpsPositionProvider.onStatusUpdate((status, details) => {
        const badge = document.getElementById('vps-status-badge-screen2');
        const locCard = document.getElementById('vps-localized-card');
        const nextBtn = document.getElementById('btn-screen2-next');

        if (badge) {
            badge.textContent = status.replace('_', ' ');
            badge.className = `vps-status-badge ${
                status === 'VPS_LOCALIZED'
                    ? 'status-localized'
                    : status === 'VPS_LOST' || status === 'VPS_ERROR'
                    ? 'status-lost'
                    : 'status-searching'
            }`;
        }

        if (details && details.pose) {
            const rawPose: VPSPose = details.pose;
            worldAnchorManager.applyVPSPose(rawPose);
            // Phase 4: Apply coordinate transformation vpsToGLB()
            const transformedPose = vpsToGLB(rawPose, activeMapConfig?.transformConfig);

            // Phase 10: Fuse VPS pose into Pose Fusion
            poseFusion.applyVPSCorrection(transformedPose, status as VPSStatus);

            // Phase 5: Update Developer User Marker in GLB World
            userMarker.setPosition({
                position: transformedPose.position,
                heading: transformedPose.heading,
                floor: transformedPose.floor,
                accuracy: transformedPose.accuracy,
            });

            // Update UI Card
            const p = transformedPose.position;
            document.getElementById('loc-pose-val')!.textContent = `X: ${p.x.toFixed(2)}, Y: ${p.y.toFixed(2)}, Z: ${p.z.toFixed(2)}`;
            document.getElementById('loc-acc-val')!.textContent = `${transformedPose.accuracy.toFixed(2)}m`;
            document.getElementById('loc-floor-val')!.textContent = transformedPose.floor.toString();

            if (locCard) locCard.style.display = 'block';
            if (nextBtn) nextBtn.style.display = 'flex';
        }
    });
}

document.getElementById('btn-screen2-back')?.addEventListener('click', () => showScreen(1));
document.getElementById('btn-screen2-next')?.addEventListener('click', () => {
    populateDestinations();
    showScreen(3);
});

/* ==================================================
   PHASE 6 — DESTINATION SELECTION
   ================================================== */
function populateDestinations(searchQuery = '') {
    const listContainer = document.getElementById('dest-list')!;
    listContainer.innerHTML = '';

    if (!activeMapConfig) return;

    const query = searchQuery.toLowerCase().trim();
    const destinations = activeMapConfig.destinations.filter(d => 
        !query || d.name.toLowerCase().includes(query) || (d.type && d.type.toLowerCase().includes(query))
    );

    for (const dest of destinations) {
        const item = document.createElement('div');
        item.className = `dest-item ${selectedDestination?.id === dest.id ? 'selected' : ''}`;
        item.setAttribute('data-id', dest.id);
        item.innerHTML = `
            <span class="dest-name">${dest.name}</span>
            <span class="dest-type">${dest.type || 'Destination'}</span>
        `;

        item.addEventListener('click', () => {
            document.querySelectorAll('.dest-item').forEach(i => i.classList.remove('selected'));
            item.classList.add('selected');
            selectedDestination = dest;
            (document.getElementById('btn-start-ar-nav') as HTMLButtonElement).disabled = false;
        });

        listContainer.appendChild(item);
    }
}

document.getElementById('dest-search')?.addEventListener('input', (e: any) => {
    populateDestinations(e.target.value);
});

document.getElementById('btn-screen3-back')?.addEventListener('click', () => showScreen(2));

/* ==================================================
   PHASE 7 - 18 — AR NAVIGATION & POSE FUSION EXECUTION
   ================================================== */
document.getElementById('btn-start-ar-nav')?.addEventListener('click', () => {
    if (!selectedDestination || !navigationEngine) return;

    // Phase 7: A* Routing from CURRENT LOCALIZED USER POSITION (nearest nav node)
    navigationEngine.setDestinationNode(selectedDestination.navigationNodeId);

    showScreen(4);
    startLiveARNavigation();
});

function startLiveARNavigation() {
    if (!navigationEngine) return;

    // Phase 10 & 13 & 14: Listen to Navigation Engine State Changes
    navigationEngine.onStateChange((state) => {
        routeVisualizer.updateRoute(state.route);
        userMarker.setPosition(state.userPosition);

        document.getElementById('ar-dest-title')!.textContent = state.destinationNode ? state.destinationNode.name : '-';
        document.getElementById('ar-dist-rem')!.textContent = state.status !== 'idle' ? `${state.distanceRemaining.toFixed(1)} m` : '0 m';

        // Phase 13: Off-route Toast Notification
        const toast = document.getElementById('reroute-toast')!;
        if (state.status === 'off-route') {
            toast.style.display = 'flex';
            setTimeout(() => { toast.style.display = 'none'; }, 3000);
        } else {
            toast.style.display = 'none';
        }

        // Phase 14: Arrival Modal Display
        if (state.status === 'arrived') {
            document.getElementById('arrival-dest-name')!.textContent = state.destinationNode ? state.destinationNode.name : 'Destination';
            document.getElementById('arrival-modal')!.style.display = 'flex';
            if (walkSimulationInterval) {
                clearInterval(walkSimulationInterval);
                walkSimulationInterval = null;
            }
        }

        // Telemetry Panel Updates (Phase 17 Debug Mode)
        const fused = poseFusion.getFusedPose();
        document.getElementById('db-map')!.textContent = activeMapConfig?.mapId || 'college_block_a';
        document.getElementById('db-vps')!.textContent = `${vpsAdapter.getStatus()} (${fused.accuracy.toFixed(2)}m)`;
        document.getElementById('db-arcore')!.textContent = `TRACKING | ${fused.status}`;
        document.getElementById('db-floor')!.textContent = `Floor ${fused.floor} | ${Math.round(fused.heading)}°`;
        document.getElementById('db-pos')!.textContent = `${fused.position.x.toFixed(2)}, ${fused.position.y.toFixed(2)}, ${fused.position.z.toFixed(2)}`;
        document.getElementById('db-latency')!.textContent = `${vpsClient.getLastLatencyMs()} ms`;
        document.getElementById('db-route')!.textContent = `VISIBLE | ${state.status.toUpperCase()}`;
    });
}

/* ==================================================
   PHASE 17 & DEBUG TOOLING
   ================================================== */
document.getElementById('btn-sim-offroute')?.addEventListener('click', () => {
    // Simulate user stepping >2.0 meters off route
    const current = poseFusion.getCurrentPosition();
    arCoreProvider.updateRelativeMotion(3.5, 0, 3.5);
    if (navigationEngine) {
        navigationEngine.updateUserPosition({
            position: { x: current.position.x + 3.5, y: current.position.y, z: current.position.z + 3.5 },
            floor: current.floor,
            heading: current.heading,
            accuracy: 0.5,
        });
    }
});

document.getElementById('btn-sim-walk')?.addEventListener('click', () => {
    if (walkSimulationInterval) {
        clearInterval(walkSimulationInterval);
        walkSimulationInterval = null;
        (document.getElementById('btn-sim-walk') as HTMLElement).textContent = '🚶 Sim Walk Along Route';
        return;
    }

    (document.getElementById('btn-sim-walk') as HTMLElement).textContent = '⏹️ Stop Sim Walk';
    
    walkSimulationInterval = setInterval(() => {
        const state = navigationEngine?.getState();
        if (!state || state.route.length < 2 || state.status === 'arrived') {
            clearInterval(walkSimulationInterval);
            walkSimulationInterval = null;
            return;
        }

        const currentPos = poseFusion.getCurrentPosition().position;
        const targetNode = state.route[1] || state.route[0];
        const dx = targetNode.position.x - currentPos.x;
        const dz = targetNode.position.z - currentPos.z;
        const dist = Math.sqrt(dx * dx + dz * dz);

        if (dist > 0.1) {
            const step = Math.min(0.4, dist);
            const stepX = (dx / dist) * step;
            const stepZ = (dz / dist) * step;

            // Apply high-frequency motion tracking delta
            arCoreProvider.updateRelativeMotion(stepX, 0, stepZ);

            if (navigationEngine) {
                navigationEngine.updateUserPosition(poseFusion.getCurrentPosition());
            }
        }
    }, 200);
});

document.getElementById('btn-toggle-nodes')?.addEventListener('click', () => {
    debugVisualizer.toggle();
});

document.getElementById('btn-arrival-done')?.addEventListener('click', () => {
    document.getElementById('arrival-modal')!.style.display = 'none';
    if (navigationEngine) navigationEngine.clear();
    showScreen(3);
});

// Window resize handler
window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

// Animation Loop (Phase 19 Performance Optimization)
function animate() {
    requestAnimationFrame(animate);
    orbitControls.update();
    userMarker.update(0.016);
    renderer.render(scene, camera);
}
animate();
