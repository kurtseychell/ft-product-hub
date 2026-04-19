# Stitch MCP Server — Product Hub Edition

An MCP (Model Context Protocol) server that connects Claude to **Google Stitch**, enabling AI-powered UI design generation directly from text prompts. Tailored for the Product Hub backoffice project.

## Quick Start

### 1. Install dependencies
```bash
cd stitch-mcp-server
npm install
npm run build
```

### 2. Configure your API key
Create a `.env` file (already present) with your Stitch API key:
```
STITCH_API_KEY=your-api-key-here
```

### 3. Connect to Claude Desktop / Claude Code

Add this to your MCP settings (e.g. `~/.claude/claude_desktop_config.json` or your Claude Code MCP config):

```json
{
  "mcpServers": {
    "stitch": {
      "command": "node",
      "args": ["dist/index.js"],
      "cwd": "/path/to/Modern AI Product Hub/stitch-mcp-server",
      "env": {
        "STITCH_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `stitch_create_project` | Create a new Stitch project |
| `stitch_list_projects` | List all accessible projects |
| `stitch_generate_screen` | Generate a single UI screen from a text prompt |
| `stitch_edit_screen` | Edit/refine an existing screen |
| `stitch_generate_variants` | Create design variants (layout, color, etc.) |
| `stitch_get_screen_content` | Get HTML & screenshot for a screen |
| `stitch_list_screens` | List all screens in a project |
| `stitch_create_design_system` | Create a visual theme/design system |
| `stitch_apply_design_system` | Apply a design system to screens |
| `stitch_batch_generate` | Generate multiple screens from an array of prompts |
| `stitch_diagnostics` | Test API connection and list available tools |

## Product Hub Workflow

The recommended workflow for generating all Product Hub screens:

1. **Create a project:** `stitch_create_project` → "Product Hub Backoffice"
2. **Set up design system:** `stitch_create_design_system` with indigo (#4F46E5) theme
3. **Batch generate screens:** `stitch_batch_generate` with all 19 prompts from the Stitch Prompts doc
4. **Refine individual screens:** `stitch_edit_screen` for adjustments
5. **Explore variants:** `stitch_generate_variants` for alternative designs
6. **Export assets:** `stitch_get_screen_content` for HTML and screenshots

## Architecture

```
stitch-mcp-server/
├── src/
│   ├── index.ts          # MCP server with all tool registrations
│   ├── stitch-client.ts  # Wrapper around @google/stitch-sdk
│   └── constants.ts      # Shared configuration
├── dist/                 # Built JavaScript (entry: dist/index.js)
├── .env                  # API key (gitignored)
├── package.json
└── tsconfig.json
```

The server uses **stdio transport** for local integration with Claude Desktop and Claude Code.
