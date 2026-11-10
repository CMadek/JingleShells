"""Run Blender in background with --factory-startup -P art/neighborhood/build.py."""
import bpy
from math import pi, atan2, hypot
from pathlib import Path
from mathutils import Vector

SRC = Path(__file__).resolve().parent
OUT = SRC.parents[1] / "assets/neighborhood"
OUT.mkdir(exist_ok=True, parents=True)
HOUSES = [
    ("peppermint", 7.8, 6, 3.1, 2.1, "aa4651"),
    ("lantern", 6.8, 6.7, 5.7, 2.4, "497b72"),
    ("gingersnap", 5.5, 7, 3.3, 3.8, "ac724a"),
    ("bluebird", 5.0, 6, 6.6, 1.6, "4d7195"),
]
CARS = [("pip", 3.15, "bc5360"), ("courier", 4.4, "638d86"), ("sledwagon", 4.1, "ba9052")]


def material(name, color, glow=0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name)
    rgba = tuple((int(color[i:i+2],16)/255)**2.2 for i in (0,2,4)) + (1,)
    m.diffuse_color = rgba
    m.use_nodes = True
    shader = m.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Emission Color"].default_value = rgba
    shader.inputs["Emission Strength"].default_value = glow
    return m


def box(name, pos, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(mat)
    if bevel:
        edge=obj.modifiers.new("Rounded trim","BEVEL")
        edge.width=bevel
        edge.segments=2
        obj.modifiers.new("Normals","WEIGHTED_NORMAL")
    return obj


def gable(name,x,y,z,w,d,rise,mat):
    verts=[(x+dx,y+dy,z+dz) for dy in (-d/2,d/2) for dx,dz in [(-w/2,0),(w/2,0),(0,rise)]]
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)


def window(x,y,z,w=1.2,side=False):
    def piece(name,dx,dz,sx,sy,sz,m):
        p=(x,y+dx,z+dz) if side else (x+dx,y,z+dz)
        box(name,p,(sy,sx,sz) if side else (sx,sy,sz),m)
    piece("Painted sash",0,0,w+.19,.16,1.42,trim)
    piece("Amber glass",0,0,w,.19,1.2,light)
    piece("Mullion",0,0,.07,.22,1.2,trim)
    piece("Cross rail",0,0,w,.22,.07,trim)
    piece("Snow sill",0,-.7,w+.35,.32,.11,snow)


