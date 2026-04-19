/**
 * Wrapper around the @google/stitch-sdk that provides a unified
 * interface for all Stitch operations used by the MCP tools.
 */

import type { DeviceType, ModelId, CreativeRange, VariantAspect } from "./constants.js";

// ─── Types ──────────────────────────────────────────────────────────────────
export interface StitchProject {
  id: string;
  name?: string;
}

export interface StitchScreen {
  id: string;
  name?: string;
  projectId: string;
}

export interface ScreenContent {
  htmlUrl: string;
  imageUrl: string;
}

export interface VariantOptions {
  variantCount?: number;
  creativeRange?: CreativeRange;
  aspects?: VariantAspect[];
}

export interface DesignSystemConfig {
  primaryColor?: string;
  accentColor?: string;
  fontFamily?: string;
  borderRadius?: string;
  style?: string;
}

// ─── Client ─────────────────────────────────────────────────────────────────
let stitchModule: any = null;

async function getStitch(): Promise<any> {
  if (!stitchModule) {
    stitchModule = await import("@google/stitch-sdk");
  }
  return stitchModule;
}

/**
 * Create a new Stitch project.
 */
export async function createProject(name: string): Promise<StitchProject> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const result = await client.callTool("create_project", { name });
    return {
      id: result.projectId ?? result.id ?? "unknown",
      name,
    };
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * List all projects accessible to the authenticated user.
 */
export async function listProjects(): Promise<StitchProject[]> {
  const sdk = await getStitch();
  const stitch = sdk.stitch ?? sdk.default?.stitch;

  if (stitch?.projects) {
    const projects = await stitch.projects();
    return projects.map((p: any) => ({ id: p.id, name: p.name }));
  }

  // Fallback via tool client
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });
  try {
    const result = await client.callTool("list_projects", {});
    return (result.projects ?? []).map((p: any) => ({
      id: p.id ?? p.projectId,
      name: p.name,
    }));
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * Generate a screen from a text prompt inside a project.
 */
export async function generateScreen(
  projectId: string,
  prompt: string,
  deviceType: DeviceType = "DESKTOP",
  modelId?: ModelId
): Promise<StitchScreen> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const args: Record<string, unknown> = {
      projectId,
      prompt,
      deviceType,
    };
    if (modelId) args.modelId = modelId;

    const result = await client.callTool("generate_screen_from_text", args);
    return {
      id: result.screenId ?? result.id ?? "unknown",
      name: result.name ?? prompt.slice(0, 60),
      projectId,
    };
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * Edit an existing screen with a new prompt.
 */
export async function editScreen(
  projectId: string,
  screenId: string,
  prompt: string,
  deviceType: DeviceType = "DESKTOP",
  modelId?: ModelId
): Promise<StitchScreen> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const args: Record<string, unknown> = {
      projectId,
      screenId,
      prompt,
      deviceType,
    };
    if (modelId) args.modelId = modelId;

    const result = await client.callTool("edit_screen", args);
    return {
      id: result.screenId ?? screenId,
      name: result.name,
      projectId,
    };
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * Generate design variants for a screen.
 */
export async function generateVariants(
  projectId: string,
  screenId: string,
  prompt: string,
  options: VariantOptions = {},
  deviceType: DeviceType = "DESKTOP",
  modelId?: ModelId
): Promise<StitchScreen[]> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const args: Record<string, unknown> = {
      projectId,
      screenId,
      prompt,
      deviceType,
      variantCount: options.variantCount ?? 3,
      creativeRange: options.creativeRange ?? "EXPLORE",
    };
    if (options.aspects) args.aspects = options.aspects;
    if (modelId) args.modelId = modelId;

    const result = await client.callTool("generate_variants", args);
    const variants = result.variants ?? result.screens ?? [];
    return variants.map((v: any) => ({
      id: v.screenId ?? v.id,
      name: v.name,
      projectId,
    }));
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * Retrieve HTML code and screenshot URL for a screen.
 */
export async function getScreenContent(
  projectId: string,
  screenId: string
): Promise<ScreenContent> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const [htmlResult, imageResult] = await Promise.all([
      client.callTool("get_screen_code", { projectId, screenId }),
      client.callTool("get_screen_image", { projectId, screenId }),
    ]);

    return {
      htmlUrl: htmlResult.downloadUrl ?? htmlResult.html ?? "",
      imageUrl: imageResult.downloadUrl ?? imageResult.image ?? "",
    };
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * List all screens in a project.
 */
export async function listScreens(projectId: string): Promise<StitchScreen[]> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const result = await client.callTool("list_screens", { projectId });
    const screens = result.screens ?? [];
    return screens.map((s: any) => ({
      id: s.screenId ?? s.id,
      name: s.name,
      projectId,
    }));
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * Create or update a design system for a project.
 */
export async function createDesignSystem(
  projectId: string,
  config: DesignSystemConfig
): Promise<{ id: string }> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const result = await client.callTool("create_design_system", {
      projectId,
      ...config,
    });
    return { id: result.designSystemId ?? result.id ?? "default" };
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * Apply a design system to screens.
 */
export async function applyDesignSystem(
  projectId: string,
  designSystemId: string,
  screenIds: string[]
): Promise<void> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    await client.callTool("apply_design_system", {
      projectId,
      designSystemId,
      screenIds,
    });
  } finally {
    await client.close().catch(() => {});
  }
}

/**
 * List available MCP tools from the Stitch server (for diagnostics).
 */
export async function listAvailableTools(): Promise<string[]> {
  const sdk = await getStitch();
  const client = new sdk.StitchToolClient({
    apiKey: process.env.STITCH_API_KEY,
  });

  try {
    const tools = await client.listTools();
    return tools.map((t: any) => t.name ?? t);
  } finally {
    await client.close().catch(() => {});
  }
}
