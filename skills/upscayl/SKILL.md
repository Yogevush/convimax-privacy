---
name: upscayl
description: Enlarge and sharpen images on this Mac with Upscayl's local AI engine (upscayl-bin, Real-ESRGAN models) through scripts/upscale.sh. Use whenever the user wants to upscale, enlarge, sharpen, improve the resolution of, or "make bigger" one image or a whole folder of images (product photos, thumbnails, small or old photos, screenshots), or mentions Upscayl. Hebrew triggers - "תגדיל את התמונה", "להגדיל תמונות", "לשפר רזולוציה", "לחדד תמונה", "אפסקייל", "הגדלה פי 4", "תמונות מוצר גדולות". Runs offline on the Mac, writes new files, never touches originals.
---

# Upscayl - local AI image upscaling

Upscayl is a free, open-source desktop app. Its engine is a command-line binary
(`upscayl-bin`) that ships inside the app together with seven AI models. This skill
runs that engine directly, so you can upscale images for the user without opening
the app. Everything runs on the Mac's own GPU. Nothing is uploaded anywhere.

## Requirements

- The Upscayl app installed on this machine, normally at `/Applications/Upscayl.app`
  (Apple Silicon and Intel are both supported, the binary is universal). A
  differently placed engine can be pointed at with `UPSCAYL_BIN`.
- The engine needs a GPU (Metal on a Mac, Vulkan elsewhere). Cloud and container
  sessions normally have neither the app nor a GPU.
