"""Deterministic UV color atlases for surface-bound stitchwork and costume trim.

Rasterize the authored mesh UVs, paint using its bind-pose surface positions, then
pack the images into Blender/GLB. No floating line meshes or runtime projection.
"""
import numpy as np
from pathlib import Path

def band(distance,width,soft=.0015):
    return np.clip((width+soft-np.abs(distance))/soft,0,1)

def paint_surface(o,p,n,base,stage):
    color=np.tile(np.asarray(base,dtype=np.float32),(len(p),1));tint=np.ones(len(p),dtype=np.float32)
    x,y,z=p.T;nx,ny,nz=n.T;name=o.name
    # Restrained woven variation; the atlas carries it with the garment as it bends.
    grain=1+.012*np.sin((x+y)*1450)*np.sin(z*1450)
    color*=grain[:,None]
    def draw(mask,ink):
        nonlocal color,tint
        mask=np.clip(mask,0,1)
        color=color*(1-mask[:,None])+np.asarray(ink)[None,:]*mask[:,None]
        tint*=1-mask
    flax=(.52,.38,.19);ivory=(.82,.73,.53);cranberry=surfaces.PALETTE['cranberry']
    if name.startswith('Joined plush coat'):
        draw(np.maximum(band(z-.71,.003),band(z-.735,.003)),flax)
        draw(band(x,.009)*(z>.76)*(z<1.22)*(ny<-.3)*(y<-.12),ivory)
    elif name.startswith('Rounded coat pocket'):
        cx=-.165 if ' L' in name else .165
        # Legacy pocket names have Blender suffixes; use their actual center.
        cx=o.matrix_world.translation.x
        target=.89+.015*np.abs((x-cx)/.073)
        draw(band(z-target,.004)*(np.abs(x-cx)<.073)*(ny<-.2),ivory)
    elif name.startswith('Soft folded wool cap'):
        zs=np.asarray([r[2] for r in cap_rings[:6]])
        cx=np.interp(z,zs,[r[0] for r in cap_rings[:6]])
        cy=np.interp(z,zs,[r[1] for r in cap_rings[:6]])
        rx=np.interp(z,zs,[r[3] for r in cap_rings[:6]])
        ry=np.interp(z,zs,[r[4] for r in cap_rings[:6]])
        a=np.arctan2((y-cy)/ry,(x-cx)/rx)
        for angle in (math.pi*.12,math.pi*.65,math.pi*1.2,math.pi*1.7):
            difference=np.arctan2(np.sin(a-angle),np.cos(a-angle))*np.minimum(rx,ry)
            draw(band(difference,.0022),flax)
        draw(band(z-1.77,.015),surfaces.PALETTE['leather'])
    elif name.startswith('Turned wool cap brim'):
        a=np.arctan2(y/.211,x/.256)
        draw(band(np.sin(a*20),.12,.10)*(z>1.672)*(z<1.714),flax)
    elif name.startswith('Folded knitted scarf'):
        draw(np.maximum(band(z-1.04,.007),band(z-1.07,.007)),cranberry)
        draw(band(z-1.018,.0025),flax)
    elif name.startswith('Knitted sock'):
        for height in (.30,.325,.35):draw(band(z-height,.002),flax)
    elif name.startswith('Single shaped boot'):
        cx=o.get('boot_center',-.145 if name.endswith('L') else .145)
        front=(ny<-.2)*(np.abs(x-cx)<.047)
        for height in (.17,.215,.255):
            for flip in (-1,1):draw(band(z-height-flip*(x-cx)*.27,.003)*front,ivory)
        draw(band(z-.082,.002),flax)
    elif name.startswith('Soft joined mitten'):
        cx=o.matrix_world.translation.x
        draw(band(z-(.635+.015*np.abs((x-cx)/.06)),.0025)*(np.abs(x-cx)<.06)*(ny<-.25),flax)
    elif name.startswith('Joined first person mitten'):
        cx=o.matrix_world.translation.x
        draw(band(y-(.55-.03*np.abs((x-cx)/.063)),.0025)*(np.abs(x-cx)<.063)*(nz>.25),flax)
        for offset in (-.036,.036):draw(band(x-cx-offset,.0018)*(y>.47)*(y<.54)*(nz>.3),flax)
    elif name.startswith('Courier badge'):
        dx=x+.14;dz=z-1.12
        draw(np.maximum(band(dx,.003)*(np.abs(dz)<.032),band(dz,.003)*(np.abs(dx)<.026))*(ny<-.15),ivory)
    return color,tint

