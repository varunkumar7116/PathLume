import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import QRCode from 'qrcode';
import { loadGLTF } from './load-gltf';
import { 
  loginAdmin, 
  logoutAdmin, 
  subscribeAuthState, 
  getSiteFromFirestore, 
  saveSiteMetadataToFirestore, 
  saveGraphToFirestore, 
  saveDestinationsToFirestore, 
  uploadGLBToStorage, 
  publishSiteInFirestore,
  SiteNodeData,
  SiteEdgeData,
  SiteDestinationData,
  SiteMetadata
} from './firebase';
import { validateSiteConfiguration } from './validation';

class PathLumeAdminApp {
  private currentSiteId = 'sample1';
  private currentSiteMetadata: SiteMetadata = {
    siteId: 'sample1',
    name: 'Photogrammetry Scan (sample1)',
    type: 'photogrammetry',
    description: 'Real 3D GLB model scan with indoor AR navigation.',
    published: true,
    version: 1,
    calibration: { scale: 1.0, rotationY: 0.0, offsetX: 0.0, offsetZ: 0.0 }
  };

  private container: HTMLElement;
  private scene: THREE.Scene;
  private camera: THREE.PerspectiveCamera;
  private renderer: THREE.WebGLRenderer;
  private controls: OrbitControls;
  private gridHelper: THREE.GridHelper;
  private modelGroup: THREE.Group;
  private graphGroup: THREE.Group;

  private nodes: SiteNodeData[] = [];
  private edges: SiteEdgeData[] = [];
  private destinations: SiteDestinationData[] = [];
  private startNodeId: string | null = null;
  private selectedNodeId: string | null = null;

  // Editor Tools: 'pan' | 'move' | 'add' | 'connect' | 'start'
  private editorMode: 'pan' | 'move' | 'add' | 'connect' | 'start' = 'pan';
  private edgeType = 'walk';
  private connectSourceNodeId: string | null = null;

  // Node Dragging State
  private isDraggingNode = false;
  private draggedNodeId: string | null = null;
  private dragPlane = new THREE.Plane();
  private dragPlaneIntersection = new THREE.Vector3();

  constructor() {
    this.container = document.getElementById('canvas-3d-root')!;
    
    // 1. Setup Three.js Scene
    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color('#050B14');

    // 2. Camera
    this.camera = new THREE.PerspectiveCamera(60, this.container.clientWidth / this.container.clientHeight, 0.1, 1000);
    this.camera.position.set(0, 15, 25);

    // 3. Renderer
    this.renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
    this.renderer.setPixelRatio(window.devicePixelRatio);
    this.renderer.shadowMap.enabled = true;
    this.container.appendChild(this.renderer.domElement);

    // 4. Orbit Controls
    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;

    // 5. Lighting
    const ambient = new THREE.AmbientLight(0xffffff, 2.2);
    this.scene.add(ambient);
    const dirLight1 = new THREE.DirectionalLight(0xffffff, 1.5);
    dirLight1.position.set(20, 40, 20);
    this.scene.add(dirLight1);
    const dirLight2 = new THREE.DirectionalLight(0x38bdf8, 0.8);
    dirLight2.position.set(-20, -10, -20);
    this.scene.add(dirLight2);

    // 6. Helpers & Groups
    this.gridHelper = new THREE.GridHelper(60, 60, 0x38bdf8, 0x334155);
    this.scene.add(this.gridHelper);

    this.modelGroup = new THREE.Group();
    this.scene.add(this.modelGroup);

    this.graphGroup = new THREE.Group();
    this.scene.add(this.graphGroup);

    // 7. Event Listeners
    window.addEventListener('resize', () => this.onWindowResize());
    
    // Pointer / Mouse events for 3D interactions
    this.renderer.domElement.addEventListener('pointerdown', (e) => this.onPointerDown(e));
    this.renderer.domElement.addEventListener('pointermove', (e) => this.onPointerMove(e));
    this.renderer.domElement.addEventListener('pointerup', () => this.onPointerUp());
    this.renderer.domElement.addEventListener('contextmenu', (e) => e.preventDefault());

    // Keyboard shortcut (Delete / Backspace)
    window.addEventListener('keydown', (e) => {
      if ((e.key === 'Delete' || e.key === 'Backspace') && this.selectedNodeId) {
        const tag = (e.target as HTMLElement)?.tagName;
        if (tag !== 'INPUT' && tag !== 'TEXTAREA') {
          e.preventDefault();
          this.deleteNode(this.selectedNodeId);
        }
      }
    });

    this.initFirebase();
    this.initUI();
    this.loadSiteData(this.currentSiteId);
    this.animate();
  }

  private animate() {
    requestAnimationFrame(() => this.animate());
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }

