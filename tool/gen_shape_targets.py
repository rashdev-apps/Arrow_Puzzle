import json
import math
import os
import random

# Vector silhouettes normalized [0, 1] x [0, 1]
SHAPES = {
    'heart': [
        [(0.50, 0.88), (0.32, 0.72), (0.16, 0.56), (0.08, 0.38), (0.08, 0.24),
         (0.16, 0.12), (0.30, 0.08), (0.42, 0.14), (0.50, 0.26), (0.58, 0.14),
         (0.70, 0.08), (0.84, 0.12), (0.92, 0.24), (0.92, 0.38), (0.84, 0.56),
         (0.68, 0.72)]
    ],
    'dog': [
        [(0.10, 0.22), (0.22, 0.14), (0.32, 0.08), (0.36, 0.18), (0.44, 0.24),
         (0.60, 0.24), (0.76, 0.26), (0.86, 0.20), (0.92, 0.14), (0.90, 0.32),
         (0.84, 0.42), (0.82, 0.64), (0.80, 0.90), (0.68, 0.90), (0.68, 0.64),
         (0.56, 0.58), (0.44, 0.58), (0.40, 0.64), (0.40, 0.90), (0.30, 0.90),
         (0.30, 0.56), (0.22, 0.44), (0.12, 0.34)]
    ],
    'cat': [
        [(0.20, 0.28), (0.22, 0.10), (0.32, 0.20), (0.38, 0.10), (0.44, 0.22),
         (0.58, 0.24), (0.74, 0.28), (0.86, 0.18), (0.94, 0.10), (0.96, 0.24),
         (0.88, 0.38), (0.80, 0.56), (0.78, 0.90), (0.66, 0.90), (0.66, 0.62),
         (0.52, 0.58), (0.40, 0.62), (0.38, 0.90), (0.26, 0.90), (0.26, 0.48),
         (0.14, 0.38)]
    ],
    'elephant': [
        [(0.06, 0.68), (0.12, 0.82), (0.18, 0.68), (0.18, 0.46), (0.26, 0.30),
         (0.20, 0.16), (0.38, 0.10), (0.46, 0.24), (0.64, 0.14), (0.82, 0.18),
         (0.92, 0.30), (0.92, 0.50), (0.86, 0.90), (0.72, 0.90), (0.72, 0.62),
         (0.58, 0.60), (0.52, 0.90), (0.38, 0.90), (0.36, 0.54), (0.26, 0.48)]
    ],
    'butterfly': [
        [(0.50, 0.12), (0.68, 0.06), (0.94, 0.16), (0.98, 0.38), (0.84, 0.52),
         (0.94, 0.68), (0.86, 0.88), (0.66, 0.78), (0.52, 0.90), (0.48, 0.90),
         (0.34, 0.78), (0.14, 0.88), (0.06, 0.68), (0.16, 0.52), (0.02, 0.38),
         (0.06, 0.16), (0.32, 0.06)]
    ],
    'maze': [
        [(0.08, 0.12), (0.35, 0.08), (0.50, 0.12), (0.78, 0.06), (0.92, 0.16),
         (0.96, 0.50), (0.90, 0.84), (0.66, 0.92), (0.35, 0.90), (0.10, 0.84),
         (0.06, 0.50)]
    ]
}

def point_in_polygon(x, y, poly):
    inside = False
    n = len(poly)
    for i in range(n):
        j = (i - 1) % n
        xi, yi = poly[i]
        xj, yj = poly[j]
        intersect = ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        if intersect:
            inside = not inside
    return inside

def rasterize(shape_name, rows, cols):
    poly = SHAPES[shape_name][0]
    mask = []
    for r in range(rows):
        for c in range(cols):
            x = (c + 0.5) / cols
            y = (r + 0.5) / rows
            mask.append(1 if point_in_polygon(x, y, poly) else 0)
    return mask

# Grids sized so target arrow count fits with high fidelity
TEST_TARGETS = [
    (1, 'heart', 30, (20, 16)),
    (2, 'dog', 50, (26, 22)),
    (3, 'cat', 60, (28, 22)),
    (4, 'elephant', 80, (32, 26)),
    (5, 'butterfly', 100, (34, 28)),
    (6, 'maze', 120, (38, 28)),
]

DIRS = {'up': (-1, 0), 'down': (1, 0), 'left': (0, -1), 'right': (0, 1)}

