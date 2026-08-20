import { initializeApp, getApps, getApp } from 'firebase/app';
import { 
  getAuth, 
  signInWithEmailAndPassword, 
  signOut as firebaseSignOut, 
  onAuthStateChanged
} from 'firebase/auth';
import { 
  getFirestore, 
  doc, 
  getDoc, 
  setDoc, 
  collection, 
  getDocs, 
  deleteDoc, 
  serverTimestamp 
} from 'firebase/firestore';
import { 
  getStorage, 
  ref, 
  uploadBytes, 
  getDownloadURL 
} from 'firebase/storage';

// Default Firebase Configuration (overridable via environment)
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || "AIzaSyCL3I4VZc3GqCrOaME-OqLJKtDGwQF2kAY",
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || "pathlume-9d8e9.firebaseapp.com",
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || "pathlume-9d8e9",
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET || "pathlume-9d8e9.firebasestorage.app",
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID || "281154593388",
  appId: import.meta.env.VITE_FIREBASE_APP_ID || "1:281154593388:web:8d487de66e54ee10a2ee49"
};

const app = !getApps().length ? initializeApp(firebaseConfig) : getApp();
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);

// Data interfaces
export interface SiteMetadata {
  siteId: string;
  name: string;
  type: string;
  description: string;
  published: boolean;
  version: number;
  publishedAt?: number;
  updatedAt?: any;
  createdAt?: any;
  vps?: {
    serverUrl: string;
    mapId: string;
    frameRateHz: number;
  };
  calibration?: {
    scale: number;
    rotationY: number;
    offsetX: number;
    offsetZ: number;
  };
  modelUrl?: string;
}

export interface SiteNodeData {
  id: string;
  x: number;
  y: number;
  z: number;
  floorId: string;
  buildingId: string;
  type: string;
}

export interface SiteEdgeData {
  id?: string;
  from: string;
  to: string;
  distance: number;
  walkable: boolean;
  transitionType: string;
}

export interface SiteDestinationData {
  id: string;
  name: string;
  category: string;
  buildingId?: string;
  floorId?: string;
  navigationNodeId: string;
}

// Authentication Helpers
export function subscribeAuthState(callback: (user: any) => void) {
  return onAuthStateChanged(auth, callback);
}

export async function loginAdmin(email: string, pass: string): Promise<any> {
  const credential = await signInWithEmailAndPassword(auth, email, pass);
  return credential.user;
}

export async function logoutAdmin(): Promise<void> {
  await firebaseSignOut(auth);
}

// Firestore Operations
export async function getSiteFromFirestore(siteId: string): Promise<{
  metadata: SiteMetadata | null;
  nodes: SiteNodeData[];
  edges: SiteEdgeData[];
  destinations: SiteDestinationData[];
}> {
  try {
    const siteRef = doc(db, 'sites', siteId);
    const siteSnap = await getDoc(siteRef);
    if (!siteSnap.exists()) {
      return { metadata: null, nodes: [], edges: [], destinations: [] };
    }

    const metadata = siteSnap.data() as SiteMetadata;

    // Subcollections
    const nodesSnap = await getDocs(collection(db, `sites/${siteId}/nodes`));
    const nodes: SiteNodeData[] = nodesSnap.docs.map((d: any) => ({ id: d.id, ...d.data() } as SiteNodeData));

    const edgesSnap = await getDocs(collection(db, `sites/${siteId}/edges`));
    const edges: SiteEdgeData[] = edgesSnap.docs.map((d: any) => ({ id: d.id, ...d.data() } as SiteEdgeData));

    const destsSnap = await getDocs(collection(db, `sites/${siteId}/destinations`));
    const destinations: SiteDestinationData[] = destsSnap.docs.map((d: any) => ({ id: d.id, ...d.data() } as SiteDestinationData));

    return { metadata, nodes, edges, destinations };
  } catch (error) {
    console.error('Error getting site from Firestore:', error);
    throw error;
  }
}