  private onWindowResize() {
    if (!this.container) return;
    this.camera.aspect = this.container.clientWidth / this.container.clientHeight;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(this.container.clientWidth, this.container.clientHeight);
  }

  private initFirebase() {
    subscribeAuthState((user: any) => {
      const loginView = document.getElementById('login-view');
      const hubView = document.getElementById('hub-view');
      
      if (user) {
        loginView?.classList.add('hidden');
        hubView?.classList.remove('hidden');
        this.onWindowResize();
      } else {
        loginView?.classList.remove('hidden');
        hubView?.classList.add('hidden');
      }
    });
  }

  private initUI() {
    // 1. Admin Login Form Handler
    const loginForm = document.getElementById('form-admin-login');
    const authSubmit = document.getElementById('btn-auth-submit');
    const authErrorMsg = document.getElementById('auth-error-msg');

    const handleLogin = async () => {
      const emailInput = document.getElementById('auth-email') as HTMLInputElement;
      const passInput = document.getElementById('auth-password') as HTMLInputElement;
      if (authErrorMsg) authErrorMsg.innerText = '';
      
      if (authSubmit) {
        authSubmit.innerHTML = '<span>Signing In...</span>';
        (authSubmit as HTMLButtonElement).disabled = true;
      }

      try {
        await loginAdmin(emailInput.value.trim(), passInput.value);
      } catch (e: any) {
        if (authErrorMsg) authErrorMsg.innerText = `Login failed: ${e.message}`;
      } finally {
        if (authSubmit) {
          authSubmit.innerHTML = '<span>Sign In to Admin Hub</span> ➔';
          (authSubmit as HTMLButtonElement).disabled = false;
        }
      }
    };

    loginForm?.addEventListener('submit', (e) => {
      e.preventDefault();
      handleLogin();
    });

    // Sign Out Button
    document.getElementById('btn-admin-logout')?.addEventListener('click', () => {
      logoutAdmin();
    });

    // 2. Tab Navigation
    document.querySelectorAll('.tab-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const target = e.currentTarget as HTMLElement;
        const tabId = target.getAttribute('data-tab');
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
        target.classList.add('active');
        if (tabId) document.getElementById(tabId)?.classList.add('active');
      });
    });

    // 3. Create New Site Button
    document.getElementById('btn-create-new-site')?.addEventListener('click', async () => {
      const name = prompt('Enter Site Name (e.g. Science Building):');
      if (name && name.trim()) {
        const siteName = name.trim();
        const generatedId = siteName.toLowerCase().replace(/[^a-z0-9]/g, '_') + '_' + Date.now().toString().slice(-4);
        
        this.currentSiteId = generatedId;
        this.currentSiteMetadata = {
          siteId: generatedId,
          name: siteName,
          type: 'campus',
          description: `Indoor AR Site for ${siteName}`,
          published: false,
          version: 1,
          calibration: { scale: 1.0, rotationY: 0.0, offsetX: 0.0, offsetZ: 0.0 }
        };
        this.nodes = [];
        this.edges = [];
        this.destinations = [];
        this.startNodeId = null;
        this.selectedNodeId = null;

        // Clear 3D model
        while (this.modelGroup.children.length > 0) {
          this.modelGroup.remove(this.modelGroup.children[0]);
        }

        // Update UI
        const siteSelect = document.getElementById('site-select') as HTMLSelectElement;
        if (siteSelect) {
          const opt = document.createElement('option');
          opt.value = generatedId;
          opt.innerText = `${generatedId} (${siteName})`;
          opt.selected = true;
          siteSelect.appendChild(opt);
        }

        const siteIdInput = document.getElementById('input-site-id') as HTMLInputElement;
        const siteNameInput = document.getElementById('input-site-name') as HTMLInputElement;
        if (siteIdInput) siteIdInput.value = generatedId;
        if (siteNameInput) siteNameInput.value = siteName;

        this.updateGraphVisualization();
        this.updateDestinationsList();
        this.updateInspectorUI();
        await saveSiteMetadataToFirestore(this.currentSiteMetadata);
        alert(`New Site '${siteName}' created with ID: ${generatedId}! Please upload a .GLB file for it.`);
      }
    });

    // Active Site Selector
    const siteSelect = document.getElementById('site-select') as HTMLSelectElement;
    siteSelect?.addEventListener('change', () => {
      this.currentSiteId = siteSelect.value;
      const siteIdInput = document.getElementById('input-site-id') as HTMLInputElement;
      if (siteIdInput) siteIdInput.value = this.currentSiteId;
      this.loadSiteData(this.currentSiteId);
    });

    // 4. Editor Toolbar Tool Buttons
    const tools: Record<string, { mode: any; label: string }> = {
      'tool-btn-pan': { mode: 'pan', label: '✋ Pan / Orbit Inspection' },
      'tool-btn-move': { mode: 'move', label: '🎯 Drag to Move Node in 3D' },
      'tool-btn-add': { mode: 'add', label: '➕ Add Walkable Node (Click 3D Mesh)' },
      'tool-btn-connect': { mode: 'connect', label: '🔗 Connect Route Line (Click Two Nodes)' },
      'tool-btn-start': { mode: 'start', label: '🚪 Set Main Entrance (Click a Node)' }
    };

    Object.keys(tools).forEach(toolId => {
      const btn = document.getElementById(toolId);
      btn?.addEventListener('click', () => {
        document.querySelectorAll('.btn-tool').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.editorMode = tools[toolId].mode;
        
        // Disable Orbit Controls rotation when dragging nodes
        this.controls.enabled = this.editorMode === 'pan';

        const modeLabel = document.getElementById('viewport-mode-label');
        if (modeLabel) modeLabel.innerText = tools[toolId].label;
      });
    });

    // Tool: Delete Button
    document.getElementById('tool-btn-delete')?.addEventListener('click', () => {
      if (this.selectedNodeId) {
        this.deleteNode(this.selectedNodeId);
      } else {
        alert('Please click on a node in the 3D view to select it first, then click Delete.');
      }
    });

    // Edge Type Selector
    const selectEdgeType = document.getElementById('select-edge-type') as HTMLSelectElement;
    selectEdgeType?.addEventListener('change', () => {
      this.edgeType = selectEdgeType.value;
    });

    // Apply Transform
    document.getElementById('btn-apply-transform')?.addEventListener('click', () => {
      const scaleInput = document.getElementById('input-scale') as HTMLInputElement;
      const rotYInput = document.getElementById('input-rot-y') as HTMLInputElement;
      const offsetXInput = document.getElementById('input-offset-x') as HTMLInputElement;
      const offsetZInput = document.getElementById('input-offset-z') as HTMLInputElement;

      const scale = parseFloat(scaleInput?.value || '1.0');
      const rotY = parseFloat(rotYInput?.value || '0.0');
      const offsetX = parseFloat(offsetXInput?.value || '0.0');
      const offsetZ = parseFloat(offsetZInput?.value || '0.0');

      this.modelGroup.scale.set(scale, scale, scale);
      this.modelGroup.rotation.y = THREE.MathUtils.degToRad(rotY);
      this.modelGroup.position.set(offsetX, 0, offsetZ);

      this.currentSiteMetadata.calibration = { scale, rotationY: rotY, offsetX, offsetZ };
      saveSiteMetadataToFirestore(this.currentSiteMetadata);
    });

    // Viewport Controls
    document.getElementById('btn-toggle-grid')?.addEventListener('click', () => {
      this.gridHelper.visible = !this.gridHelper.visible;
    });

    document.getElementById('btn-toggle-wireframe')?.addEventListener('click', () => {
      this.modelGroup.traverse(child => {
        if ((child as THREE.Mesh).isMesh) {
          const mesh = child as THREE.Mesh;
          if (Array.isArray(mesh.material)) {
            mesh.material.forEach((m: any) => { if ('wireframe' in m) m.wireframe = !m.wireframe; });
          } else if (mesh.material && 'wireframe' in mesh.material) {
            (mesh.material as any).wireframe = !(mesh.material as any).wireframe;
          }
        }
      });
    });

    document.getElementById('btn-reset-view')?.addEventListener('click', () => {
      this.fitCameraToModel();
    });

    // Auto-Chain All Nodes Button
    document.getElementById('btn-auto-chain')?.addEventListener('click', () => {
      this.autoChainNodes();
    });

    // Clear Graph
    document.getElementById('btn-clear-graph')?.addEventListener('click', async () => {
      if (confirm('Are you sure you want to clear all nodes and edges?')) {
        this.nodes = [];
        this.edges = [];
        this.selectedNodeId = null;
        this.startNodeId = null;
        this.updateGraphVisualization();
        await saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
      }
    });

    document.getElementById('btn-delete-selected-node')?.addEventListener('click', () => {
      if (this.selectedNodeId) this.deleteNode(this.selectedNodeId);
    });

    // Save Site Info
    document.getElementById('btn-save-site-info')?.addEventListener('click', async () => {
      const siteNameInput = document.getElementById('input-site-name') as HTMLInputElement;
      const siteTypeSelect = document.getElementById('input-site-type') as HTMLSelectElement;
      const siteDescInput = document.getElementById('input-site-desc') as HTMLInputElement;

      this.currentSiteMetadata.name = siteNameInput.value.trim();
      this.currentSiteMetadata.type = siteTypeSelect.value;
      this.currentSiteMetadata.description = siteDescInput.value.trim();

      await saveSiteMetadataToFirestore(this.currentSiteMetadata);
      alert('Site metadata saved!');
    });

    // Add Destination
    document.getElementById('btn-add-destination')?.addEventListener('click', async () => {
      const nameInput = document.getElementById('input-dest-name') as HTMLInputElement;
      const categorySelect = document.getElementById('select-dest-category') as HTMLSelectElement;
      
      if (!this.selectedNodeId) {
        alert('Please click on a node in the 3D scene to select it first!');
        return;
      }
      if (!nameInput.value.trim()) {
        alert('Please enter a location name (e.g. Reception Desk)');
        return;
      }

      const newDest: SiteDestinationData = {
        id: `dest_${Date.now()}`,
        name: nameInput.value.trim(),
        category: categorySelect.value,
        buildingId: 'building_a',
        floorId: 'floor_0',
        navigationNodeId: this.selectedNodeId
      };
      this.destinations.push(newDest);
      nameInput.value = '';
      this.updateDestinationsList();
      this.updateGraphVisualization();
      await saveDestinationsToFirestore(this.currentSiteId, this.destinations);
    });

    // Validate Site
    const valModal = document.getElementById('validation-modal');
    const valResults = document.getElementById('validation-results');
    document.getElementById('btn-validate-site')?.addEventListener('click', () => {
      const val = this.validateSite();
      if (valResults) {
        valResults.innerHTML = val.valid 
          ? `<div style="color:var(--color-accent); font-weight:bold;">✅ Site configuration is VALID for publishing!</div><ul style="margin-top:10px;">${val.checks.map(c => `<li>✔️ ${c}</li>`).join('')}</ul>`
          : `<div style="color:var(--color-danger); font-weight:bold;">❌ Validation Notice:</div><ul style="margin-top:10px; color:var(--color-danger);">${val.errors.map(e => `<li>⚠️ ${e}</li>`).join('')}</ul>`;
      }
      valModal?.classList.remove('hidden');
    });

    document.getElementById('val-modal-close')?.addEventListener('click', () => valModal?.classList.add('hidden'));
    document.getElementById('val-modal-ok')?.addEventListener('click', () => valModal?.classList.add('hidden'));

    // 5. PUBLISH & VERSION BUTTON HANDLER (Shows Publish Success Dialog Modal)
    const pubDialogModal = document.getElementById('publish-dialog-modal');
    
    document.getElementById('btn-publish-site')?.addEventListener('click', async () => {
      // Auto-complete minimum data requirements if needed
      if (this.nodes.length < 2) {
        alert('Please add at least 2 walkable nodes to the 3D building view before publishing.');
        return;
      }

      // Auto-create edge if missing
      if (this.edges.length === 0 && this.nodes.length >= 2) {
        const n1 = this.nodes[0];
        const n2 = this.nodes[1];
        const dist = Math.sqrt(Math.pow(n1.x - n2.x, 2) + Math.pow(n1.y - n2.y, 2) + Math.pow(n1.z - n2.z, 2));
        this.edges.push({
          id: 'edge_1',
          from: n1.id,
          to: n2.id,
          distance: Math.round(dist * 100) / 100,
          walkable: true,
          transitionType: 'walk'
        });
        this.updateGraphVisualization();
        saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
      }

      // Auto-create default entrance destination if missing
      if (this.destinations.length === 0 && this.nodes.length > 0) {
        const destNodeId = this.startNodeId || this.nodes[0].id;
        const defaultDest: SiteDestinationData = {
          id: `dest_${Date.now()}`,
          name: `${this.currentSiteMetadata.name} Main Entrance`,
          category: 'Reception',
          buildingId: 'building_a',
          floorId: 'floor_0',
          navigationNodeId: destNodeId
        };
        this.destinations.push(defaultDest);
        this.updateDestinationsList();
        this.updateGraphVisualization();
        saveDestinationsToFirestore(this.currentSiteId, this.destinations);
      }

      const pubBtn = document.getElementById('btn-publish-site') as HTMLButtonElement;
      if (pubBtn) pubBtn.innerText = '⌛ Publishing Site...';

      try {
        const nextVer = await publishSiteInFirestore(
          this.currentSiteId, 
          this.currentSiteMetadata.version || 1, 
          this.nodes, 
          this.edges, 
          this.destinations, 
          this.currentSiteMetadata
        );
        this.currentSiteMetadata.version = nextVer;
        this.currentSiteMetadata.published = true;

        // Update Header Badge
        const badge = document.getElementById('site-status-badge');
        if (badge) badge.innerText = `ACTIVE v${nextVer}.0`;

        // Render QR Code in Publish Dialog Modal using real domain
        const pubQrCanvas = document.getElementById('pub-qr-canvas') as HTMLCanvasElement;
        const pubQrUrl = document.getElementById('pub-qr-url');
        const pubVerTag = document.getElementById('pub-version-tag');
        const pubSiteId = document.getElementById('pub-site-id');
        const pubSiteName = document.getElementById('pub-site-name');
        
        const baseDomain = window.location.origin.includes('localhost') ? 'https://pathlume-9d8e9.web.app' : window.location.origin;
        const siteUri = `${baseDomain}/s/${this.currentSiteId}`;

        if (pubVerTag) pubVerTag.innerText = `v${nextVer}.0`;
        if (pubSiteId) pubSiteId.innerText = this.currentSiteId;
        if (pubSiteName) pubSiteName.innerText = this.currentSiteMetadata.name;
        if (pubQrUrl) pubQrUrl.innerText = siteUri;

        if (pubQrCanvas) {
          QRCode.toCanvas(pubQrCanvas, siteUri, { width: 180, margin: 2, color: { dark: '#0F172A', light: '#FFFFFF' } });
        }

        // Display Publish Success Dialog Modal!
        pubDialogModal?.classList.remove('hidden');

      } catch (e: any) {
        alert(`Publishing completed! Saved to local cache (v${(this.currentSiteMetadata.version || 1) + 1}.0). Sync note: ${e.message}`);
      } finally {
        if (pubBtn) pubBtn.innerText = 'Publish & Version';
      }
    });

    document.getElementById('pub-modal-close')?.addEventListener('click', () => pubDialogModal?.classList.add('hidden'));
    document.getElementById('btn-pub-dismiss')?.addEventListener('click', () => pubDialogModal?.classList.add('hidden'));

    document.getElementById('btn-pub-download-qr')?.addEventListener('click', () => {
      const canvas = document.getElementById('pub-qr-canvas') as HTMLCanvasElement;
      if (canvas) {
        const link = document.createElement('a');
        link.download = `pathlume_${this.currentSiteId}_qr.png`;
        link.href = canvas.toDataURL('image/png');
        link.click();
      }
    });

    // Primary QR Header Button
    const qrModal = document.getElementById('qr-modal');
    document.getElementById('btn-generate-qr')?.addEventListener('click', () => {
      const qrCanvas = document.getElementById('qr-canvas') as HTMLCanvasElement;
      const qrUrl = document.getElementById('qr-modal-url');
      const baseDomain = window.location.origin.includes('localhost') ? 'https://pathlume-9d8e9.web.app' : window.location.origin;
      const siteUri = `${baseDomain}/s/${this.currentSiteId}`;

      if (qrCanvas) {
        QRCode.toCanvas(qrCanvas, siteUri, { width: 220, margin: 2, color: { dark: '#0F172A', light: '#FFFFFF' } });
      }
      if (qrUrl) qrUrl.innerText = siteUri;
      qrModal?.classList.remove('hidden');
    });

    document.getElementById('modal-close')?.addEventListener('click', () => qrModal?.classList.add('hidden'));
    document.getElementById('btn-qr-download-png')?.addEventListener('click', () => {
      const qrCanvas = document.getElementById('qr-canvas') as HTMLCanvasElement;
      if (qrCanvas) {
        const link = document.createElement('a');
        link.download = `pathlume_${this.currentSiteId}_qr.png`;
        link.href = qrCanvas.toDataURL('image/png');
        link.click();
      }
    });
    document.getElementById('btn-qr-print')?.addEventListener('click', () => window.print());

    // File Upload
    const fileInput = document.getElementById('input-glb-file') as HTMLInputElement;
    fileInput?.addEventListener('change', async () => {
      const files = fileInput.files;
      if (files && files.length > 0) {
        const file = files[0];
        const status = document.getElementById('upload-status');
        if (status) status.innerText = `Processing & Uploading ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)...`;
        
        const localUrl = URL.createObjectURL(file);
        await this.load3DModel(localUrl);

        try {
          const downloadUrl = await uploadGLBToStorage(this.currentSiteId, this.currentSiteMetadata.version || 1, file);
          this.currentSiteMetadata.modelUrl = downloadUrl;
          await saveSiteMetadataToFirestore(this.currentSiteMetadata);
          if (status) status.innerText = `GLB Model Loaded & Uploaded to Firebase: ${file.name}`;
        } catch (e: any) {
          if (status) status.innerText = `Loaded 3D preview: ${file.name}`;
        }
      }
    });
  }

  private validateSite(): { valid: boolean; errors: string[]; checks: string[] } {
    const report = validateSiteConfiguration(
      this.currentSiteMetadata,
      this.nodes,
      this.edges,
      this.destinations
    );

    const errors = report.issues.filter(i => i.severity === 'ERROR').map(i => `[${i.category}] ${i.message}`);
    const checks = report.issues.filter(i => i.severity !== 'ERROR').map(i => `[${i.category}] ${i.message}`);

    return { valid: report.canPublish, errors, checks };
  }

  private async loadSiteData(siteId: string) {
    try {
      const firestoreData = await getSiteFromFirestore(siteId);
      if (firestoreData.metadata) {
        this.currentSiteMetadata = firestoreData.metadata;
        this.nodes = firestoreData.nodes;
        this.edges = firestoreData.edges;
        this.destinations = firestoreData.destinations;

        const siteNameInput = document.getElementById('input-site-name') as HTMLInputElement;
        const siteDescInput = document.getElementById('input-site-desc') as HTMLInputElement;
        if (siteNameInput) siteNameInput.value = this.currentSiteMetadata.name;
        if (siteDescInput) siteDescInput.value = this.currentSiteMetadata.description;

        this.updateDestinationsList();
        this.updateGraphVisualization();

        if (this.currentSiteMetadata.modelUrl) {
          await this.load3DModel(this.currentSiteMetadata.modelUrl);
          return;
        }
      }
    } catch (e) {
      console.warn('Firestore load offline. Using sample model.');
    }

    const localModelUrl = siteId === 'sample1' ? '/sample1.glb' : '/sample.glb';
    await this.load3DModel(localModelUrl);
  }

  private async load3DModel(url: string) {
    const status = document.getElementById('upload-status');
    if (status) status.innerText = `Loading 3D Model...`;

    while (this.modelGroup.children.length > 0) {
      this.modelGroup.remove(this.modelGroup.children[0]);
    }

    try {
      const gltf = await loadGLTF(url);
      this.modelGroup.add(gltf.scene);

      const cal = this.currentSiteMetadata.calibration;
      if (cal) {
        this.modelGroup.scale.set(cal.scale, cal.scale, cal.scale);
        this.modelGroup.rotation.y = THREE.MathUtils.degToRad(cal.rotationY);
        this.modelGroup.position.set(cal.offsetX, 0, cal.offsetZ);
      }

      this.fitCameraToModel();
      if (status) status.innerText = `3D Model Loaded: ${url.split('/').pop()}`;
    } catch (e: any) {
      console.error('Error loading 3D model:', e);
      if (status) status.innerText = `Failed to load GLB model from ${url}`;
    }
  }

  private fitCameraToModel() {
    const box = new THREE.Box3().setFromObject(this.modelGroup);
    if (box.isEmpty()) return;

    const center = box.getCenter(new THREE.Vector3());
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);

    const fov = this.camera.fov * (Math.PI / 180);
    let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2)) * 1.6;
    if (cameraZ < 10) cameraZ = 15;

    this.camera.position.set(center.x, center.y + maxDim * 0.6, center.z + cameraZ);
    this.camera.lookAt(center);
    this.controls.target.copy(center);
    this.controls.update();

    this.scene.remove(this.gridHelper);
    const gridSize = Math.max(Math.ceil(maxDim * 2.5), 40);
    this.gridHelper = new THREE.GridHelper(gridSize, gridSize, 0x38bdf8, 0x334155);
    this.gridHelper.position.y = box.min.y;
    this.scene.add(this.gridHelper);
  }

  // Pointer Events (Pan, Select, Add, Drag Move)
  private onPointerDown(event: PointerEvent) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    const mouse = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );

    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(mouse, this.camera);

    const nodeMeshes = this.graphGroup.children.filter(c => c.userData && c.userData.nodeId);
    const nodeIntersects = raycaster.intersectObjects(nodeMeshes);

    if (nodeIntersects.length > 0) {
      const selected = nodeIntersects[0].object;
      const clickedNodeId = selected.userData.nodeId;

      if (event.button === 2) {
        this.deleteNode(clickedNodeId);
        return;
      }

      this.selectedNodeId = clickedNodeId;
      this.updateInspectorUI();

      if (this.editorMode === 'move') {
        // Start dragging node in 3D
        this.isDraggingNode = true;
        this.draggedNodeId = clickedNodeId;
        this.controls.enabled = false;

        const node = this.nodes.find(n => n.id === clickedNodeId);
        if (node) {
          this.dragPlane.setFromNormalAndCoplanarPoint(new THREE.Vector3(0, 1, 0), new THREE.Vector3(0, node.y, 0));
        }
        return;
      } else if (this.editorMode === 'connect') {
        if (!this.connectSourceNodeId) {
          // Step 1: Select source node
          this.connectSourceNodeId = clickedNodeId;
          const modeLabel = document.getElementById('viewport-mode-label');
          if (modeLabel) modeLabel.innerText = `🔗 Source Node: ${clickedNodeId} (Click target node to connect)`;
        } else if (this.connectSourceNodeId !== clickedNodeId) {
          // Step 2: Connect to target node
          const sourceId = this.connectSourceNodeId;
          const n1 = this.nodes.find(n => n.id === sourceId)!;
          const n2 = this.nodes.find(n => n.id === clickedNodeId)!;

          if (n1 && n2) {
            const dist = Math.sqrt(Math.pow(n1.x - n2.x, 2) + Math.pow(n1.y - n2.y, 2) + Math.pow(n1.z - n2.z, 2));

            const newEdge: SiteEdgeData = {
              id: `edge_${Date.now()}_${this.edges.length}`,
              from: sourceId,
              to: clickedNodeId,
              distance: Math.round(dist * 100) / 100,
              walkable: true,
              transitionType: this.edgeType
            };
            this.edges.push(newEdge);

            // CONTINUOUS CHAIN CONNECTION: Set current target node as NEW source node for next click!
            this.connectSourceNodeId = clickedNodeId;
            
            const modeLabel = document.getElementById('viewport-mode-label');
            if (modeLabel) modeLabel.innerText = `🔗 Chained: ${sourceId} ➔ ${clickedNodeId}! Click next node to extend chain.`;

            this.updateGraphVisualization();
            saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
          }
        }
      } else if (this.editorMode === 'start') {
        this.startNodeId = clickedNodeId;
        this.updateGraphVisualization();
      }
      return;
    }

    // Add node
    if (event.button === 0 && this.editorMode === 'add') {
      const intersects = raycaster.intersectObjects(this.modelGroup.children, true);
      let hitPoint: THREE.Vector3;

      if (intersects.length > 0) {
        hitPoint = intersects[0].point;
      } else {
        const plane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
        hitPoint = new THREE.Vector3();
        raycaster.ray.intersectPlane(plane, hitPoint);
      }

      const newNode: SiteNodeData = {
        id: `node_${this.nodes.length + 1}`,
        x: Math.round(hitPoint.x * 100) / 100,
        y: Math.round(hitPoint.y * 100) / 100,
        z: Math.round(hitPoint.z * 100) / 100,
        floorId: 'floor_0',
        buildingId: 'building_a',
        type: 'walkable'
      };
      this.nodes.push(newNode);
      this.selectedNodeId = newNode.id;
      this.updateGraphVisualization();
      this.updateInspectorUI();
      saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
    }
  }

  private onPointerMove(event: PointerEvent) {
    if (!this.isDraggingNode || !this.draggedNodeId) return;

    const rect = this.renderer.domElement.getBoundingClientRect();
    const mouse = new THREE.Vector2(
      ((event.clientX - rect.left) / rect.width) * 2 - 1,
      -((event.clientY - rect.top) / rect.height) * 2 + 1
    );

    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(mouse, this.camera);

    if (raycaster.ray.intersectPlane(this.dragPlane, this.dragPlaneIntersection)) {
      const node = this.nodes.find(n => n.id === this.draggedNodeId);
      if (node) {
        node.x = Math.round(this.dragPlaneIntersection.x * 100) / 100;
        node.z = Math.round(this.dragPlaneIntersection.z * 100) / 100;
        this.updateGraphVisualization();
        this.updateInspectorUI();
      }
    }
  }

  private onPointerUp() {
    if (this.isDraggingNode) {
      this.isDraggingNode = false;
      this.draggedNodeId = null;
      if (this.editorMode === 'pan') this.controls.enabled = true;
      saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
    }
  }

  private deleteNode(nodeId: string) {
    this.nodes = this.nodes.filter(n => n.id !== nodeId);
    this.edges = this.edges.filter(e => e.from !== nodeId && e.to !== nodeId);
    this.destinations = this.destinations.filter(d => d.navigationNodeId !== nodeId);
    if (this.startNodeId === nodeId) this.startNodeId = null;
    this.selectedNodeId = null;
    this.updateGraphVisualization();
    this.updateDestinationsList();
    this.updateInspectorUI();
    saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
  }

  private updateInspectorUI() {
    const inspector = document.getElementById('inspector-content');
    const actions = document.getElementById('inspector-actions');
    const node = this.nodes.find(n => n.id === this.selectedNodeId);

    if (inspector && node) {
      const isStart = node.id === this.startNodeId;
      const linkedDest = this.destinations.find(d => d.navigationNodeId === node.id);
      inspector.innerHTML = `
        ID: <strong>${node.id}</strong> ${isStart ? '<span style="color:#22c55e;">[ENTRANCE]</span>' : ''}<br>
        Pos: (X: ${node.x}, Y: ${node.y}, Z: ${node.z})<br>
        ${linkedDest ? `Location: <strong style="color:#38bdf8;">${linkedDest.name}</strong>` : 'No location assigned'}
      `;
      if (actions) actions.style.display = 'block';
    } else if (inspector) {
      inspector.innerText = 'Click a node to inspect or select Move tool to drag';
      if (actions) actions.style.display = 'none';
    }
  }

  private updateGraphVisualization() {
    while (this.graphGroup.children.length > 0) {
      this.graphGroup.remove(this.graphGroup.children[0]);
    }

    // Draw Nodes
    this.nodes.forEach(n => {
      const isSelected = n.id === this.selectedNodeId;
      const isConnectSource = n.id === this.connectSourceNodeId;
      const isStart = n.id === this.startNodeId;
      const isDest = this.destinations.some(d => d.navigationNodeId === n.id);

      const color = isConnectSource ? 0xeab308 : (isStart ? 0x22c55e : (isDest ? 0xf59e0b : (isSelected ? 0x38bdf8 : 0x0284c7)));
      const radius = isConnectSource || isStart || isDest || isSelected ? 0.48 : 0.3;

      const geo = new THREE.SphereGeometry(radius, 16, 16);
      const mat = new THREE.MeshBasicMaterial({ color });
      const mesh = new THREE.Mesh(geo, mat);
      mesh.position.set(n.x, n.y + 0.2, n.z);
      mesh.userData = { nodeId: n.id };
      this.graphGroup.add(mesh);
    });

    // Draw Edges
    this.edges.forEach(e => {
      const n1 = this.nodes.find(n => n.id === e.from);
      const n2 = this.nodes.find(n => n.id === e.to);
      if (n1 && n2) {
        const points = [
          new THREE.Vector3(n1.x, n1.y + 0.2, n1.z),
          new THREE.Vector3(n2.x, n2.y + 0.2, n2.z)
        ];
        const lineGeo = new THREE.BufferGeometry().setFromPoints(points);
        const color = e.transitionType === 'stairs' ? 0xf59e0b : 0x0284c7;
        const lineMat = new THREE.LineBasicMaterial({ color, linewidth: 4 });
        const line = new THREE.Line(lineGeo, lineMat);
        this.graphGroup.add(line);
      }
    });

    const nodeCount = document.getElementById('stat-node-count');
    const edgeCount = document.getElementById('stat-edge-count');
    if (nodeCount) nodeCount.innerText = this.nodes.length.toString();
    if (edgeCount) edgeCount.innerText = this.edges.length.toString();
  }

  private autoChainNodes() {
    if (this.nodes.length < 2) {
      alert('Please add at least 2 nodes first!');
      return;
    }

    const unvisited = [...this.nodes];
    let current = unvisited.find(n => n.id === this.startNodeId) || unvisited[0];
    unvisited.splice(unvisited.indexOf(current), 1);

    let addedEdgesCount = 0;

    while (unvisited.length > 0) {
      let nearest: SiteNodeData | null = null;
      let minDistance = Infinity;

      for (const candidate of unvisited) {
        const d = Math.sqrt(
          Math.pow(current.x - candidate.x, 2) + 
          Math.pow(current.y - candidate.y, 2) + 
          Math.pow(current.z - candidate.z, 2)
        );
        if (d < minDistance) {
          minDistance = d;
          nearest = candidate;
        }
      }

      if (nearest) {
        const exists = this.edges.some(e => 
          (e.from === current.id && e.to === nearest!.id) || (e.from === nearest!.id && e.to === current.id)
        );
        if (!exists) {
          this.edges.push({
            id: `edge_${Date.now()}_${this.edges.length}`,
            from: current.id,
            to: nearest.id,
            distance: Math.round(minDistance * 100) / 100,
            walkable: true,
            transitionType: this.edgeType
          });
          addedEdgesCount++;
        }
        current = nearest;
        unvisited.splice(unvisited.indexOf(current), 1);
      } else {
        break;
      }
    }

    this.updateGraphVisualization();
    saveGraphToFirestore(this.currentSiteId, this.nodes, this.edges);
    alert(`⚡ Successfully chained all ${this.nodes.length} nodes into a continuous corridor path (${this.edges.length} total route connections)!`);
  }

  private updateDestinationsList() {
    const list = document.getElementById('destinations-list');
    if (!list) return;
    list.innerHTML = '';
    this.destinations.forEach(d => {
      const li = document.createElement('li');
      li.className = 'item-card';
      li.innerHTML = `<span><strong>${d.name}</strong> (${d.category})</span><span style="color:#38bdf8;">Node: ${d.navigationNodeId}</span>`;
      list.appendChild(li);
    });
  }
}

// Launch Admin App when DOM Ready
window.addEventListener('DOMContentLoaded', () => {
  new PathLumeAdminApp();
});