def generate_shape_level(level_id, shape_name, target_arrows, dims):
    rows, cols = dims
    mask = rasterize(shape_name, rows, cols)
    free = set((r, c) for r in range(rows) for c in range(cols) if mask[r * cols + c] == 1)
    occupied = {}
    arrows = []

    rng = random.Random(level_id * 1007 + 77)
    # Calibrated arrow lengths:
    # 2 to 4 cells per arrow allows high density (30 to 120 arrows) while preserving recognizability
    min_len = 2
    max_len = 3 if target_arrows <= 40 else 4

    attempts = 0
    while len(arrows) < target_arrows and free and attempts < 10000:
        attempts += 1
        starts = list(free)
        rng.shuffle(starts)
        best = None

        for head_r, head_c in starts:
            if best:
                break
            dirs = list(DIRS.keys())
            rng.shuffle(dirs)

            for dname in dirs:
                dr, dc = DIRS[dname]
                # Ray exit check
                curr_r, curr_c = head_r + dr, head_c + dc
                ray_clear = True
                while 0 <= curr_r < rows and 0 <= curr_c < cols:
                    if (curr_r, curr_c) in occupied:
                        ray_clear = False
                        break
                    curr_r += dr
                    curr_c += dc
                if not ray_clear:
                    continue

                # Head run >= 2
                opp_dr, opp_dc = -dr, -dc
                second_r, second_c = head_r + opp_dr, head_c + opp_dc
                if not (0 <= second_r < rows and 0 <= second_c < cols and (second_r, second_c) in free):
                    continue

                path = [(second_r, second_c), (head_r, head_c)]
                visited = {(head_r, head_c), (second_r, second_c)}

                curr_tail_r, curr_tail_c = second_r, second_c
                curr_dir = (opp_dr, opp_dc)
                target_len = rng.randint(min_len, max_len)

                while len(path) < target_len:
                    candidates = []
                    for cand_dir in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                        if cand_dir == (-curr_dir[0], -curr_dir[1]):
                            continue
                        nr, nc = curr_tail_r + cand_dir[0], curr_tail_c + cand_dir[1]
                        if 0 <= nr < rows and 0 <= nc < cols and (nr, nc) in free and (nr, nc) not in visited:
                            candidates.append(cand_dir)
                    if not candidates:
                        break
                    chosen = curr_dir if (curr_dir in candidates and rng.random() < 0.65) else rng.choice(candidates)
                    curr_tail_r += chosen[0]
                    curr_tail_c += chosen[1]
                    path.insert(0, (curr_tail_r, curr_tail_c))
                    visited.add((curr_tail_r, curr_tail_c))
                    curr_dir = chosen

                if len(path) >= 2:
                    best = {
                        'id': f'a{len(arrows)}',
                        'path': [{'row': r, 'col': c} for r, c in path],
                        'dir': dname,
                    }
                    break

        if not best:
            break
        arrows.append(best)
        for pt in best['path']:
            pt_tup = (pt['row'], pt['col'])
            free.discard(pt_tup)
            occupied[pt_tup] = best['id']

    # Extend tails
    grew = True
    while grew and free:
        grew = False
        for a in arrows:
            tail = (a['path'][0]['row'], a['path'][0]['col'])
            for dr, dc in [(0, 1), (0, -1), (1, 0), (-1, 0)]:
                nr, nc = tail[0] + dr, tail[1] + dc
                if 0 <= nr < rows and 0 <= nc < cols and (nr, nc) in free:
                    a['path'].insert(0, {'row': nr, 'col': nc})
                    free.discard((nr, nc))
                    occupied[(nr, nc)] = a['id']
                    grew = True
                    break

    level_data = {
        'id': level_id,
        'shape': shape_name,
        'rows': rows,
        'cols': cols,
        'mask': mask,
        'arrows': arrows,
        'par_moves': len(arrows),
        'difficulty': round(len(arrows) * 1.5, 1),
        'timeLimit': max(20, round(len(arrows) * 5.0)) if level_id > 3 else None,
        'solution': [a['id'] for a in arrows],
    }
    return level_data

print('Regenerating 6 target shape levels with exact arrow counts...')
for lvl, shape, target_cnt, dims in TEST_TARGETS:
    data = generate_shape_level(lvl, shape, target_cnt, dims)
    with open(f'assets/levels/level_{lvl:03d}.json', 'w') as f:
        json.dump(data, f, indent=2)
    print(f'Level {lvl} [{shape.upper()}]: {len(data["arrows"])} arrows (Target: {target_cnt}, Grid: {data["rows"]}x{data["cols"]})')

print('All 6 shape targets generated!')
