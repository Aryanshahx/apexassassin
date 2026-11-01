#!/usr/bin/env python3
"""Render original, coherent top-down environment props with Blender 4.x.

All geometry, procedural materials, lighting and camera are authored in this
file. The user's two sheets are visual references only; no reference pixels are
copied. Static transparent PNGs are suitable for the existing 2D Godot game.

Run: blender --background --threads 3 --python tools/render_v69_props.py -- [asset ...]
"""
import bpy, math, sys, random
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = Path(bpy.data.filepath).parent if bpy.data.filepath else Path.cwd()
# Always invoked from the project root; a caller can change output explicitly.
OUT = ROOT / 'assets/environment/v69'
OUT.mkdir(parents=True, exist_ok=True)
random.seed(690021)

# Clear default scene and set one repeatable orthographic camera and lighting.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=64
# Debian's Blender package may not include OpenImageDenoise; enough samples
# give stable CPU renders without making the build depend on that library.
scene.cycles.use_denoising=False
scene.render.resolution_x=384
scene.render.resolution_y=384
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'
scene.render.image_settings.color_depth='8'
scene.render.film_transparent=True
scene.world.color=(0.28,0.28,0.28)
scene.world.use_nodes=True
scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(0.48,0.52,0.58,1)
scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=0.42
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.render.image_settings.compression=25

bpy.ops.object.camera_add(location=(0,-5,12))
CAM=bpy.context.object;CAM.name='Production camera';CAM.data.type='ORTHO';scene.camera=CAM

def area(name, location, power, size, color):
    bpy.ops.object.light_add(type='AREA',location=location)
    ob=bpy.context.object;ob.name=name;ob.data.energy=power;ob.data.shape='DISK';ob.data.size=size;ob.data.color=color
    ob.rotation_euler=(Vector((0,0,.25))-ob.location).to_track_quat('-Z','Y').to_euler()
    return ob
LIGHTS=[area('large upper-left softbox',(-4,-3,7),650,5.0,(1.0,.91,.79)),
        area('cool gentle fill',(4,3,7),220,5.0,(.72,.82,1.0))]
STAGE={CAM,*LIGHTS}

def material(name, low, high=None, *, metal=0, rough=.7, grain=(1,1,1), scale=22, bump=.08):
    m=bpy.data.materials.new(name);m.diffuse_color=(*low,1);m.use_nodes=True
    n=m.node_tree.nodes;n.clear();links=m.node_tree.links
    out=n.new('ShaderNodeOutputMaterial');bs=n.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
    links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    if high:
        tex=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');mapping.inputs['Scale'].default_value=grain
        noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=3.0;noise.inputs['Roughness'].default_value=.64
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.20;ramp.color_ramp.elements[0].color=(*low,1)
        ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=(*high,1)
        links.new(tex.outputs['Generated'],mapping.inputs['Vector']);links.new(mapping.outputs['Vector'],noise.inputs['Vector']);links.new(noise.outputs['Fac'],ramp.inputs['Fac']);links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
        if bump:
            b=n.new('ShaderNodeBump');b.inputs['Strength'].default_value=bump;b.inputs['Distance'].default_value=.025
            links.new(noise.outputs['Fac'],b.inputs['Height']);links.new(b.outputs['Normal'],bs.inputs['Normal'])
    else:bs.inputs['Base Color'].default_value=(*low,1)
    return m

