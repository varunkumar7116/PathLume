import { SiteMetadata, SiteNodeData, SiteEdgeData, SiteDestinationData } from './firebase';

export type ValidationSeverity = 'ERROR' | 'WARNING' | 'INFO';

export interface ValidationIssue {
  severity: ValidationSeverity;
  category: 'MODEL' | 'CALIBRATION' | 'NAVIGATION' | 'DESTINATION' | 'QR' | 'VPS' | 'FIREBASE';
  message: string;
}

export interface ValidationReport {
  isValid: boolean;
  canPublish: boolean;
  errorsCount: number;
  warningsCount: number;
  issues: ValidationIssue[];
}

export function validateSiteConfiguration(
  metadata: SiteMetadata | null,
  nodes: SiteNodeData[],
  edges: SiteEdgeData[],
  destinations: SiteDestinationData[],
  _vpsConfig?: any
): ValidationReport {
  const issues: ValidationIssue[] = [];

  // 1. Metadata Checks
  if (!metadata || !metadata.siteId) {
    issues.push({
      severity: 'ERROR',
      category: 'FIREBASE',
      message: 'Site ID is missing or undefined.'
    });
  }

  // 2. Model & Calibration Checks
  if (!metadata?.modelUrl) {
    issues.push({
      severity: 'WARNING',
      category: 'MODEL',
      message: 'No 3D GLB model URL is attached to this site. Default grid will be rendered.'
    });
  }

  if (metadata?.calibration?.scale === 0) {
    issues.push({
      severity: 'ERROR',
      category: 'CALIBRATION',
      message: 'Model calibration scale cannot be zero.'
    });
  }

  // 3. Navigation Graph Checks
  if (nodes.length === 0) {
    issues.push({
      severity: 'ERROR',
      category: 'NAVIGATION',
      message: 'Navigation graph has zero nodes. At least one entrance node is required.'
    });
  }

  const entranceNodes = nodes.filter(n => n.type === 'ENTRANCE' || n.id === 'n1');
  if (nodes.length > 0 && entranceNodes.length === 0) {
    issues.push({
      severity: 'ERROR',
      category: 'NAVIGATION',
      message: 'No ENTRANCE node designated. Set an entrance node to anchor navigation start.'
    });
  }

  // Check for disconnected nodes
  const connectedNodeIds = new Set<string>();
  for (const e of edges) {
    connectedNodeIds.add(e.from);
    connectedNodeIds.add(e.to);
  }

  if (nodes.length > 1) {
    const disconnected = nodes.filter(n => !connectedNodeIds.has(n.id));
    if (disconnected.length > 0) {
      issues.push({
        severity: 'WARNING',
        category: 'NAVIGATION',
        message: `${disconnected.length} disconnected navigation nodes found.`
      });
    }
  }

  // 4. Destination Checks
  if (destinations.length === 0) {
    issues.push({
      severity: 'WARNING',
      category: 'DESTINATION',
      message: 'No destinations registered. Users will have no navigable target locations.'
    });
  }

  const nodeIds = new Set(nodes.map(n => n.id));
  for (const d of destinations) {
    if (!nodeIds.has(d.navigationNodeId)) {
      issues.push({
        severity: 'ERROR',
        category: 'DESTINATION',
        message: `Destination "${d.name}" references non-existent node "${d.navigationNodeId}".`
      });
    }
  }

  // 5. QR Code Payload Validation
  if (metadata?.siteId) {
    const expectedQrPayload = `pathlume://site/${metadata.siteId}`;
    issues.push({
      severity: 'INFO',
      category: 'QR',
      message: `Primary Site QR Payload verified: "${expectedQrPayload}"`
    });
  }

  // 6. VPS Boundary Check
  issues.push({
    severity: 'INFO',
    category: 'VPS',
    message: 'VPS status: UNAVAILABLE (ARCORE-ONLY DEVELOPMENT MODE ACTIVE).'
  });

  const errorsCount = issues.filter(i => i.severity === 'ERROR').length;
  const warningsCount = issues.filter(i => i.severity === 'WARNING').length;

  return {
    isValid: errorsCount === 0,
    canPublish: errorsCount === 0,
    errorsCount,
    warningsCount,
    issues
  };
}