def house(index,spec):
    name,w,d,h,r,color=spec
    siding=material("Painted clapboard",color)
    box("House", (0,0,h/2),(w,d,h),siding)
    box("Plinth",(0,0,.20),(w+.15,d+.15,.4),brick)
    gable("Gable",0,0,h,w,d,r,siding)
    for sign in (-1,1):
        span=w/2+.42
        slope=r*span/(w/2)
        roof=box("Snow panel",(sign*span/2,0,h+r-slope/2+.09),
                 (hypot(span,slope)+.06,d+.84,.23),snow,.045)
        roof.rotation_euler.y=sign*atan2(slope,span)
    fy=-d/2
    for x in (-w*.30,w*.30):
        window(x,fy,h*.32 if h>5 else 1.75)
        if h>5: window(x,fy,h-.95,.96)
    for y in (-d*.25,d*.25):
        window(w/2,y,1.8,1.0,True)
        window(-w/2,y,1.8,1.0,True)
    box("Spruce door",(0,fy-.04,1),(1.12,.21,2),pine)
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=6,major_radius=.25,minor_radius=.085,location=(0,fy-.16,1.42),rotation=(pi/2,0,0))
    bpy.context.object.data.materials.append(pine)
    box("Velvet bow",(0,fy-.21,1.17),(.21,.10,.13),berry)
    if index==1:
        box("Gallery balcony",(0,fy-.46,3.62),(w-.55,1.1,.22),trim)
        for i in range(11):
            box("Baluster",((i-5)*.54,fy-.94,3.97),(.10,.10,.66),pine)
        box("Gallery cap",(0,fy-.94,4.33),(w-.62,.17,.13),snow)
    if index==3:
        box("Bay window",(0,fy-.3,3.55),(2.25,.8,1.65),siding)
        window(0,fy-.71,3.55,1.75)
        gable("Bay canopy",0,fy-.3,4.4,2.62,1.12,.6,snow)
    porch=[2.2,3.8,1.85,2.6][index]
    gable("Snow porch hood",0,fy-.47,2.22,porch,1.38,.46,snow)
    for x in (-porch*.40,porch*.40):
        box("Carved post",(x,fy-.98,1.12),(.14,.14,2.24),trim)
    box("Front step",(0,fy-.61,.12),(porch,1.55,.24),brick)
    if index in (0,2):
        # A cross-gable over the side wing gives the low cottages a second ridge.
        box("Side wing",(-w*.45,.4,1.05),(2.2,3.2,2.1),siding)
        gable("Wing snow",-w*.45,.4,2.1,2.8,3.6,1.25,snow)
    for i in range(13):
        x=(i-6)*w/13
        z=h+.15+(1-abs(x)/(w*.5+.4))*(r+.24)
        box("Festoon bulb",(x,fy-.442,z-.15),(.15,.13,.19),light if i%3 else berry,.04)
    cx,cy=w*.21,d*.18
    top=h+r+.85
    box("Brick stack",(cx,cy,(h+top)/2),(1.25,1.25,top-h),brick)
    for sign in (-1,1):
        box("Snow rim",(cx+.64*sign,cy,top),(.16,1.45,.17),snow)
        box("Snow rim",(cx,cy+.64*sign,top),(1.13,.16,.17),snow)
    box("Flue shadow",(cx,cy,top-.02),(1.12,1.12,.05),dark)
    return (cx,cy,top+.09)


def car(index,spec):
    name,length,color=spec
    paint=material("Body paint",color)
    box("Coachwork",(0,0,.62),(1.67,length,.69),paint,.16)
    cabin=[1.58,2.85,2.48][index]
    height=[.75,1.20,.88][index]
    cab=box("Glazed cabin",(0,.14,1.0+height/2),(1.46,cabin,height),glass,.16)
    rake=[.39,.30,.38][index]
    for v in cab.data.vertices:
        if v.co.z>0:
            v.co.x*=.90
            if v.co.y<0: v.co.y+=rake
    box("Snow cap",(0,.14+rake/2,1+height),(1.36,cabin-rake,.12),snow,.055)
    if index==1:
        box("Parcel compartment",(0,.76,1.47),(1.48,1.47,1.09),paint,.10)
        for side in (-1,1):
            for j in range(3):
                box("Courier pennant",(side*.746,.53+j*.13,1.56),(.02,.08,.25-j*.05),trim,.012)
    for end in (-1,1):
        box("Bumper",(0,end*length/2,.42),(1.44,.11,.13),dark,.045)
        for side in (-1,1):
            if end==1: box("Tail lamp",(side*.62,length/2,.72),(.24,.06,.16),berry,.03)
    box("Winter hood",(0,-length/2+.38,.973),(1.29,.46,.035),snow,.014)
    for side in (-1,1):
        box("Window pillar",(side*.726,.1,1+height/2),(.075,.12,height),paint)
        for y in (-length*.30,length*.30):
            bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.37,depth=.21,rotation=(0,pi/2,0),location=(side*.83,y,.37))
            bpy.context.object.data.materials.append(dark)
            bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.16,depth=.025,rotation=(0,pi/2,0),location=(side*.94,y,.37))
            bpy.context.object.data.materials.append(trim)
        box("Headlamp",(side*.54,-length/2,.75),(.32,.06,.15),light,.025)
    if index==2:
        box("Roof parcel",(0,.3,2.17),(.8,.87,.45),berry,.04)
        box("Ribbon",(0,.3,2.17),(.14,.89,.46),trim)