MAT={
 'wood':material('aged warm oak',(0.24,.105,.035),(.53,.285,.10),grain=(1,8,1),scale=9,bump=.13),
 'wood_trim':material('warm oak edges',(.32,.145,.045),(.68,.39,.14),grain=(1,9,1),scale=8,bump=.10),
 'wood_dark':material('dark wood grain',(.13,.055,.019),(.35,.16,.045),grain=(1,8,1),scale=11,bump=.12),
 'metal':material('brushed graphite metal',(.10,.12,.14),(.24,.28,.30),metal=.60,rough=.48,grain=(1,5,1),scale=30,bump=.06),
 'iron':material('black iron fasteners',(.045,.055,.060),(.12,.13,.14),metal=.7,rough=.38,scale=45,bump=.02),
 'steel':material('brushed pale steel',(.23,.29,.34),(.43,.49,.52),metal=.62,rough=.50,scale=25,bump=.07),
 'green':material('military olive enamel',(.12,.17,.075),(.26,.34,.14),metal=.25,rough=.60,scale=22,bump=.04),
 'red':material('industrial red enamel',(.30,.035,.025),(.56,.09,.06),metal=.30,rough=.52,scale=30,bump=.04),
 'blue':material('industrial blue enamel',(.035,.10,.23),(.075,.25,.42),metal=.30,rough=.50,scale=30,bump=.04),
 'yellow':material('safety ochre',(.48,.28,.035),(.78,.53,.07),metal=.15,rough=.58,scale=30,bump=.04),
 'concrete':material('fine concrete',(.20,.22,.23),(.39,.40,.40),rough=.9,scale=58,bump=.12),
 'sand':material('canvas sandbag',(.28,.21,.125),(.48,.38,.235),rough=.94,scale=37,bump=.13),
 'cardboard':material('corrugated cardboard',(.36,.20,.075),(.58,.36,.14),rough=.9,scale=35,bump=.07),
 'tape':material('packing tape',(.62,.41,.20),(.80,.61,.34),rough=.62,scale=25,bump=.015),
 'rubber':material('tire rubber',(.028,.032,.034),(.075,.082,.08),rough=.92,scale=45,bump=.10),
 'leaf':material('dark olive foliage',(.075,.15,.045),(.20,.30,.08),rough=.88,scale=30,bump=.12),
 'glass':material('lamp lens',(.75,.56,.30),(.95,.78,.47),rough=.3,scale=10,bump=0),
}


def assign(obj,mat):
    obj.data.materials.append(MAT[mat] if isinstance(mat,str) else mat)
    return obj

