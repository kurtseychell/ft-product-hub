#!/usr/bin/env node
/**
 * Stitch MCP Server — Product Hub Edition
 *
 * Exposes Google Stitch AI UI design tools via MCP so Claude can
 * generate, iterate, and export UI screens directly from text prompts.
 * Tailored for the Product Hub backoffice project with a batch-generate
 * workflow tool.
 */

import "dotenv/config";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import {
  createProject,
  listProjects,
  generateScreen,
  editScreen,
  generateVariants,
  getScreenContent,
  listScreens,
  createDesignSystem,
  applyDesignSystem,
  listAvailableTools,
} from "./stitch-client.js";
import { CHARACTER_LIMIT } from "./constants.js";

// ─── Helpers ────────────────────────────────────────────────────────────────

function handleError(error: unknown): { content: Array<{ type: "text"; text: string }>; isError: true } {
  const message = error instanceof Error ? error.message : String(error);
  return {
    isError: true,
    content: [{ type: "text" as const, text: `Error: ${message}` }],
  };
}

function textResult(text: string) {
  const truncated =
    text.length > CHARACTER_LIMIT
      ? text.slice(0, CHARACTER_LIMIT) + "\n\n[Response truncated — use pagination or filters]"
      : text;
  return { content: [{ type: "text" as const, text: truncated }] };
}

// ─── Server ─────────────────────────────────────────────────────────────────

const server = new McpServer({
  name: "stitch-mcp-server",
  version: "1.0.0",
});

// ─── Tool: stitch_create_project ────────────────────────────────────────────

