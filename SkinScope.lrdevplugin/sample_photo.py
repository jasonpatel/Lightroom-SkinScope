#!/usr/bin/env python
# sample_photo.py - Real pixel skin tone sampler for SkinScope
import os, sys, json, math
from PIL import Image

def sample_photo(photo_path, out_json):
    try:
        ext = os.path.splitext(photo_path)[1].lower()
        if ext in ['.jpg', '.jpeg', '.png', '.tif', '.tiff', '.bmp']:
            im = Image.open(photo_path)
        else:
            with open(photo_path, 'rb') as f:
                data = f.read(15000000)
            from io import BytesIO
            idx = data.find(b'PRVW')
            jpg_start = -1
            if idx != -1:
                jpg_start = data.find(b'\xff\xd8\xff', idx)
            if jpg_start == -1:
                jpg_start = data.find(b'\xff\xd8\xff')
            if jpg_start != -1:
                jpg_end = data.find(b'\xff\xd9', jpg_start)
                if jpg_end != -1:
                    im = Image.open(BytesIO(data[jpg_start:jpg_end+2]))
                else:
                    im = Image.open(BytesIO(data[jpg_start:]))
            else:
                raise ValueError("No embedded preview JPEG found in RAW file")
                
        w, h = im.size
        candidates = []
        step = max(1, min(w, h) // 150)
        
        # Scan image area (excluding outer 5% frame edges)
        for y in range(h // 20, (h * 19) // 20, step):
            for x in range(w // 20, (w * 19) // 20, step):
                r, g, b = im.getpixel((x, y))[:3]
                # Living skin baseline: Red dominates, Blue is lowest
                if r > g and g > b and r > 85 and b > 45 and (r - b) > 12:
                    # Biological hair & dark wood rejection:
                    # Brown hair and dark wood heavily absorb green and blue compared to living human skin.
                    # Living skin with capillary blood flow maintains G/R >= 0.68 and B/R >= 0.54.
                    if (g / float(r)) >= 0.68 and (b / float(r)) >= 0.54:
                        rf, gf, bf = r / 255.0, g / 255.0, b / 255.0
                        Y  =  0.2126 * rf + 0.7152 * gf + 0.0722 * bf
                        Cb = -0.1146 * rf - 0.3854 * gf + 0.5000 * bf
                        Cr =  0.5000 * rf - 0.4542 * gf - 0.0458 * bf
                        deg = (math.degrees(math.atan2(Cr, Cb)) + 360.0) % 360.0
                        chroma = math.sqrt(Cb * Cb + Cr * Cr)
                        sat = (chroma / max(0.01, Y)) * 0.58 / 0.5 * 100.0
                        if 100 <= deg <= 136 and 10 <= sat <= 55:
                            candidates.append({
                                'x': x, 'y': y,
                                'r': r, 'g': g, 'b': b,
                                'deg': deg, 'sat': sat,
                                'Y': Y * 100.0
                            })
                        
        if not candidates:
            res = {"success": False, "error": "No skin pixels detected"}
        else:
            # Vertical distribution analysis to separate Face/Head from Torso/Body
            y_bins = [0] * 10
            for p in candidates:
                idx = min(9, int((p['y'] / float(h)) * 10))
                y_bins[idx] += 1
            
            # Find clothing/neck valley separating upper head/face from lower body
            split_y = h * 0.45
            for i in range(2, 7):
                if y_bins[i] < y_bins[i-1] and y_bins[i] < y_bins[i+1] and y_bins[i] < (len(candidates) * 0.05):
                    split_y = (i + 0.5) * (h / 10.0)
                    break
            
            face_candidates = [p for p in candidates if p['y'] < split_y]
            body_candidates = [p for p in candidates if p['y'] >= split_y]
            
            # If no upper skin exists (e.g. tight crop on torso), fallback to all candidates
            if not face_candidates:
                face_candidates = list(candidates)
            if not body_candidates:
                body_candidates = list(candidates)
                
            # Filter shadow falloff on face (focus on key-lit midtones & highlights: upper 70% luma)
            if len(face_candidates) > 20:
                face_candidates.sort(key=lambda p: p['Y'])
                face_candidates = face_candidates[int(len(face_candidates) * 0.30):]
                
            def aggregate(px_list):
                if not px_list: return None
                avg_r = sum(p['r'] for p in px_list) / float(len(px_list))
                avg_g = sum(p['g'] for p in px_list) / float(len(px_list))
                avg_b = sum(p['b'] for p in px_list) / float(len(px_list))
                avg_deg = sum(p['deg'] for p in px_list) / float(len(px_list))
                avg_sat = sum(p['sat'] for p in px_list) / float(len(px_list))
                avg_luma = sum(p['Y'] for p in px_list) / float(len(px_list))
                return {
                    "r": round(avg_r / 255.0, 4),
                    "g": round(avg_g / 255.0, 4),
                    "b": round(avg_b / 255.0, 4),
                    "rgb_255": [int(round(avg_r)), int(round(avg_g)), int(round(avg_b))],
                    "angle": round(avg_deg, 1),
                    "sat": round(avg_sat, 1),
                    "luma": round(avg_luma, 1),
                    "count": len(px_list)
                }

            face_stats = aggregate(face_candidates)
            body_stats = aggregate(body_candidates)
            overall_stats = aggregate(candidates)

            # Default top-level fields to face_stats for immediate accuracy
            primary = face_stats or overall_stats
            res = {
                "success": True,
                "r": primary["r"],
                "g": primary["g"],
                "b": primary["b"],
                "rgb_255": primary["rgb_255"],
                "angle": primary["angle"],
                "sat": primary["sat"],
                "luma": primary["luma"],
                "face": face_stats,
                "body": body_stats,
                "overall": overall_stats,
                "count": len(candidates)
            }
    except Exception as e:
        res = {"success": False, "error": str(e)}

    with open(out_json, 'w') as f:
        json.dump(res, f)

if __name__ == '__main__':
    if len(sys.argv) >= 3:
        sample_photo(sys.argv[1], sys.argv[2])
