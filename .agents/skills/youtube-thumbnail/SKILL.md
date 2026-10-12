---
name: youtube-thumbnail
description: Create, edit, or review YouTube thumbnails. Always use when a YouTube thumbnail or video cover is requested; keep the design restrained and preserve photographed people exactly.
---

# YouTube Thumbnail

Create a clear 16:9 thumbnail built around one idea. Favor hierarchy, curiosity,
and an instantly readable subject over visual noise.

## Core Rules

- Use a 1280 x 720 canvas unless the user requests another size.
- Communicate one idea with one dominant focal point.
- Prefer no text when the image communicates the idea. Otherwise use one short
  phrase, normally one to four words. Do not repeat the full video title.
- Keep colors natural and controlled. Do not globally oversaturate the image,
  crush shadows, clip highlights, or push skin tones toward orange or red.
- Preserve photographed people. Do not regenerate, beautify, reshape, repaint,
  relight, recolor, sharpen, smooth, or otherwise alter their face, skin, hair,
  body, expression, clothing, accessories, or silhouette.
- Allow only cropping, uniform scaling, positioning, and a natural drop shadow
  around a person. Do not add strokes, keylines, glows, halos, rim lights, or
  bright outlines around people.
- Never invent or replace a recognizable person when a source photo is
  provided. Use the original pixels.

## Workflow

1. Inspect the title, topic, source images, brand assets, and any reference
   thumbnails. Identify the single visual promise of the video. Before generating
   a background, ask for the PhotoCraft filename unless the user already
   supplied it. Use that basename with a `.pcraft` extension in
   `/media/drive/Video Production/YTthumbnails/`; do not invent a filename.
2. Select the simplest composition that communicates that promise:
   - one subject plus a contextual background;
   - one subject plus one supporting object; or
   - one strong object or scene with optional short text.
3. Establish hierarchy at small size. Make the main subject recognizable before
   adding secondary elements. Keep important content away from the bottom-right
   timestamp area and allow breathing room near every edge.
4. Lock any source person before generating or editing other elements. Generate
   the background or supporting graphics separately, then composite the original
   person over them. If exact pixel preservation cannot be guaranteed, do not
   send the person through a generative edit. As soon as the background is
   generated, import it into PhotoCraft and save the initial layered `.pcraft`
   document at the requested path before continuing the composition. Follow
   the native save checkpoint instructions below.
5. Add text only if it supplies information the image cannot. Use one bold,
   legible type style with strong contrast and minimal effects. Avoid stacked
   captions, tiny labels, punctuation clutter, and multiple competing fonts.
6. Apply restrained finishing. Use selective contrast and color separation
   instead of extreme saturation. For a person, use only a soft, neutral drop
   shadow with modest opacity and blur.
7. Save the editable document as `.pcraft` and export the final thumbnail as
   PNG, JPEG, or WebP at 1280 x 720.

## Image Tool Guidance

- Use the `photocraft` skill and `photocraft-cli` MCP tools for supported image
  inspection, layered assembly, editing, previews, and export. Discover command
  parameters before applying edits. If the connection or capability is missing,
  explain the limitation before selecting another tool; follow explicit user
  tool choices and higher-priority tool requirements.
- Inspect every supplied source image before editing it.
- Use image generation for new backgrounds, objects, textures, or complete
  thumbnails that contain no supplied person.
- Use PhotoCraft's supported non-generative compositing for supplied people. Keep the
  original person layer unchanged apart from crop, uniform scale, position, and
  drop shadow.
- Save the layered `.pcraft` document alongside the final image so the
  composition remains editable.
- When writing an image-generation prompt, explicitly request a clean 16:9
  composition, a restrained natural palette, realistic contrast, negative
  space for optional text, and no embedded typography unless the tool is meant
  to render the final text.
- Do not claim a person was preserved unless the final image was compared with
  the source at full size.

## Native Save Checkpoint

- Use `.pcraft` for every working-document save. Save
  `/media/drive/Video Production/YTthumbnails/<filename>.pcraft` through the
  PhotoCraft MCP's `doc_save` tool using its discovered schema.
- Check that the destination directory is available and within the MCP read
  and write roots before generating the background. If it is not, explain the
  missing mount or MCP configuration; do not silently save elsewhere or broaden
  access.
- Treat the supplied filename as a basename, not a path. If it would replace an
  existing file and replacement has not been authorized, ask for a different
  filename or permission to replace that file.
- Verify the initial `.pcraft` file exists and reopens in PhotoCraft with the
  expected canvas and background layer. Keep subsequent people, text, and
  supporting graphics on separate layers and update the same `.pcraft` file
  as the work progresses.
- Deliver the `.pcraft` working file alongside the final thumbnail and report
  a failed native save or verification as incomplete work, even if the generated
  background is available.

## Visual QA

Before delivery, inspect the full-resolution result and a small thumbnail-sized
preview. Confirm all of the following:

- The concept is understandable within roughly one second.
- The thumbnail contains one clear focal point and no unnecessary decoration.
- Text is absent or limited to one short, readable phrase.
- No person has changed relative to the source.
- People have no outline, glow, halo, rim light, or edge color; any separation
  comes only from a natural drop shadow.
- Saturation and contrast remain controlled, especially in skin tones and
  brand colors.
- The subject and text remain legible at small size and are not obstructed by
  the timestamp area.
- The final file is exactly 16:9 and has no accidental crop, padding, artifacts,
  or embedded watermark.

If any check fails, revise the thumbnail and inspect it again before presenting
the result.

## Delivery QA

Do not treat an internal sandbox path, generated preview reference, or claimed
export as a delivered file. Before finishing:

1. Confirm that the final image exists at a user-accessible local artifact path
   for the current task, using its configured output directory when available.
2. Verify the actual file type, dimensions, and size. When the file was copied
   from another local source, compare hashes to prove the artifact is complete.
3. Present the verified artifact with an absolute local path that the current
   Codex client can render or download.

Treat the task as partially complete and explain the blocker if the image is
visually finished but cannot be exposed as an accessible artifact.