def rasterize(objects,size):
    positions=np.zeros((size,size,3),np.float32);normals=np.zeros_like(positions)
    owner=np.full((size,size),-1,np.int16)
    for object_id,o in enumerate(objects):
        mesh=o.data;mesh.calc_loop_triangles()
        uv=mesh.uv_layers.active.data
        world=np.asarray(o.matrix_world,dtype=np.float32)
        vertices=np.asarray([v.co[:] for v in mesh.vertices],np.float32)@world[:3,:3].T+world[:3,3]
        vertex_normals=np.asarray([v.normal[:] for v in mesh.vertices],np.float32)@np.linalg.inv(world[:3,:3])
        for tri in mesh.loop_triangles:
            t=np.asarray([uv[i].uv[:] for i in tri.loops],np.float32)*size-.5
            lo=np.maximum(np.floor(t.min(axis=0)).astype(int),0);hi=np.minimum(np.ceil(t.max(axis=0)).astype(int)+1,size)
            if np.any(lo>=hi):continue
            xx,yy=np.meshgrid(np.arange(lo[0],hi[0]),np.arange(lo[1],hi[1]))
            a,b,c=t;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den)<1e-7:continue
            wa=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
            wb=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
            wc=1-wa-wb;inside=(wa>=-.0001)&(wb>=-.0001)&(wc>=-.0001)
            if not inside.any():continue
            xs=xx[inside];ys=yy[inside];weights=np.stack((wa[inside],wb[inside],wc[inside]),axis=1)
            positions[ys,xs]=weights@vertices[list(tri.vertices)]
            normals[ys,xs]=weights@vertex_normals[list(tri.vertices)]
            owner[ys,xs]=object_id
    return positions,normals,owner

def image_from_pixels(name,rgba,path,data=False):
    image=bpy.data.images.new(name,width=rgba.shape[1],height=rgba.shape[0],alpha=True)
    image.colorspace_settings.name='Non-Color' if data else 'sRGB'
    pixels=rgba.astype(np.float32).copy()
    if not data:
        rgb=pixels[:,:,:3]
        pixels[:,:,:3]=np.where(rgb<=.0031308,12.92*rgb,1.055*np.maximum(rgb,0)**(1/2.4)-.055)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw=str(path);image.file_format='PNG';image.save();image.pack()
    return image

def paint_surfaces(stage):
    remove_line_guides();bpy.context.view_layer.update()
    targets=[(pine,'coat',2048),(red,'cranberry',1024),(cream,'wool',2048),(dark,'leather',2048),(gold,'brass',512)]
    source_dir=Path(ROOT)/'art/elf/textures';source_dir.mkdir(exist_ok=True)
    game_dir=Path(ROOT)/'assets/elf/textures';game_dir.mkdir(exist_ok=True)
    for material,label,size in targets:
        objects=[o for o,w in parts if o.data.materials[0]==material]
        if not objects:continue
        if stage=='hands':size=1024
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            o.select_set(True)
            while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
            o.data.uv_layers.new(name='Costume atlas')
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.004)
        bpy.ops.uv.pack_islands(margin=.004)
        bpy.ops.object.mode_set(mode='OBJECT')
        p,n,owner=rasterize(objects,size)
        rgba=np.ones((size,size,4),np.float32);tint=np.ones((size,size),np.float32)
        base=material.diffuse_color[:3];rgba[:,:,:3]=base
        for object_id,o in enumerate(objects):
            occupied=owner==object_id
            rgb,mask=paint_surface(o,p[occupied],n[occupied],base,stage)
            rgba[occupied,:3]=rgb;tint[occupied]=mask
        # Extend island colors into their gutters for filtering and generated LODs.
        valid=owner>=0
        for step in range(5):
            old=valid.copy()
            for axis,shift in ((0,1),(0,-1),(1,1),(1,-1)):
                fill=~valid & np.roll(old,shift,axis=axis)
                rgba[fill]=np.roll(rgba,shift,axis=axis)[fill]
                tint[fill]=np.roll(tint,shift,axis=axis)[fill];valid[fill]=True
        name=f'{stage}_{label}_color'
        atlas=image_from_pixels(name,rgba,source_dir/(name+'.png'))
        nodes=material.node_tree.nodes;links=material.node_tree.links;pbr=nodes['Principled BSDF']
        # The color atlas includes grain; avoid applying the old tiled map to new UVs.
        for node in list(nodes):
            if node.type not in ('BSDF_PRINCIPLED','OUTPUT_MATERIAL'):nodes.remove(node)
        tex=nodes.new('ShaderNodeTexImage');tex.image=atlas
        links.new(tex.outputs['Color'],pbr.inputs['Base Color'])
        pbr.inputs['Roughness'].default_value=.92 if label in ('coat','cranberry','wool') else (.76 if label=='leather' else .32)
        pbr.inputs['Metallic'].default_value=.72 if label=='brass' else 0
        if label=='coat':
            mask_rgba=np.ones_like(rgba);mask_rgba[:,:,:3]=tint[:,:,None]
            image_from_pixels(stage+'_coat_tint',mask_rgba,game_dir/(stage+'_coat_tint.png'),data=True)
        print('PAINTED',stage,label,size,'surface objects',len(objects),flush=True)