export async function saveSiteMetadataToFirestore(metadata: Partial<SiteMetadata> & { siteId: string }): Promise<void> {
  const siteRef = doc(db, 'sites', metadata.siteId);
  await setDoc(siteRef, {
    ...metadata,
    updatedAt: serverTimestamp()
  }, { merge: true });
}

export async function saveGraphToFirestore(
  siteId: string, 
  nodes: SiteNodeData[], 
  edges: SiteEdgeData[]
): Promise<void> {
  // Clear & save nodes
  const nodesColRef = collection(db, `sites/${siteId}/nodes`);
  const existingNodes = await getDocs(nodesColRef);
  for (const d of existingNodes.docs) {
    await deleteDoc(d.ref);
  }
  for (const node of nodes) {
    await setDoc(doc(db, `sites/${siteId}/nodes`, node.id), node);
  }

  // Clear & save edges
  const edgesColRef = collection(db, `sites/${siteId}/edges`);
  const existingEdges = await getDocs(edgesColRef);
  for (const d of existingEdges.docs) {
    await deleteDoc(d.ref);
  }
  for (let i = 0; i < edges.length; i++) {
    const edgeId = edges[i].id || `edge_${i + 1}_${edges[i].from}_${edges[i].to}`;
    await setDoc(doc(db, `sites/${siteId}/edges`, edgeId), { ...edges[i], id: edgeId });
  }
}

export async function saveDestinationsToFirestore(siteId: string, destinations: SiteDestinationData[]): Promise<void> {
  const destColRef = collection(db, `sites/${siteId}/destinations`);
  const existing = await getDocs(destColRef);
  for (const d of existing.docs) {
    await deleteDoc(d.ref);
  }
  for (const dest of destinations) {
    await setDoc(doc(db, `sites/${siteId}/destinations`, dest.id), dest);
  }
}

// Storage Operations
export async function uploadGLBToStorage(siteId: string, version: number, file: File): Promise<string> {
  const storagePath = `sites/${siteId}/models/v${version}/${file.name}`;
  const fileRef = ref(storage, storagePath);
  await uploadBytes(fileRef, file, { contentType: 'model/gltf-binary' });
  const downloadUrl = await getDownloadURL(fileRef);
  return downloadUrl;
}

// Publish Site & Version
export async function publishSiteInFirestore(
  siteId: string, 
  currentVersion: number, 
  nodes: SiteNodeData[], 
  edges: SiteEdgeData[], 
  destinations: SiteDestinationData[], 
  metadata: SiteMetadata
): Promise<number> {
  const nextVersion = (currentVersion || 0) + 1;
  const publishedAt = Date.now();

  const publishedSiteData = {
    ...metadata,
    version: nextVersion,
    published: true,
    publishedAt,
    navigationGraph: { nodes, edges },
    destinations
  };

  // Always save snapshot to localStorage for reliable instant publishing
  try {
    localStorage.setItem(`pathlume_published_${siteId}`, JSON.stringify(publishedSiteData));
    localStorage.setItem(`pathlume_published_${siteId}_v${nextVersion}`, JSON.stringify(publishedSiteData));
  } catch (e) {
    console.warn('localStorage publish backup error:', e);
  }

  try {
    const firestoreData = {
      ...publishedSiteData,
      updatedAt: serverTimestamp()
    };

    const firestoreWrites = Promise.all([
      setDoc(doc(db, 'sites', siteId), firestoreData, { merge: true }),
      setDoc(doc(db, `sites/${siteId}/versions`, `v${nextVersion}`), firestoreData),
      setDoc(doc(db, 'publishedSites', siteId), firestoreData)
    ]);

    const timeout = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Firestore network sync timeout')), 2500)
    );

    await Promise.race([firestoreWrites, timeout]);
  } catch (err: any) {
    console.warn('Firestore publish notice (saved to local storage):', err.message);
  }

  return nextVersion;
}
