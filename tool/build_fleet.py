import struct, sys, numpy as np, trimesh, fast_simplification

src, out = sys.argv[1], sys.argv[2]
cars = {
    'model_3': ('Tesla_Model_3', 4.72, 1.85, 1.44, 0.62),
    'model_s': ('Tesla_Model_3', 4.98, 1.96, 1.43, 0.62),
    'model_y': ('Tesla_Model_Y', 4.75, 1.92, 1.62, 0.6),
    'model_x': ('Tesla_Model_X', 5.05, 2.0, 1.68, 0.6),
    'cybertruck': ('Tesla_Cybertruck', 5.68, 2.2, 1.79, 0.58),
}

def prepare(path, length, width, height):
    mesh = trimesh.load(path, force='mesh')
    mesh = max(mesh.split(only_watertight=False), key=lambda p: len(p.faces))
    v, f = fast_simplification.simplify(mesh.vertices.astype(np.float32), mesh.faces.astype(np.int32), target_reduction=1 - 6000 / len(mesh.faces))
    v = v.astype(np.float64)
    ext = v.max(0) - v.min(0)
    if ext[0] > ext[2]:
        v = v[:, [2, 1, 0]] * [1, 1, -1]
    v -= [(v[:, 0].max() + v[:, 0].min()) / 2, v[:, 1].min(), (v[:, 2].max() + v[:, 2].min()) / 2]
    v *= [width / np.ptp(v[:, 0]), height / np.ptp(v[:, 1]), length / np.ptp(v[:, 2])]
    mesh = trimesh.Trimesh(v, f, process=True)
    mesh.fix_normals()
    return mesh

def colors(mesh, height, belt, cyber):
    v, n = mesh.vertices, mesh.vertex_normals
    x, y, z = np.abs(v[:, 0]), v[:, 1], v[:, 2]
    half = np.ptp(v[:, 0]) / 2
    shade = np.ones(len(v))
    if cyber:
        glass = (y > belt * height) & (y < 0.93 * height) & (np.abs(n[:, 1]) < 0.75)
    else:
        glass = y > belt * height
    shade[glass] = 0.035
    shade[y < 0.2] = 0.05
    low = v[y < 0.04]
    radius = 0.36 if not cyber else 0.43
    for side in (low[:, 2] > 0, low[:, 2] <= 0):
        if side.sum() == 0:
            continue
        zc = low[side, 2].mean()
        shade[(np.hypot(y - radius, z - zc) < radius + 0.03) & (x > half - 0.4)] = 0.03
    return np.repeat(shade[:, None], 4, 1) * [1, 1, 1.15, 0] + [0, 0, 0, 1]

for name, (photo, length, width, height, belt) in cars.items():
    mesh = prepare(f'{src}/{photo}.glb', length, width, height)
    color = np.clip(colors(mesh, height, belt, name == 'cybertruck'), 0, 1)
    positions = mesh.vertices.astype('<f4')
    normals = mesh.vertex_normals.astype('<f4')
    indices = mesh.faces.astype('<u4').ravel()
    data = struct.pack('<3f2I', length, width, height, len(positions), len(indices))
    data += positions.tobytes() + normals.tobytes() + color.astype('<f4').tobytes() + indices.tobytes()
    open(f'{out}/{name}.bin', 'wb').write(data)
    print(name, len(mesh.faces), len(data))
