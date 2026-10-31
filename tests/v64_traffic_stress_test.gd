extends SceneTree
func _init(): call_deferred("run")
func run():
 var gs=root.get_node("GameState");gs.sound_enabled=false
 var walls=[];var overlaps=[];var lowest=INF
 for n in range(1,101):
  gs.start_level(n);await process_frame;await process_frame
  var lv=current_scene;lv.set_physics_process(false);lv.player_pos=Vector2(-10000,-10000)
  var near:Vector2i=lv.guard_walkable_regions[0][int(lv.guard_walkable_regions[0].size()/2)]
  var target:Vector2=lv._cell_center(near.x,near.y)
  for g in lv.guards:
   g.state=lv.GState.ALERT;g.last_seen=target;g.path.clear();g.sees_player=false;g.chase_left=lv._chase_duration(g)
  var gap=INF;var solid=0
  for t in range(600):
   lv._update_guards(1.0/60.0)
   for i in range(lv.guards.size()):
    var g=lv.guards[i]
    if lv._guard_solid(g.pos):solid+=1
    for j in range(i):gap=minf(gap,g.pos.distance_to(lv.guards[j].pos))
  if gap<lv.GUARD_GAP-0.06:overlaps.append([n,gap])
  if solid>0:walls.append([n,solid])
  lowest=minf(lowest,gap)
  if n%20==0:print("through ",n," overlap levels=",overlaps.size()," walls=",walls.size())
 print("V64 ALERT TRAFFIC walls=",walls," overlaps=",overlaps," min_gap=",lowest)
 quit(1 if not walls.is_empty() or not overlaps.is_empty() else 0)