- Never decide from the environment alone whether it can work: run `--check`
  first and trust its answer. If it passes, proceed here. If it reports that the
  app is missing, tell the user the job has to run in Claude Code on the Mac and
  offer to install the app there (`brew install --cask upscayl`, or download it
  from https://upscayl.org and drag it into Applications).

## The script

`scripts/upscale.sh` lives next to this file. After the normal install it is at:

```
~/.claude/skills/upscayl/scripts/upscale.sh
```

Always call it with `bash` and quote paths (Hebrew names and spaces are fine):

```bash
bash ~/.claude/skills/upscayl/scripts/upscale.sh --check
bash ~/.claude/skills/upscayl/scripts/upscale.sh "/Users/me/Pictures/product.jpg"
bash ~/.claude/skills/upscayl/scripts/upscale.sh "/Users/me/Pictures/products"
```

Results go to an `upscaled` folder next to the input, named
`<name>_upscayl_4x.<ext>`. Originals are never modified or deleted. Outputs that
already exist are skipped unless `--overwrite` is given.

## Workflow

1. Run `--check` once per session. It prints the engine path, the models, and
   whether the engine responds. If it fails, follow the message (install the app,
   or clear Gatekeeper, see Troubleshooting) before doing anything else.
2. Work out the inputs from the request: one file, several files, or a folder.
   Only jpg, jpeg, png and webp are accepted. HEIC, TIFF, PDF pages and so on must
   be converted first (see Limits).
3. Pick the options (defaults are right for most requests):
   - scale 4x, same format as the input, model `upscayl-standard-4x`.
   - The user names a pixel size ("I need 2000 px wide") -> `--width 2000`.
   - Web or marketplace photos where file size matters -> keep jpg, consider
     `--compress 20` (jpg quality 80).
   - Illustrations, logos, drawings -> `--model digital-art-4x`.
   - "Too sharp", "looks plastic", faces look odd -> `--model high-fidelity-4x`
     or `--scale 2`.
4. Run it. A photo of a few megapixels takes seconds on Apple Silicon; a folder
   of fifty takes a few minutes. Use `-v` if the user wants to watch progress.
5. Report the results in a short table: input, output path, new pixel size, file
   size. Mention skipped and failed files explicitly.

Never delete originals, never write outputs over the inputs, and do not run the
same folder twice with `--overwrite` unless the user asks for it.

## Options

| Option | Meaning | Default |
| --- | --- | --- |
| `-m, --model NAME` | Model, see the table below | `upscayl-standard-4x` |
| `-s, --scale N` | Output scale: 2, 3 or 4 | 4 |
| `-f, --format EXT` | Output format: jpg, png or webp | same as input |
| `-w, --width PX` | Resize the result to this width (keeps aspect ratio); `--scale` is then ignored, like in the app | off |
| `-c, --compress N` | 0 to 100. For jpg and webp the quality is 100 minus N. 0 keeps maximum quality | 0 |
| `-o, --out DIR` | Output folder | `upscaled` next to each input |
| `--suffix TEXT` | Suffix for output names | `_upscayl_<scale>x` |
| `--overwrite` | Redo outputs that already exist | off |
| `--recursive` | Also process sub-folders of a folder | off |
| `--tta` | TTA mode: slower, slightly better | off |
| `--tile N` | Tile size; use 256 or 128 if the GPU runs out of memory | auto |
| `--dry-run` | Print the engine commands instead of running them | off |
| `-v, --verbose` | Show the engine's own progress output | off |
| `--list-models` | Print the installed models | |
| `--check` | Verify the install and print paths | |

Environment variables: `UPSCAYL_BIN` (engine path), `UPSCAYL_MODELS` (models
folder), `UPSCAYL_MODEL` (default model). Only needed for unusual installs.

## Models (the seven that ship with Upscayl 2.15)

Descriptions are Upscayl's own. Three models are licensed for non-commercial use
only. The user sells products and courses, so for anything that will be
published commercially (product listings, sales pages, ads, course material)
use only the four commercial-safe models.

| Model | Upscayl's description | Commercial use |
| --- | --- | --- |
| `upscayl-standard-4x` (default) | Suitable for most images | yes |
| `upscayl-lite-4x` | Suitable for most images. High-speed upscaling with minimal quality loss | yes |
| `high-fidelity-4x` | For all kinds of images with a focus on realistic details and smooth textures | yes |
| `digital-art-4x` | For digital art and illustrations | yes |
| `remacri-4x` | For natural images. Added sharpness and detail | no |
| `ultramix-balanced-4x` | For natural images with a balance of sharpness and detail | no |
| `ultrasharp-4x` | For natural images with a focus on sharpness | no |

All seven are 4x models; 2x and 3x outputs are produced by the engine resizing the
4x result, exactly as the app does.

## Request to command

| The user says | Run |
| --- | --- |
| "תגדיל את התמונה הזאת" / "upscale this photo" | `upscale.sh "<file>"` |
| "תגדיל את כל התמונות בתיקייה פי 4" | `upscale.sh "<folder>"` |
| "פי 2 מספיק" | `upscale.sh --scale 2 "<folder>"` |
| "אני צריך אותן ברוחב 2000 פיקסל לאמזון" | `upscale.sh --width 2000 --format jpg "<folder>"` |
| "תוציא הכל בפורמט png" | `upscale.sh --format png "<folder>"` |
| "זה איור, לא צילום" | `upscale.sh --model digital-art-4x "<file>"` |
| "יצא מלאכותי מדי" | `upscale.sh --model high-fidelity-4x --overwrite "<file>"` |
| "כולל תיקיות המשנה" | `upscale.sh --recursive "<folder>"` |
| "לתיקייה אחרת" | `upscale.sh --out "<dir>" "<folder>"` |

## Reporting

Each successful file prints one line like:

```
+ /path/in.jpg  ->  /path/upscaled/in_upscayl_4x.jpg  (4000x3000, 2310 KB, 6s)
```

Turn those lines into a short table for the user and add one line with the
totals (`Done. succeeded: N | skipped: N | failed: N`). Exit codes: 0 every file
succeeded; 1 at least one file failed or was not found; 2 Upscayl is not
installed; 3 the app is installed but macOS has not let its engine run yet
(see Troubleshooting).

## Limits

- Formats: jpg, jpeg, png, webp only. Convert first when needed, for example
  `sips -s format jpeg "photo.heic" --out "photo.jpg"` (sips ships with macOS).
- Output size: 4x of a 3000 px photo is 12000 px. A png at that size can be tens
  of MB. Prefer jpg or `--width` for web use.
- Very large inputs can exhaust GPU memory; retry with `--tile 256`.
- Faces and text: AI upscaling invents detail. For portraits or images with small
  text prefer `high-fidelity-4x` and check the result before publishing.

## Troubleshooting

- "Upscayl is not installed": install it (`brew install --cask upscayl`) or ask
  the user to download it from https://upscayl.org, then run `--check` again.
- "Engine responds: NO" right after a fresh install, or the run is killed:
  macOS Gatekeeper has not cleared the app yet. Run `open -a Upscayl` once, close
  it, and retry. If that does not help: `xattr -dr com.apple.quarantine /Applications/Upscayl.app`.
- "Invalid GPU Device" or Vulkan errors: the engine needs a GPU. On a Mac this
  should not happen; if it does, run the Upscayl app once to confirm it works
  there, and update the app.
- Out-of-memory errors (vkAllocateMemory, vkQueueSubmit, DEVICE_LOST):
  use `--tile 256`, then `--tile 128`.
- Custom models: the engine accepts any Real-ESRGAN ncnn model pair
  (`name.param` + `name.bin`). Point `UPSCAYL_MODELS` at a folder that contains
  them and pass `--model name`.
