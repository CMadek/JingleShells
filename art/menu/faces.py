"""Menu facial shapes and corrective blinks on the existing elf sculpt."""
from mathutils import Vector

EXPRESSIONS = ('Veteran', 'Smirk', 'Skeptic')
FACE_PREFIXES = ('Eye white', 'Bright pupil', 'Eye highlight',
                 'Sculpted upper eyelid', 'Expressive brow', 'Friendly stitched smile')
lid_material = material('Menu eyelid crease', (.25, .135, .075))

def eye_parameters(expression, side):
    if expression == 'Veteran':
        return .48, .15
    if expression == 'Smirk':
        return (.57 if side < 0 else .72), (.10 if side < 0 else -.06)
    return (.43 if side < 0 else .68), (.18 if side < 0 else -.12)

def face_point(name, p, expression):
    x, y, z = p
    side = -1 if name.endswith('L') else 1
    scale, slope = eye_parameters(expression, side)
    eye = x - side * .088
    if name.startswith(('Eye white', 'Bright pupil', 'Eye highlight', 'Sculpted upper eyelid')):
        z = 1.532 + (z - 1.535) * scale + side * eye * slope
        if name.startswith('Sculpted upper eyelid'):
            y -= .009
    elif name.startswith('Expressive brow'):
        outer = side * eye
        if expression == 'Veteran':
            z = 1.586 + outer * .35 + (z - 1.61) * .24
        elif expression == 'Smirk':
            z = (1.596 if side < 0 else 1.619) + outer * (.19 if side < 0 else -.11) + (z-1.61)*.45
        else:
            z = (1.581 if side < 0 else 1.618) + outer * (.33 if side < 0 else -.12) + (z-1.61)*.35
        y -= .014
    elif name.startswith('Friendly stitched smile'):
        old_line = 1.387 + (x/.055)**2 * .020
        thickness = z - old_line
        t = max(-1, min(1, x/.055))
        if expression == 'Veteran':
            z = 1.395 - .004*t*t + thickness
        elif expression == 'Smirk':
            z = 1.395 + .012*t + .006*t*t + thickness
        else:
            z = 1.395 - .004*t + thickness
    return Vector((x, y, z))

for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH' or not obj.name.startswith(FACE_PREFIXES):
        continue
    if obj.name.startswith('Sculpted upper eyelid'):
        # A fine crease stays visible at the instant the eyes are fully closed.
        # Narrow the existing tube instead of adding a floating face overlay.
        side = -1 if obj.name.endswith('L') else 1
        inverse = obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            p = obj.matrix_world @ vertex.co
            radial = Vector((p.x-side*.088, 0, p.z-1.535))
            radius = radial.length
            if radius > 0:
                radial *= (.047+(radius-.047)*.45)/radius
            p.x = side*.088 + radial.x
            p.z = 1.535 + radial.z
            p.y = -.226 + (p.y+.226)*.45
            vertex.co = inverse @ p
        obj.data.materials.clear()
        obj.data.materials.append(lid_material)
    obj.shape_key_add(name='Basis', from_mix=False)
    inverse = obj.matrix_world.inverted()
    for expression in EXPRESSIONS:
        key = obj.shape_key_add(name=expression, from_mix=False)
        key.value = 0
        blink = obj.shape_key_add(name=expression + 'Blink', from_mix=False)
        blink.value = 0
        for i, vertex in enumerate(obj.data.vertices):
            original = obj.matrix_world @ vertex.co
            posed = face_point(obj.name, original, expression)
            key.data[i].co = inverse @ posed
            if obj.name.startswith(('Eye white', 'Bright pupil', 'Eye highlight', 'Sculpted upper eyelid')):
                closed = posed.copy()
                side = -1 if obj.name.endswith('L') else 1
                line = 1.532 + side * (posed.x-side*.088) * .04
                closed.z = line + (posed.z-line) * .025
                if obj.name.startswith('Sculpted upper eyelid'):
                    radius = Vector((original.x-side*.088,0,original.z-1.535)).length
                    closed.z = line + (radius-.047)*.9
                else:
                    closed.y += .035
                # Used together with the expression: no inverted squint geometry.
                blink.data[i].co = vertex.co + inverse.to_3x3() @ (closed-posed)
