/** Maximum characters in a single tool response */
export const CHARACTER_LIMIT = 25_000;

/** Stitch API base endpoint */
export const STITCH_MCP_ENDPOINT = "https://stitch.googleapis.com/mcp";

/** Default Gemini model for generation */
export const DEFAULT_MODEL = "GEMINI_3_PRO";

/** Device types supported by Stitch */
export type DeviceType = "MOBILE" | "DESKTOP" | "TABLET" | "AGNOSTIC";

/** Model IDs available for generation */
export type ModelId = "GEMINI_3_PRO" | "GEMINI_3_FLASH";

/** Creative range for variant generation */
export type CreativeRange = "REFINE" | "EXPLORE" | "REIMAGINE";

/** Variant aspects that can be explored */
export type VariantAspect = "LAYOUT" | "COLOR_SCHEME" | "IMAGES" | "TEXT_FONT" | "TEXT_CONTENT";
