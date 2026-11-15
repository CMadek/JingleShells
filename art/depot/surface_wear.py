"""Baked colour plates for the depot. U follows the long edge of each board."""
import bpy
import numpy as np


def cloud(rng, u, v, nx, ny):
    lattice = rng.random((ny, nx))
    x, y = u * nx, v * ny
    ix, iy = np.floor(x).astype(int), np.floor(y).astype(int)
    tx, ty = x - ix, y - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = lattice[iy % ny, ix % nx] * (1-tx) + lattice[iy % ny, (ix+1) % nx] * tx
    b = lattice[(iy+1) % ny, ix % nx] * (1-tx) + lattice[(iy+1) % ny, (ix+1) % nx] * tx
    return a * (1-ty) + b * ty


def finish(material, family, seed, rgb):
    rng = np.random.default_rng(seed)
    h, w = 512, 1024
    v, u = np.mgrid[:h, :w] / np.array([h, w])[:, None, None]
    mottling = cloud(rng, u, v, 13, 9)
    fleck = cloud(rng, u, v, 110, 74)
    grit = rng.random((h, w))
    edge = np.minimum.reduce([u, 1-u, v, 1-v])
    rim = np.clip(1-edge/(.009 + .048*mottling**2), 0, 1)
    if family == 'wood':
        cx, cy = rng.uniform(.20, .79, 2)
        knot = np.exp(-((u-cx)/.13)**2-((v-cy)/.20)**2)
        sweep = v + .042*cloud(rng,u,v,3,4) + .085*knot
        rings = (.5 + .5*np.cos(sweep * 132 + mottling*3))**8
        fibers = cloud(rng,u,sweep,13,157)
        tone = .67 + .55*fibers + .39*mottling - .18*rings - .40*knot + .07*grit
        rub = rim*(.11 + .42*fleck)
        exposed = [.49,.29,.135]
    elif family == 'leather':
        grain = cloud(rng,u,v,220,165)
        tone = .62 + .58*mottling + .18*grain + .08*grit
        rub = rim*(.2+.5*fleck) + .09*np.clip((mottling-.61)*3,0,1)
        exposed = [.49,.18,.085]
    elif family == 'enamel':
        tone = .79 + .27*mottling + .08*fleck
        rub = rim*np.clip((fleck+.22*grit-.32)*2.8,0,1)
        exposed = [.40,.24,.115]
    else:  # Fired brick with pale salts and a rough, chipped arris.
        tone = .61 + .49*mottling + .27*fleck + .17*grit
        rub = .21*rim + .16*np.clip((mottling-.58)*2.4,0,1)
        exposed = [.54,.35,.22]
    linear = np.asarray(rgb)*tone[:,:,None]*(1-rub[:,:,None]) + np.asarray(exposed)*rub[:,:,None]
    rgba = np.ones((h,w,4),np.float32)
    rgba[:,:,:3] = np.clip(linear,0,1)**(1/2.2)
    image = bpy.data.images.new(material.name,w,h)
    image.pixels.foreach_set(rgba.ravel())
    image.pack()
    tree = material.node_tree
    tex = tree.nodes.new('ShaderNodeTexImage')
    tex.image = image
    tree.links.new(tex.outputs['Color'],tree.nodes.get('Principled BSDF').inputs['Base Color'])


def box_uv(obj):
    mesh = obj.data
    uv = mesh.uv_layers.active.data
    for face in mesh.polygons:
        a,b = sorted(range(3),key=lambda i: abs(face.normal[i]))[:2]
        if obj.dimensions[b] > obj.dimensions[a]:
            a,b = b,a
        for corner in face.loop_indices:
            p = mesh.vertices[mesh.loops[corner].vertex_index].co
            uv[corner].uv = (p[a]/obj.dimensions[a]+.5,p[b]/obj.dimensions[b]+.5)


def woven(material, repeats, base, band):
    """One filtered surface per textile, including its faded selvedge."""
    h=w=768
    v,u=np.mgrid[:h,:w]/np.array([h,w])[:,None,None]
    a,b=(u*repeats[0])%1,(v*repeats[1])%1
    broad=((a<.43).astype(float)+(b<.43).astype(float))*.42
    dye=np.asarray(base)*(1-broad[:,:,None])+np.asarray(band)*broad[:,:,None]
    red=np.maximum(np.abs(a-.48)<.032,np.abs(b-.48)<.032)*.64
    ivory=np.maximum(np.abs(a-.55)<.014,np.abs(b-.55)<.014)*.38
    dye=dye*(1-red[:,:,None])+np.array([.34,.092,.048])*red[:,:,None]
    dye=dye*(1-ivory[:,:,None])+np.array([.51,.42,.28])*ivory[:,:,None]
    rng=np.random.default_rng(1937)
    nap=.86+.18*cloud(rng,u,v,49,61)+.12*rng.random((h,w))
    nap+=.066*np.sin(2*np.pi*u*310)*np.cos(2*np.pi*v*302)
    edge=np.minimum.reduce([u,1-u,v,1-v])
    nap *= np.where(edge<.012,.71,1)
    rgba=np.ones((h,w,4),np.float32)
    rgba[:,:,:3]=np.clip(dye*nap[:,:,None],0,1)**(1/2.2)
    img=bpy.data.images.new(material.name,w,h)
    img.pixels.foreach_set(rgba.ravel());img.pack()
    nodes=material.node_tree.nodes
    tex=nodes.new('ShaderNodeTexImage');tex.image=img
    material.node_tree.links.new(tex.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
