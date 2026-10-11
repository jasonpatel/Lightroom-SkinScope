#!/usr/bin/env python
# sample_photo.py - Real pixel skin tone sampler for SkinScope
# Supports both one-shot CLI execution and persistent daemon mode.
import os, sys, json, math, socket, time

def analyze_image(photo_path):
    try:
        from PIL import Image
    except ImportError:
        return {"success": False, "error": "Pillow (PIL) is not installed. Run 'pip install pillow' to enable raw pixel sampling."}

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
                return {"success": False, "error": "No embedded preview JPEG found in RAW file"}

        w, h = im.size
        candidates = []
        step = max(1, min(w, h) // 150)
        pix = im.load()

        # Scan image area (excluding outer 5% frame edges)
        for y in range(h // 20, (h * 19) // 20, step):
            for x in range(w // 20, (w * 19) // 20, step):
                r, g, b = pix[x, y][:3]
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
            return {"success": False, "error": "No skin pixels detected"}

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
        return {
            "success": True,
            "width": w,
            "height": h,
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
        return {"success": False, "error": str(e)}

def run_daemon(port_file):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 0))
    server.listen(5)
    assigned_port = server.getsockname()[1]

    with open(port_file, 'w') as f:
        f.write(str(assigned_port) + "\n")

    # 15 minutes idle timeout
    IDLE_TIMEOUT = 900
    last_active = time.time()
    server.settimeout(2.0)

    try:
        while True:
            if time.time() - last_active > IDLE_TIMEOUT:
                break
            try:
                conn, _ = server.accept()
            except socket.timeout:
                continue
            except Exception:
                break

            last_active = time.time()
            conn.settimeout(10.0)
            buffer = ""

            try:
                while True:
                    data = conn.recv(4096)
                    if not data:
                        break
                    buffer += data.decode('utf-8', errors='ignore')
                    if "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        line = line.strip()
                        if not line:
                            continue

                        try:
                            req = json.loads(line)
                        except Exception as e:
                            resp = {"success": False, "error": "Invalid JSON: " + str(e)}
                            conn.sendall((json.dumps(resp) + "\n").encode('utf-8'))
                            continue

                        cmd = req.get("cmd")
                        if cmd == "ping":
                            resp = {"success": True, "pong": True}
                        elif cmd == "sample":
                            path = req.get("path")
                            resp = analyze_image(path)
                        elif cmd == "exit":
                            resp = {"success": True, "exiting": True}
                            conn.sendall((json.dumps(resp) + "\n").encode('utf-8'))
                            conn.close()
                            return
                        else:
                            resp = {"success": False, "error": "Unknown command"}

                        conn.sendall((json.dumps(resp) + "\n").encode('utf-8'))
            except Exception:
                pass
            finally:
                try:
                    conn.close()
                except Exception:
                    pass
    finally:
        try:
            server.close()
        except Exception:
            pass
        if os.path.exists(port_file):
            try:
                os.remove(port_file)
            except Exception:
                pass

if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == '--daemon':
        port_file = sys.argv[2] if len(sys.argv) >= 3 else "skinscope_daemon.port"
        run_daemon(port_file)
    elif len(sys.argv) >= 3:
        # Standard one-shot mode: python sample_photo.py <photo_path> <out_json>
        res = analyze_image(sys.argv[1])
        with open(sys.argv[2], 'w') as f:
            json.dump(res, f)
    else:
        print("Usage:")
        print("  One-shot: python sample_photo.py <photo_path> <out_json>")
        print("  Daemon:   python sample_photo.py --daemon <port_file_path>")