def box(name,center,size,mat,bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center)
    ob=bpy.context.object;ob.name=name;ob.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('small manufactured bevel','BEVEL');mod.width=bevel;mod.segments=2
        mod=ob.modifiers.new('weighted corner normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    return assign(ob,mat)

def cylinder(name,center,radius,depth,mat,vertices=32,rotation=(0,0,0),bevel=.012):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=center,rotation=rotation)
    ob=bpy.context.object;ob.name=name
    if bevel:
        mod=ob.modifiers.new('rounded rim','BEVEL');mod.width=bevel;mod.segments=2
        mod=ob.modifiers.new('weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    for f in ob.data.polygons:f.use_smooth=True
    return assign(ob,mat)

def torus(name,center,major,minor,mat,rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=40,minor_segments=10,location=center,major_radius=major,minor_radius=minor,rotation=rotation)
    ob=bpy.context.object;ob.name=name
    for f in ob.data.polygons:f.use_smooth=True
    return assign(ob,mat)

def beam_xy(name,p0,p1,width,depth,mat):
    a,b=Vector(p0),Vector(p1);ob=box(name,(a+b)*.5,((b-a).length,width,depth),mat,.009)
    ob.rotation_euler.z=math.atan2(b.y-a.y,b.x-a.x);return ob

def beam_xz(name,p0,p1,width,depth,mat):
    a,b=Vector(p0),Vector(p1);ob=box(name,(a+b)*.5,((b-a).length,width,depth),mat,.009)
    ob.rotation_euler.y=-math.atan2(b.z-a.z,b.x-a.x);return ob

def crate_wood(darker=False):
    wood='wood_dark' if darker else 'wood';trim='wood' if darker else 'wood_trim'
    box('solid wooden crate',(0,0,.31),(1.0,1.0,.62),wood,.026)
    # Small inset boards, framed by continuous raised edge beams.
    for i in range(5):
        x=-.38+i*.19
        box('top plank',(x,0,.625),(.175,.85,.025),wood,.008)
    for y in (-.45,.45):box('top horizontal frame',(0,y,.66),(1.0,.12,.075),trim,.012)
    for x in (-.45,.45):box('top vertical frame',(x,0,.66),(.12,.79,.075),trim,.012)
    beam_xy('top diagonal brace',(-.37,-.35,.676),(.37,.35,.676),.105,.07,trim)
    beam_xy('top crossing brace',(-.37,.35,.686),(.37,-.35,.686),.105,.07,trim)
    # The visible front face gives the top-down object its restrained 2.5D depth.
    for z in (.095,.53):box('front horizontal rail',(0,-.508,z),(1.0,.07,.095),trim,.009)
    for x in (-.45,.45):box('front vertical rail',(x,-.518,.31),(.09,.07,.48),trim,.009)
    beam_xz('front diagonal brace',(-.38,-.552,.13),(.38,-.552,.50),.055,.08,trim)
    beam_xz('front crossing brace',(-.38,-.562,.50),(.38,-.562,.13),.055,.08,trim)
    for x in (-.45,.45):
        for y in (-.45,.45):cylinder('top corner nail',(x,y,.705),.022,.018,'iron',vertices=12,bevel=.004)


def metal_box(colour='steel', long=False, style='plain'):
    sx=1.65 if long else 1.0
    trim='metal' if colour in ('green','red','blue') else 'steel'
    box('formed metal body',(0,0,.26),(sx,1.0,.52),colour,.04)
    box('recessed metal lid',(0,0,.535),(sx*.89,.86,.055),colour,.018)
    for y in (-.46,.46):box('top perimeter rail',(0,y,.57),(sx,.075,.07),trim,.01)
    for x in (-sx*.46,sx*.46):box('top perimeter rail',(x,0,.57),(.075,.86,.07),trim,.01)
    for x in (-sx*.36,sx*.36):
        for y in (-.36,.36):cylinder('top bolted fastener',(x,y,.602),.019,.018,'iron',vertices=12,bevel=.003)
    # A lip and pair of catches on the visible front are useful at game scale.
    box('front lip',(0,-.505,.39),(sx*.91,.045,.055),trim,.008)
    for x in (-sx*.3,sx*.3):
        box('front latch',(x,-.538,.30),(.10,.04,.16),'iron',.01)
        box('front latch bright',(x,-.565,.32),(.055,.016,.075),'steel',.005)
    if style=='cross':
        beam_xy('armored lid brace',(-sx*.36,-.32,.59),(sx*.36,.32,.59),.065,.04,'steel')
        beam_xy('armored lid brace',(-sx*.36,.32,.595),(sx*.36,-.32,.595),.065,.04,'steel')
    elif style=='ammo':
        for x in (-.08,0,.08):box('stencilled ammo marks',(x,0,.575),(.035,.21,.008),'yellow',.004)
    elif style=='tool':
        box('top carrying handle',(0,0,.63),(.34,.065,.055),'iron',.01)
    elif style=='hazard':
        box('hazard inset', (0,0,.582),(sx*.68,.52,.025), 'hazard_stripes', .006)
    else:
        for y in (-.20,.20):box('lid embossing',(0,y,.568),(sx*.70,.025,.025),trim,.004)


def barrel(colour='red'):
    cylinder('drum body',(0,0,.39),.37,.78,colour,vertices=48,bevel=.018)
    for z in (.10,.30,.55,.71):torus('drum protective rim',(0,0,z),.37,.018,'metal')
    cylinder('drum lid',(0,0,.79),.36,.035,colour,vertices=48,bevel=.008)
    torus('lid seam',(0,0,.813),.31,.012,'iron')
    for x,y in ((-.15,-.04),(.15,.10)):
        cylinder('steel filling plug',(x,y,.818),.045,.018,'iron',vertices=16,bevel=.004)
        cylinder('plug highlight',(x,y,.830),.023,.008,'steel',vertices=12,bevel=.002)
    # The small top stencil is original graphic geometry, not reference pixels.
    if colour in ('red','yellow'):
        cylinder('warning marker',(0,-.03,.817),.10,.01,'yellow' if colour=='red' else 'iron',vertices=5,bevel=0)


def pallet(plastic=False, with_boxes=False):
    wood='blue' if plastic else 'wood';edge='metal' if plastic else 'wood_dark'
    for x in (-.58,0,.58):box('pallet bearer',(x,0,.075),(.13,.95,.15),edge,.01)
    for y in (-.40,-.20,0,.20,.40):
        box('pallet deck board',(0,y,.18),(1.5,.16,.075),wood,.012)
        if not plastic:
            for x in (-.58,.58):cylinder('deck nail',(x,y,.223),.016,.01,'iron',vertices=10,bevel=.002)
    if with_boxes:
        for x,y in ((-.37,0),(.34,.04)):
            box('packed carton',(x,y,.42),(.57,.54,.44),'cardboard',.018)
            box('packing tape',(x,y,.648),(.12,.54,.012),'tape',.002)


def cardboard(stack=False):
    def one(x,y,z,s):
        box('shipping carton',(x,y,z+s*.5),(s,s*.90,s),'cardboard',.025)
        box('paper tape top',(x,y,z+s+.009),(s*.18,s*.90,.018),'tape',.003)
        box('paper tape front',(x,y-s*.455,z+s*.5),(s*.18,.015,s*.95),'tape',.002)
    if stack:
        one(-.27,-.05,0,.70);one(.33,0,0,.58);one(0,.12,.70,.53)
    else:one(0,0,0,1.0)


def sandbag_wall():
    for y in (-.24,.18):
        for x in (-.68,0,.68):
            ob=box('rounded canvas sandbag',(x,y,.14),(.68,.43,.27),'sand',.105)
            ob.modifiers['small manufactured bevel'].segments=4
            box('stitched bag end',(x+.29,y,.282),(.025,.32,.009),'wood_dark',.003)
    for x in (-.34,.34):
        ob=box('top-layer sandbag',(x,-.04,.38),(.68,.41,.25),'sand',.10)
        ob.modifiers['small manufactured bevel'].segments=4
        box('stitched bag end',(x+.29,-.04,.508),(.025,.30,.009),'wood_dark',.003)


def tire_stack():
    for z in (.13,.34,.55):
        torus('tire',(0,0,z),.34,.105,'rubber')
        for a in range(12):
            angle=math.tau*a/12; x,y=.34*math.cos(angle),.34*math.sin(angle)
            ob=box('tread notch',(x,y,z+.073),(.045,.10,.02),'metal',.003);ob.rotation_euler.z=angle


def fence():
    box('fence footing',(0,0,.09),(1.0,.78,.18),'concrete',.025)
    for x in (-.44,.44):box('upright frame',(x,0,.47),(.09,.08,.79),'steel',.012)
    for z in (.20,.82):box('cross frame',(0,0,z),(1.0,.08,.09),'steel',.012)
    for x in (-.34,-.17,0,.17,.34):box('wire mesh',(x,.0,.51),(.02,.022,.57),'metal',.003)
    for z in (.27,.40,.53,.66,.78):box('wire mesh',(0,0,z),(.80,.022,.018),'metal',.003)


def industrial_pipe(vertical=True):
    # Cylinder lies in the floor plane. Bands and brackets share one light.
    cylinder('pipe body',(0,0,.29),.30,2.55,'metal',vertices=48,rotation=(math.pi/2,0,0),bevel=.015)
    for y in (-1.05,-.37,.37,1.05):
        torus('industrial pipe band',(0,y,.29),.305,.038,'steel',rotation=(math.pi/2,0,0))
    for y in (-.9,.9):box('pipe mounting foot',(0,y,.07),(.85,.23,.14),'metal',.018)
    if not vertical:rotate_art(math.pi/2)


def shipping_container(colour='blue',vertical=False):
    box('container chassis',(0,0,.27),(2.9,.94,.54),colour,.035)
    # Narrow corrugations are real geometry, not stretched thumbnail pixels.
    for i in range(15):
        x=-1.30+i*(2.6/14)
        box('roof corrugation',(x,0,.558),(.065,.84,.035),colour,.006)
    for y in (-.43,.43):box('container roof edge',(0,y,.58),(2.9,.075,.07),'metal',.012)
    for x in (-1.40,1.40):box('container end trim',(x,0,.58),(.075,.85,.07),'metal',.012)
    box('front footing',(0,-.476,.08),(2.9,.05,.11),'metal',.008)
    for x in (-1.3,-.65,0,.65,1.3):
        box('front support',(x,-.484,.30),(.06,.045,.39),'metal',.007)
    if vertical:rotate_art(math.pi/2)


def concrete_wall(style='plain',vertical=False):
    body='red' if style=='jersey' else 'concrete'
    box('concrete barrier',(0,0,.28),(2.3,.78,.56),body,.045)
    box('wall cap',(0,0,.585),(2.25,.75,.07),'concrete',.018)
    box('wall lower lip',(0,-.405,.08),(2.3,.06,.12),'metal',.007)
    if style=='hazard':box('safety stripe panel',(0,-.06,.63),(1.9,.36,.025),'hazard_stripes',.005)
    elif style=='jersey':box('road barrier inset',(0,-.08,.63),(.42,.50,.022),'concrete',.005)
    else:
        for x in (-.75,0,.75):box('concrete casting joint',(x,0,.631),(.016,.64,.008),'metal',.001)
    if vertical:rotate_art(math.pi/2)


def floor_vent():
    box('fan casing',(0,0,.10),(1.0,1.0,.20),'steel',.035)
    box('fan recessed panel',(0,0,.215),(.79,.79,.035),'metal',.018)
    torus('fan ring',(0,0,.24),.32,.025,'steel')
    for i in range(6):
        ob=box('fan blade',(0,0,.25),(.56,.075,.025),'steel',.008);ob.rotation_euler.z=math.pi*i/6
    cylinder('fan hub',(0,0,.275),.075,.035,'iron',vertices=24,bevel=.008)
    for x in (-.41,.41):
        for y in (-.41,.41):cylinder('housing bolt',(x,y,.224),.022,.015,'iron',vertices=12,bevel=.003)


def grate():
    box('drain frame',(0,0,.035),(1,1,.07),'steel',.02)
    box('drain inset',(0,0,.072),(.84,.84,.012),'iron',.008)
    for x in (-.30,-.18,-.06,.06,.18,.30):box('drain bar',(x,0,.088),(.045,.80,.025),'steel',.004)


def manhole():
    cylinder('manhole cover',(0,0,.06),.48,.12,'steel',vertices=48,bevel=.015)
    torus('cover outer rim',(0,0,.128),.40,.018,'metal')
    for x in (-.15,0,.15):
        for y in (-.15,0,.15):cylinder('drain hole',(x,y,.129),.025,.012,'iron',vertices=12,bevel=.001)


def floor_lamp():
    box('recessed floor lamp frame',(0,0,.045),(1.0,.48,.09),'metal',.035)
    box('warm protected lens',(0,0,.096),(.76,.28,.02),'glass',.02)
    for x in (-.38,.38):cylinder('light screw',(x,0,.11),.025,.014,'steel',vertices=12,bevel=.002)


def bush(plant=False):
    if plant:
        cylinder('plant pot',(0,0,.20),.25,.4,'cardboard',vertices=24,bevel=.02)
        torus('plant pot rim',(0,0,.41),.24,.035,'wood_dark')
        cylinder('plant soil',(0,0,.41),.21,.025,'wood_dark',vertices=24,bevel=0)
    else:cylinder('bush base',(0,0,.09),.30,.18,'wood_dark',vertices=24,bevel=.01)
    points=[(0,0,.48),(.22,0,.45),(-.2,0,.43),(0,.22,.43),(0,-.2,.43),(.14,.14,.57),(-.14,-.14,.54)]
    for x,y,z in points:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=.23,location=(x,y,z))
        ob=bpy.context.object;ob.name='foliage';ob.scale=(1,.92,1.1);assign(ob,'leaf')