def batch_colors(obj):
    """Bake static diffuse colors into one surface, retaining paint and glow slots."""
    geo=obj.data
    original=list(geo.materials)
    atlas=material("Winter palette","ffffff")
    vertex=atlas.node_tree.nodes.new("ShaderNodeVertexColor")
    vertex.layer_name="Winter"
    atlas.node_tree.links.new(vertex.outputs["Color"],atlas.node_tree.nodes.get("Principled BSDF").inputs["Base Color"])
    colors=geo.color_attributes.new(name="Winter",type="BYTE_COLOR",domain="CORNER")
    slots=[atlas]
    assignments=[]
    for poly in geo.polygons:
        m=original[poly.material_index]
        keep=m.name in ("Candlelight","Painted clapboard","Body paint")
        if keep and m not in slots: slots.append(m)
        assignments.append(slots.index(m) if keep else 0)
        for loop in poly.loop_indices:
            colors.data[loop].color=(1,1,1,1) if keep else m.diffuse_color
    geo.materials.clear()
    for slot in slots: geo.materials.append(slot)
    for poly,idx in zip(geo.polygons,assignments): poly.material_index=idx


def preview(name, vehicle):
    target=Vector((0,0,1 if vehicle else 3.6))
    bpy.ops.object.camera_add(location=target+Vector((11,-17,11)))
    cam=bpy.context.object
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.type="ORTHO"
    cam.data.ortho_scale=5.9 if vehicle else 14.6
    sc=bpy.context.scene
    sc.camera=cam
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.015))
    bpy.context.object.data.materials.append(material("Studio","66808d"))
    for pos,energy,size in [((-6,-8,14),2200,8),((8,-3,10),1500,7),((1,8,13),2400,6)]:
        bpy.ops.object.light_add(type="AREA",location=pos)
        obj=bpy.context.object
        obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
        obj.data.energy,obj.data.size=energy,size
    sc.world=bpy.data.worlds.new("Winter fill")
    sc.world.color=(.42,.42,.42)
    sc.render.engine="CYCLES"
    sc.cycles.samples=5
    sc.cycles.use_denoising=True
    sc.render.resolution_x,sc.render.resolution_y,sc.render.resolution_percentage=460,380,100
    sc.render.filepath=str(SRC/(name+".png"))
    bpy.ops.render.render(write_still=True)


for vehicle, specs in [(False,HOUSES),(True,CARS)]:
    for index,spec in enumerate(specs):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version=0
        snow=material("Powder snow","f1f7ff")
        trim=material("Cream trim","f1d89d")
        light=material("Candlelight","ffcc78",1.3)
        brick=material("Cranberry brick","904e43")
        pine=material("Fir","235649")
        berry=material("Holly red","cd3943")
        dark=material("Charcoal","2c3743")
        glass=material("Frosted glass","475d70")
        top=car(index,spec) if vehicle else house(index,spec)
        name=spec[0]
        if top:
            bpy.ops.object.empty_add(type="PLAIN_AXES",location=top)
            bpy.context.object.name="Delivery"
        bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+".blend")),compress=True)
        bpy.ops.object.select_all(action="DESELECT")
        parts=[o for o in bpy.context.scene.objects if o.type=="MESH"]
        # Godot imports these low-poly hulls as collision-only shapes.
        for part in parts:
            if part.name.startswith(("House","Gable","Side wing","Wing snow","Snow rim","Brick stack","Coachwork","Glazed cabin")):
                proxy=part.copy()
                proxy.data=part.data.copy()
                proxy.modifiers.clear()
                if part.name == "Brick stack":
                    # Leave space for the parcel's center to cross the delivery plane.
                    proxy.dimensions.z -= .55
                    proxy.location.z -= .275
                proxy.name=part.name+"-convcolonly"
                bpy.context.collection.objects.link(proxy)
                proxy.select_set(False)
        for o in parts: o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0]
        bpy.ops.object.convert(target="MESH")
        bpy.ops.object.join()
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        bpy.context.object.name="Exterior"
        batch_colors(bpy.context.object)
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+".glb")),export_format="GLB",export_animations=False)
        for o in list(bpy.context.scene.objects):
            if o.name.endswith("-convcolonly"): o.hide_render=True
        preview(name,vehicle)
