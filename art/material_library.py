"""Shared, exportable Christmas materials. No renderer-only procedural nodes.

Small periodic roughness/normal maps are packed in the .blend and embedded in GLB.
Colors are linear; material names are also the Godot presentation contract.
"""
import bpy, math, random
from pathlib import Path

PALETTE = {
    "cranberry": (.36, .035, .055), "spruce": (.035, .145, .106),
    "cream": (.82, .73, .53), "brass": (.58, .34, .105),
    "leather": (.095, .035, .027), "rubber": (.028, .037, .033),
}
_images = {}

def detail_maps(family, roughness, metallic):
    key = (family, roughness, metallic)
    if key in _images: return _images[key]
    size = 128
    rng = random.Random(24012)
    heights = []
    for y in range(size):
        for x in range(size):
            n = rng.uniform(-1, 1)
            if family == "wool":
                h = .5*math.sin(x*math.tau/8)*math.cos(y*math.tau/8) + .18*n
            elif family == "leather":
                h = .25*math.sin(x*math.tau/16)*math.sin(y*math.tau/16) + .3*n
            elif family == "wood":
                h = .35*math.sin(x*math.tau/16 + .25*math.sin(y*math.tau/128)) + .1*n
            elif family == "brass":
                h = .12*math.sin(y*math.tau/4) + .08*n
            else:
                h = .12*n
            heights.append(h)
    orm, normals = [], []
    strength = {"wool": .32, "leather": .16, "wood": .12, "brass": .05}.get(family, .035)
    for y in range(size):
        for x in range(size):
            h = heights[y*size+x]
            dx = (heights[y*size+(x+1)%size]-heights[y*size+(x-1)%size])*strength
            dy = (heights[((y+1)%size)*size+x]-heights[((y-1)%size)*size+x])*strength
            length = math.sqrt(dx*dx+dy*dy+1)
            normals.extend([.5-dx/length/2, .5-dy/length/2, .5+1/length/2, 1])
            orm.extend([1, max(.04, min(1, roughness+h*.06)), metallic, 1])
    result = []
    for suffix, pixels in [("ORM", orm), ("normal", normals)]:
        # Dots are treated as image extensions by the GLB exporter, which would
        # give normal and ORM maps the same basename during Godot extraction.
        image = bpy.data.images.new(f"{family}_r{round(roughness*100):02d}_m{round(metallic*100):02d}_{suffix}", width=size, height=size)
        image.colorspace_settings.name = "Non-Color"
        image.pixels.foreach_set(pixels)
        image.pack()
        result.append(image)
    _images[key] = result
    return result

def finish(material, family="paint", roughness=.42, metallic=0):
    nodes, links = material.node_tree.nodes, material.node_tree.links
    p = nodes.get("Principled BSDF")
    orm, normal = detail_maps(family, roughness, metallic)
    tex = nodes.new("ShaderNodeTexImage"); tex.image = orm; tex.label = "Packed physical surface"
    split = nodes.new("ShaderNodeSeparateColor")
    links.new(tex.outputs["Color"], split.inputs["Color"])
    links.new(split.outputs["Green"], p.inputs["Roughness"])
    links.new(split.outputs["Blue"], p.inputs["Metallic"])
    tex = nodes.new("ShaderNodeTexImage"); tex.image = normal
    bump = nodes.new("ShaderNodeNormalMap")
    links.new(tex.outputs["Color"], bump.inputs["Color"])
    links.new(bump.outputs["Normal"], p.inputs["Normal"])
    if family in ("wool", "leather"):
        p.inputs["Sheen Weight"].default_value = .22 if family == "wool" else .08
    return material

def material(name, color, family="paint", roughness=.42, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*color, 1)
    return finish(m, family, roughness, metallic)

def planar_uv(obj, scale=.55):
    """World-scale microdetail; keep authored carpet and sphere UVs untouched."""
    if obj.type != "MESH" or obj.data.uv_layers: return
    uv = obj.data.uv_layers.new(name="Surface grain")
    for face in obj.data.polygons:
        dominant = max(range(3), key=lambda i: abs(face.normal[i]))
        axes = [(1,2), (0,2), (0,1)][dominant]
        for i in face.loop_indices:
            p = obj.data.vertices[obj.data.loops[i].vertex_index].co
            uv.data[i].uv = (p[axes[0]]/scale, p[axes[1]]/scale)