def storage_rack():
    # Thick rack base means the same rectangle blocks movement as the art.
    box('rack footing',(0,0,.09),(1.7,1.0,.18),'metal',.015)
    for x in (-.77,.77):
        for y in (-.4,.4):box('rack post',(x,y,.50),(.08,.08,.88),'blue',.012)
    for z in (.25,.54,.93):box('rack shelf',(0,0,z),(1.7,.96,.065),'steel',.01)
    for x in (-.42,.38):
        box('stored carton',(x,0,.70),(.55,.62,.27),'cardboard',.012)
        box('carton tape',(x,0,.84),(.08,.62,.012),'tape',.002)


def rotate_art(angle):
    bpy.context.view_layer.update()
    mat=Matrix.Rotation(angle,4,'Z')
    for ob in list(scene.objects):
        if ob not in STAGE and ob.type=='MESH':ob.matrix_world=mat @ ob.matrix_world


def hazard_material():
    m=bpy.data.materials.new('original diagonal safety paint');m.diffuse_color=(.68,.42,.04,1);m.use_nodes=True
    n=m.node_tree.nodes;n.clear();L=m.node_tree.links
    out=n.new('ShaderNodeOutputMaterial');bs=n.new('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=.70
    uv=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeMapping');mapping.inputs['Rotation'].default_value[2]=math.radians(28)
    wave=n.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='X';wave.inputs['Scale'].default_value=6.0;wave.inputs['Distortion'].default_value=.07
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
    ramp.color_ramp.elements[0].position=.48;ramp.color_ramp.elements[0].color=(.035,.039,.035,1)
    ramp.color_ramp.elements[1].position=.50;ramp.color_ramp.elements[1].color=(.80,.48,.055,1)
    L.new(uv.outputs['Generated'],mapping.inputs['Vector']);L.new(mapping.outputs['Vector'],wave.inputs['Vector']);L.new(wave.outputs['Color'],ramp.inputs['Fac']);L.new(ramp.outputs['Color'],bs.inputs['Base Color']);L.new(bs.outputs['BSDF'],out.inputs['Surface'])
    return m

MAT['hazard_stripes']=hazard_material()

def clear_art():
    for ob in list(scene.objects):
        if ob not in STAGE:bpy.data.objects.remove(ob,do_unlink=True)


def render(name):
    arts=[ob for ob in scene.objects if ob not in STAGE and ob.type=='MESH']
    if not arts:raise RuntimeError('No geometry for '+name)
    bpy.context.view_layer.update()
    coords=[ob.matrix_world@Vector(v) for ob in arts for v in ob.bound_box]
    minx,maxx=min(v.x for v in coords),max(v.x for v in coords)
    miny,maxy=min(v.y for v in coords),max(v.y for v in coords)
    minz,maxz=min(v.z for v in coords),max(v.z for v in coords)
    center=Vector(((minx+maxx)/2,(miny+maxy)/2,(minz+maxz)/2))
    CAM.location=center+Vector((0,-5,12))
    CAM.rotation_euler=(center-CAM.location).to_track_quat('-Z','Y').to_euler()
    # Orthographic projected height: y and height share the same tilted view.
    theta=math.atan2(5,12)
    projected_height=(maxy-miny)*math.cos(theta)+(maxz-minz)*math.sin(theta)
    CAM.data.ortho_scale=max(maxx-minx,projected_height)*1.16
    scene.render.filepath=str(OUT/(name+'.png'))
    print('RENDER',name,'objects',len(arts),'size',round(CAM.data.ortho_scale,3),flush=True)
    bpy.ops.render.render(write_still=True)


def camo_box():
    metal_box('green',long=True)
    box('canvas wrapped supply',(0,.02,.625),(1.35,.68,.09),'sand',.03)
    for x in (-.4,.4):box('canvas tie-down',(x,.02,.68),(.075,.7,.035),'green',.006)

ASSETS={
    'crate_wood':lambda:crate_wood(),
    'crate_wood_small':lambda:crate_wood(True),
    'crate_steel':lambda:metal_box('steel',style='cross'),
    'crate_green':lambda:metal_box('green'),
    'crate_ammo':lambda:metal_box('green',style='ammo'),
    'crate_tool':lambda:metal_box('red',style='tool'),
    'crate_hazard':lambda:metal_box('concrete',style='hazard'),
    'crate_metal':lambda:metal_box('steel',long=True),
    'crate_camo':camo_box,
    'cargo_box':lambda:cardboard(False),
    'cargo_stack':lambda:cardboard(True),
    'barrel_red':lambda:barrel('red'),
    'barrel_blue':lambda:barrel('blue'),
    'barrel_yellow':lambda:barrel('yellow'),
    'barrel_gray':lambda:barrel('steel'),
    'pallet':lambda:pallet(),
    'pallet_boxes':lambda:pallet(with_boxes=True),
    'pallet_plastic':lambda:pallet(plastic=True),
    'sandbags':sandbag_wall,
    'tires':tire_stack,
    'fence':fence,
    'pipe_v':lambda:industrial_pipe(True),
    'pipe_h':lambda:industrial_pipe(False),
    'container_blue_h':lambda:shipping_container('blue'),
    'container_blue_v':lambda:shipping_container('blue',True),
    'container_red_h':lambda:shipping_container('red'),
    'container_red_v':lambda:shipping_container('red',True),
    'wall_concrete_h':lambda:concrete_wall(),
    'wall_concrete_v':lambda:concrete_wall(vertical=True),
    'wall_hazard_h':lambda:concrete_wall('hazard'),
    'wall_hazard_v':lambda:concrete_wall('hazard',True),
    'wall_jersey_h':lambda:concrete_wall('jersey'),
    'wall_jersey_v':lambda:concrete_wall('jersey',True),
    'vent':floor_vent,
    'grate':grate,
    'manhole':manhole,
    'lamp':floor_lamp,
    'plant':lambda:bush(True),
    'bush':lambda:bush(False),
    'storage_rack':storage_rack,
}
requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
if not requested:requested=list(ASSETS)
for name in requested:
    clear_art()
    if name not in ASSETS:raise SystemExit('Unknown requested asset: '+name)
    ASSETS[name]()
    render(name)