server.registerTool(
  "stitch_create_project",
  {
    title: "Create Stitch Project",
    description: `Create a new Google Stitch project. A project is a container for UI design screens.
Returns the project ID which is needed for all subsequent screen operations.

Args:
  - name (string): Human-readable project name (e.g. "Product Hub Backoffice")

Returns: { projectId, name }`,
    inputSchema: {
      name: z.string().min(1).max(200).describe("Name for the new Stitch project"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async ({ name }) => {
    try {
      const project = await createProject(name);
      return textResult(
        `# Project Created\n\n- **Project ID:** ${project.id}\n- **Name:** ${project.name}`
      );
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_list_projects ─────────────────────────────────────────────

server.registerTool(
  "stitch_list_projects",
  {
    title: "List Stitch Projects",
    description: `List all Google Stitch projects accessible to the authenticated user.
Returns project IDs and names.

Returns: Array of { projectId, name }`,
    inputSchema: {},
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async () => {
    try {
      const projects = await listProjects();
      if (projects.length === 0) {
        return textResult("No projects found. Create one with `stitch_create_project`.");
      }
      const lines = ["# Stitch Projects\n"];
      for (const p of projects) {
        lines.push(`- **${p.name ?? "Untitled"}** — ID: \`${p.id}\``);
      }
      return textResult(lines.join("\n"));
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_generate_screen ───────────────────────────────────────────

server.registerTool(
  "stitch_generate_screen",
  {
    title: "Generate UI Screen",
    description: `Generate a single UI screen from a text prompt inside a Stitch project.
The prompt should describe the UI you want — layout, components, content, colours, etc.

Args:
  - project_id (string): The Stitch project ID to generate into
  - prompt (string): Detailed text description of the UI screen to generate
  - device_type (optional): "DESKTOP" | "MOBILE" | "TABLET" | "AGNOSTIC" (default: DESKTOP)
  - model_id (optional): "GEMINI_3_PRO" | "GEMINI_3_FLASH" (default: GEMINI_3_PRO)

Returns: { screenId, name, projectId }`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      prompt: z.string().min(10).max(10_000).describe("Text description of the UI screen to generate"),
      device_type: z
        .enum(["MOBILE", "DESKTOP", "TABLET", "AGNOSTIC"])
        .default("DESKTOP")
        .describe("Target device type"),
      model_id: z
        .enum(["GEMINI_3_PRO", "GEMINI_3_FLASH"])
        .optional()
        .describe("Gemini model to use for generation"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async ({ project_id, prompt, device_type, model_id }) => {
    try {
      const screen = await generateScreen(project_id, prompt, device_type, model_id);
      return textResult(
        `# Screen Generated\n\n- **Screen ID:** ${screen.id}\n- **Name:** ${screen.name}\n- **Project:** ${screen.projectId}\n\nUse \`stitch_get_screen_content\` to retrieve the HTML and screenshot.`
      );
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_edit_screen ───────────────────────────────────────────────

server.registerTool(
  "stitch_edit_screen",
  {
    title: "Edit UI Screen",
    description: `Edit an existing screen by applying a modification prompt.
Use this to refine a previously generated screen (e.g. "Make the sidebar icons larger").

Args:
  - project_id (string): The Stitch project ID
  - screen_id (string): The screen ID to edit
  - prompt (string): Modification instructions
  - device_type (optional): "DESKTOP" | "MOBILE" | "TABLET" | "AGNOSTIC"
  - model_id (optional): "GEMINI_3_PRO" | "GEMINI_3_FLASH"

Returns: { screenId, name, projectId }`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      screen_id: z.string().min(1).describe("Screen ID to edit"),
      prompt: z.string().min(5).max(5_000).describe("Modification instructions"),
      device_type: z
        .enum(["MOBILE", "DESKTOP", "TABLET", "AGNOSTIC"])
        .default("DESKTOP")
        .describe("Target device type"),
      model_id: z
        .enum(["GEMINI_3_PRO", "GEMINI_3_FLASH"])
        .optional()
        .describe("Gemini model to use"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async ({ project_id, screen_id, prompt, device_type, model_id }) => {
    try {
      const screen = await editScreen(project_id, screen_id, prompt, device_type, model_id);
      return textResult(
        `# Screen Edited\n\n- **Screen ID:** ${screen.id}\n- **Project:** ${screen.projectId}`
      );
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_generate_variants ─────────────────────────────────────────

server.registerTool(
  "stitch_generate_variants",
  {
    title: "Generate Screen Variants",
    description: `Generate design variants for an existing screen to explore alternative layouts, colour schemes, or content.

Args:
  - project_id (string): Stitch project ID
  - screen_id (string): Base screen ID to create variants from
  - prompt (string): Direction for variants
  - variant_count (optional, 1-5, default 3): Number of variants
  - creative_range (optional): "REFINE" | "EXPLORE" | "REIMAGINE" (default: EXPLORE)
  - aspects (optional): Array of "LAYOUT" | "COLOR_SCHEME" | "IMAGES" | "TEXT_FONT" | "TEXT_CONTENT"

Returns: Array of variant screen objects`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      screen_id: z.string().min(1).describe("Base screen ID"),
      prompt: z.string().min(5).max(5_000).describe("Direction for variant exploration"),
      variant_count: z.number().int().min(1).max(5).default(3).describe("Number of variants to generate"),
      creative_range: z
        .enum(["REFINE", "EXPLORE", "REIMAGINE"])
        .default("EXPLORE")
        .describe("How far to deviate from the original"),
      aspects: z
        .array(z.enum(["LAYOUT", "COLOR_SCHEME", "IMAGES", "TEXT_FONT", "TEXT_CONTENT"]))
        .optional()
        .describe("Which design aspects to vary"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async ({ project_id, screen_id, prompt, variant_count, creative_range, aspects }) => {
    try {
      const variants = await generateVariants(
        project_id,
        screen_id,
        prompt,
        { variantCount: variant_count, creativeRange: creative_range, aspects },
      );
      const lines = [`# ${variants.length} Variants Generated\n`];
      for (let i = 0; i < variants.length; i++) {
        lines.push(`${i + 1}. **${variants[i].name ?? `Variant ${i + 1}`}** — ID: \`${variants[i].id}\``);
      }
      return textResult(lines.join("\n"));
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_get_screen_content ────────────────────────────────────────

server.registerTool(
  "stitch_get_screen_content",
  {
    title: "Get Screen HTML & Screenshot",
    description: `Retrieve the HTML code and screenshot image URL for a generated screen.
Use this after generating or editing a screen to get its output assets.

Args:
  - project_id (string): Stitch project ID
  - screen_id (string): Screen ID

Returns: { htmlUrl, imageUrl }`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      screen_id: z.string().min(1).describe("Screen ID"),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async ({ project_id, screen_id }) => {
    try {
      const content = await getScreenContent(project_id, screen_id);
      return textResult(
        `# Screen Content\n\n- **HTML Download:** ${content.htmlUrl}\n- **Screenshot Download:** ${content.imageUrl}`
      );
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_list_screens ──────────────────────────────────────────────

server.registerTool(
  "stitch_list_screens",
  {
    title: "List Project Screens",
    description: `List all screens in a Stitch project.

Args:
  - project_id (string): Stitch project ID

Returns: Array of { screenId, name }`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
    },
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async ({ project_id }) => {
    try {
      const screens = await listScreens(project_id);
      if (screens.length === 0) {
        return textResult("No screens in this project yet. Use `stitch_generate_screen` to create one.");
      }
      const lines = [`# Screens (${screens.length})\n`];
      for (const s of screens) {
        lines.push(`- **${s.name ?? "Untitled"}** — ID: \`${s.id}\``);
      }
      return textResult(lines.join("\n"));
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_create_design_system ──────────────────────────────────────

server.registerTool(
  "stitch_create_design_system",
  {
    title: "Create Design System",
    description: `Create a design system (theme) for a Stitch project. This sets the visual identity that can be applied to generated screens.

Args:
  - project_id (string): Stitch project ID
  - primary_color (optional): Primary brand colour, e.g. "#4F46E5"
  - accent_color (optional): Accent colour
  - font_family (optional): Font family name, e.g. "Inter"
  - border_radius (optional): Border radius, e.g. "8px"
  - style (optional): Style description, e.g. "clean, modern SaaS"

Returns: { designSystemId }`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      primary_color: z.string().optional().describe("Primary brand colour hex"),
      accent_color: z.string().optional().describe("Accent colour hex"),
      font_family: z.string().optional().describe("Font family name"),
      border_radius: z.string().optional().describe("Border radius value"),
      style: z.string().optional().describe("Style description"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async ({ project_id, primary_color, accent_color, font_family, border_radius, style }) => {
    try {
      const ds = await createDesignSystem(project_id, {
        primaryColor: primary_color,
        accentColor: accent_color,
        fontFamily: font_family,
        borderRadius: border_radius,
        style,
      });
      return textResult(
        `# Design System Created\n\n- **ID:** ${ds.id}\n- **Project:** ${project_id}\n\nUse \`stitch_apply_design_system\` to apply it to screens.`
      );
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_apply_design_system ───────────────────────────────────────

server.registerTool(
  "stitch_apply_design_system",
  {
    title: "Apply Design System to Screens",
    description: `Apply a design system (theme) to one or more screens in a project.

Args:
  - project_id (string): Stitch project ID
  - design_system_id (string): Design system ID to apply
  - screen_ids (string[]): Array of screen IDs to apply the theme to

Returns: Confirmation message`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      design_system_id: z.string().min(1).describe("Design system ID"),
      screen_ids: z.array(z.string().min(1)).min(1).describe("Screen IDs to apply the design system to"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async ({ project_id, design_system_id, screen_ids }) => {
    try {
      await applyDesignSystem(project_id, design_system_id, screen_ids);
      return textResult(
        `# Design System Applied\n\nApplied design system \`${design_system_id}\` to ${screen_ids.length} screen(s).`
      );
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_batch_generate ────────────────────────────────────────────
// This is the high-level workflow tool tailored for Product Hub.

server.registerTool(
  "stitch_batch_generate",
  {
    title: "Batch Generate Multiple Screens",
    description: `Generate multiple UI screens from an array of prompts in a single operation.
This is ideal for generating an entire set of Product Hub screens at once.

Each prompt in the array will be generated as a separate screen in the project.
The design system (if provided) will be applied after all screens are generated.

Args:
  - project_id (string): Stitch project ID
  - prompts (array): Array of { name, prompt } objects, one per screen
  - device_type (optional): "DESKTOP" | "MOBILE" | "TABLET" | "AGNOSTIC"
  - design_system_id (optional): Apply this design system to all generated screens

Returns: Summary of generated screens with their IDs`,
    inputSchema: {
      project_id: z.string().min(1).describe("Stitch project ID"),
      prompts: z
        .array(
          z.object({
            name: z.string().min(1).describe("Screen name for identification"),
            prompt: z.string().min(10).max(10_000).describe("Text prompt for this screen"),
          })
        )
        .min(1)
        .max(25)
        .describe("Array of screen prompts to generate"),
      device_type: z
        .enum(["MOBILE", "DESKTOP", "TABLET", "AGNOSTIC"])
        .default("DESKTOP")
        .describe("Target device type for all screens"),
      design_system_id: z
        .string()
        .optional()
        .describe("Design system ID to apply to all generated screens"),
    },
    annotations: {
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: true,
    },
  },
  async ({ project_id, prompts, device_type, design_system_id }) => {
    try {
      const results: Array<{ name: string; screenId: string; success: boolean; error?: string }> = [];

      for (const item of prompts) {
        try {
          const screen = await generateScreen(project_id, item.prompt, device_type);
          results.push({ name: item.name, screenId: screen.id, success: true });
        } catch (err) {
          results.push({
            name: item.name,
            screenId: "",
            success: false,
            error: err instanceof Error ? err.message : String(err),
          });
        }
      }

      // Apply design system if provided
      if (design_system_id) {
        const successIds = results.filter((r) => r.success).map((r) => r.screenId);
        if (successIds.length > 0) {
          try {
            await applyDesignSystem(project_id, design_system_id, successIds);
          } catch {
            // Non-fatal — report but don't fail the whole batch
          }
        }
      }

      const succeeded = results.filter((r) => r.success).length;
      const failed = results.filter((r) => !r.success).length;

      const lines = [
        `# Batch Generation Complete`,
        ``,
        `**${succeeded}** of **${prompts.length}** screens generated successfully${failed > 0 ? ` (${failed} failed)` : ""}.`,
        design_system_id ? `Design system \`${design_system_id}\` applied to all successful screens.` : "",
        ``,
        `## Screens`,
        ``,
      ];

      for (const r of results) {
        if (r.success) {
          lines.push(`- ✅ **${r.name}** — ID: \`${r.screenId}\``);
        } else {
          lines.push(`- ❌ **${r.name}** — Failed: ${r.error}`);
        }
      }

      return textResult(lines.join("\n"));
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Tool: stitch_diagnostics ───────────────────────────────────────────────

server.registerTool(
  "stitch_diagnostics",
  {
    title: "Stitch Connection Diagnostics",
    description: `Test the connection to the Stitch API and list available tools.
Use this to verify the API key is valid and see what operations are available.

Returns: Connection status and list of available Stitch MCP tools`,
    inputSchema: {},
    annotations: {
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: true,
    },
  },
  async () => {
    try {
      const hasKey = !!process.env.STITCH_API_KEY;
      if (!hasKey) {
        return textResult(
          "# Diagnostics\n\n❌ **STITCH_API_KEY** environment variable is not set. Please configure it in your .env file."
        );
      }

      const tools = await listAvailableTools();
      const lines = [
        "# Stitch Diagnostics",
        "",
        "✅ **API Key:** Configured",
        `✅ **Available Tools:** ${tools.length}`,
        "",
        "## Tools",
        "",
      ];
      for (const t of tools) {
        lines.push(`- \`${t}\``);
      }
      return textResult(lines.join("\n"));
    } catch (e) {
      return handleError(e);
    }
  }
);

// ─── Start Server ───────────────────────────────────────────────────────────

async function main() {
  if (!process.env.STITCH_API_KEY) {
    console.error(
      "WARNING: STITCH_API_KEY environment variable is not set. " +
        "Stitch API calls will fail. Set it in your .env file or environment."
    );
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("stitch-mcp-server running via stdio");
}

main().catch((error) => {
  console.error("Fatal server error:", error);
  process.exit(1);
});
