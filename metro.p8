pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
--main
debug={}
debug_on=false
function _init()
	pal(13,131,1)
	pal(14,139,1)
	reset_game()
	sfx(0)
end

function _update60()
	f+=1
	_upd()
end

function _draw()
	_drw()
	if (shakedur>=0) doshake()
	draw_debug()
end

dirx={-1,1,0,0,1,1,-1,-1}
diry={0,0,-1,1,-1,1,1,-1}

adjx={-1,0,1,1,1,0,-1,-1}
adjy={-1,-1,-1,0,1,1,1,0}

function splash()
	
end

function reset_game()
	pal(11,138,1)
	f=0
	tk=1
	cx,cy=8,8
	reset_state()
	mapgen()
	add(blnc,cash)
	shakedur=10
	_upd=upd_splash
	_drw=drw_splash
end

function reset_state()
	ntwk=blankmap(0)
	stns={}
	lns={}
	day=1
	mode=1
	vmode=1
	mn_opt=1
	do_trk=false
	toolbar=false
	tool=1
	prev_cx,prev_cy=0,0
	cash=10000
	profit=0
	loss=0
	pop={}
	blnc={}
	loop_exists=false
	route={}
end
-->8
--updates

function upd_game()
	handle_tk()
	if is_gover() then
		_upd=upd_gover
		_drw=drw_gover
	end

	if toolbar then
		mode=tool
		if btnp(0) then
			if (tool>1) tool-=1
		elseif btnp(1) then
			if (tool<#tbspr) tool+=1
		elseif btnp(3) then
			toolbar=false
			cx,cy=prev_cx,prev_cy
			return
		end
		cx=tbpos[tool]
	elseif mgmt then
		cache=mgopt
		cx=(mgmarg+mgpad)/8
		cy=mgmarg/8+mgopt*2
		itval=mgitems[mgopt].val
		itmax=mgitems[mgopt].max
		if not mgitems[mgopt].lock then
			if btnp(0) then 
				if (itval==0) then
					shakedur=2
				else 
					mgitems[mgopt].val = max(mgitems[mgopt].val-1,0)
					if mgopt==2 then
						del(trns,trns[#trns])
						refund(prc.trn)
					end
				end
			elseif btnp(1) then 
				if (itval==itmax) then
					shakedur=2
				else 
					mgitems[mgopt].val = min(mgitems[mgopt].val+1,mgitems[mgopt].max)
					if mgopt==2 then
						add_train()
						purchase(prc.trn)
					end
				end
			end
		end
		if btnp(2) then
			mgopt=max(mgopt-1,1)
		elseif btnp(3) then
			mgopt=min(mgopt+1,#mgitems)
		elseif btnp(4) or btnp(5) then
			mgmt=false
			vmode=1
			apply_mgmt_changes()
			cx,cy=prev_cx,prev_cy		
		end
	else
		for i=0,3 do
			if btnp(i) then
				dx=cx+dirx[i+1]
				dy=cy+diry[i+1]
				if inbounds(dx,dy) then
					cx,cy=dx,dy
--					calcdist(cx,cy)
				end
			end
		end
	end
	
	if btnp(❎) then
		if toolbar then 
			toolbar=false
			mode=tool
			cx,cy=prev_cx,prev_cy
			if tool==5 then
				mgmt=true
			end
		else 
			map_tool_to_act()
		end
	end
	
	if btnp(🅾️) then
		if toolbar then
			toolbar=false
			mode=tool
			cx,cy=prev_cx,prev_cy
		else
			toolbar=true
			prev_cx,prev_cy=cx,cy
			cx=tbpos[tool]
			cy=0
		end
	end
	
	if tk%10==0 and f==0 then
		handle_day()
	end
end

function upd_splash()
	if btnp(❎) or btnp(🅾️) then
		_upd=upd_menu
		_drw=drw_menu
	end
end

function upd_menu()
	if btnp(⬆️) then
		mn_opt=max(mn_opt-1,1)
		play('opt-move')
	elseif btnp(⬇️) then
		mn_opt=min(mn_opt+1,#mn_items)
		play('opt-move')
	else
		if btnp(❎) or btnp(🅾️) then
			if mn_opt==1 then		
				_upd=upd_game
				_drw=drw_game
			else
				_upd=upd_manual
				_drw=drw_manual
			end
			play('opt-select')
		end
	end
end

function upd_manual()
	if btnp(🅾️) or btnp(❎) then
		_upd=upd_menu
		_drw=drw_menu
	end
end

function upd_gover()
	if btnp(❎) then
		reset_game()
	end
end

function handle_tk()
	if (f%60==0) then
		tk+=1
		if (#trns>0 and loop_exists) then
			for t in all(trns) do
			 	t.move()
			 end
		end
	end

	if (f>=60) f=0 
end

--------
--day--
--------

function handle_day()
	day+=1
	
	cash=calc_budget()
	add_data()
	draw_profit()
	profit=0
	if #stns>0 then
		gen_pass()
	end
end

----------------
--calculations--
----------------

function calc_budget()
	calc_maint()
	return cash+profit
end

function apply_mgmt_changes()
	prc.trk=mgitems[1].val
end

-----------
--actions--
-----------

function map_tool_to_act()
	if 				tool==1 then do_cursor()
	elseif tool==2 then do_station()
	elseif tool==3 then do_track()
	elseif tool==4 then do_delete()
	elseif tool==5 then show_mgmt()
	end
	if #stns>1 and tool>=2 and tool<=5 then
		loop_handler()
		if loop_exists and #trns==0 then
			purchase(prc.trn)
			add_train()
		end
	end
end

function do_cursor()
	apply_select()
end

function do_station()
	if in_river(cx,cy) then
		add(msgs,new_msg('cannot place in river',8))
		return
	elseif ntwk[cx][cy]==1 then
		return 
	else
		if cash<prc.stn then
			add(msgs,new_msg('not enough money!',8))
		else
			ntwk[cx][cy]=1
			add(stns,new_stn(cx,cy))
			purchase(prc.stn)
			play('stn')
			shakedur=2
		end
	end
end

function do_track()
	if ntwk[cx][cy]==0 then
		ntwk[cx][cy]=2
		if in_river(cx,cy) then
			purchase(prc.brg)
		else
			purchase(prc.trk)
		end
		play('trk')
	end
end

function do_delete()
	if ntwk[cx][cy]>0 then
		idx=get_stn(cx,cy)
		del(stns,stns[idx])
		ntwk[cx][cy]=0
		add(msgs,new_msg('deleted!'))
		play('del')
		shakedur=2

	end
end

function purchase(price)
	cash-=price
	add(msgs,new_msg('-'..price,8))
end

function refund(price)
	cash+=price
	add(msgs,new_msg('+'..price,11))
end

function add_train()
	local t=new_train()
	add(trns,t)
end

---------------
--check gover--
---------------

function is_gover()
	if (cash<-1000) return true
	return false
end

----------------
--balance data--
----------------

function add_data()
	add(cash_dt,cash)
	add(profit_dt,profit)
end
-->8
--draw

function drw_game()
	pal(4,4,1)
	vmode_for_tool()
	if vmode==3 then
		cls(0)
		map(32,0)
		draw_blnc()	
	else
		if vmode==1 then
			cls(0)
			map(0)
		elseif vmode==2 then
			pal(4,128,1)
			cls(4)
			map(16,0)
			draw_pop()
		end
		draw_debug()
		draw_network()
		draw_stations()
		--draw_route()
		if (#trns>0) then 
			for t in all(trns) do
				if t.x != nil and t.y != nil then
					t.draw()
				end
				for p in all(t.pass) do
				print(p.dest.x .. p.dest.y)
				end
			end
		end
	end
	if (toolbar) draw_toolbar() 
	if (mgmt) show_mgmt()
	if not mgmt and not toolbar then draw_cursor() end
	draw_msgs()
	draw_hud()
	draw_areas()
	if (debug_on) print(cx .. cy, 2,10,7)	
	if (smokedur>=0) drw_smoke(cx,cy)
end

function drw_splash()
	msg='press ❎ to start'
	by='by cameron robson'
	len=#msg*4/2
	bylen=#by*4/2
	startx=63-(8*8)/2
	
	cls(0)
	
	for i=0,3 do
		--spr(168+(i*2),i*16,0,2,2)
	end
	
	spr(136,startx+(8*8),60,2,1)
	spr(128,startx,50,8,4)
	print('monorail',startx+36,68,5)
	print('simulator',startx+28,74,5)
	print(by,63-len,114,5)
	
	for i=0,7 do
		--spr(81,startx+(i*8),68)
	end
	
	print(msg,63-len,88,8+flr(f/9)%3)
end

function drw_menu()
	cls()
	for i,optn in pairs(mn_items) do
		if i==mn_opt then
			spr(138,30,mn_pos[i]-2)
		end
		print(optn,40,mn_pos[i],7)
	end
end

function drw_manual()
	draw_manual()
end

function drw_gover()
	
end

function draw_pop()
	for x=0,15 do
		for y=0,15 do
			p=pop[x][y]
			if p>0 then
				spr(47+p,x*8,y*8)
			end
		end
	end
end

function draw_network()
	for x=0,15 do
		for y=0,15 do
			t=ntwk[x][y]
			if t==2 then
				s=get_trk_spr(x,y)
				spr(s,x*8,y*8)
			end
		end 
	end	
end

function draw_stations()
	for s in all(stns) do
		s.hov=(cx==s.x and cy==s.y)
		s.draw()
	end
end

function draw_debug()
	print('',10,10)
	for d in all(debug) do
		print(d,12)
	end
end

function draw_areas()
	for a in all(areas) do
		a.hov=(cx==a.x and cy==a.y)
		a.draw()
	end
end


--could use loop + dirx/y here? 
function get_trk_spr(x,y)
	l=x>0 and is_rideable(x-1,y) 
	r=x<15 and is_rideable(x+1,y) 
	u=y>0 and is_rideable(x,y-1) 
	d=y<15 and is_rideable(x,y+1)
	
	if l and u then return 82
	elseif l and d then return 83
	elseif r and u then return 84	
	elseif r and d then return 85
	elseif u or d then return 80
	else return 81 
	end
end

function draw_distmap(m)
	for x=0,15 do
		for y=0,15 do
			if m[x][y]>0 then
				print(m[x][y],x*8,y*8,7)
			end
		end
	end
end

function get_trn_spr(x,y)
	return get_trk_spr(x,y)+16
end

function highlight_line()
	l=lns[#lns]
	
	for s in all(l.rt) do
		spr(112,s.x*8,s.y*8)
	end
end

function draw_line(l)
		for i=1,#l.rt do
			s=l.rt[i]
			if i==1 then
				spr(112,s.x*8,(s.y-1)*8)
			else
				spr(113,s.x*8,(s.y-1)*8)
			end
		end
end

function draw_route()
	if #route>1 then
		for i=1,#route do
			print(i,route[i].x*8+i/8,route[i].y*8,8+i%2)
		end
	end
	print(#route,10,10)
end
-->8
--state

day=1

mode=1
vmode=1
do_trk=false

prev_cx,prev_cy=0,0

cash=10000
profit=0

pop={}

--------
--menu--
--------

mn_opt=1
mn_items={
	'new game',
	'how to play'
}
mn_pos={
	40,
	50,
	60
}

menuitem(1,'how to play')
----------
--charts--
----------

cash_dt={10000,9556,8000,9000,5000}
profit_dt={}

-------------
--messaging--
-------------

msgs={}

----------
--prices--
----------

prc={
	stn=1000,
	trk=100,
	brg=200,
	trn=500,
	tkt=5
}

---------
--metro--
---------

stns={} -- xypos,queue
ntwk={} -- map of stns/trk
route={}
trns={}

------
--ui--
------

mgmt=false
mgopt=1
mgopt_active=false
mgmarg=18
mgpad=6
mgheight=16
mgitems={
	{name='tkt price',s=104,val=prc.tkt,max=20,lock=true},
	{name='trains',s=105,val=1,max=3,lock=true}
}

toolbar=false
tool=1

tbpos={16,32,48,64,80,96,112}
tbspr={2,3,4,5,6,7,8}

tbnames={
	'cursor',
	'station',
	'track',
	'demolish',
	'manage',
	'population',
	'data'
}

-----------
--namegen--
-----------

starts={
	'wall',
	'bridge',
	'temple',
	'upper',
	'east'
}

ends={
	'ford',
	'ton',
	'ham',
	' town',
	' city'
}

map_starts={
	'river',
	'sun',
	'windy',
}

map_ends={
	' valley',
	'opolis',
	'ville',
	' canyon',
	' fields',
}


-------
--map--
-------

map_name=''
river={}
areas={}

-->8
--generation

function mapgen()
	for x=0,15 do
		for y=0,15 do
			mset(x,y,16)
		end
	end
	
	map_name=gen_name()
	gen_river()
	gen_river_edges()
	gen_city()
	gen_forest()
	gen_suburbs()
	gen_pop()
	gen_adj_pop()
end


function gen_river()
	rx,ry=0,7
	for x=0,31 do
		if rnd()>0.5 then
			ry+=1
		else
			ry-=1
		end
		
		if (rx>=15) return
		if (rnd()>0.3) then
			add(river,{x=rx,y=ry})
			mset(rx,ry,37)
			mset(rx+16,ry,36)
			rx+=1
		end
		add(river,{x=rx,y=ry})
		mset(rx,ry,37) 
		mset(rx+16,ry,36)
	end
end

function gen_river_edges()
	for r in all(river) do
		t=rtile_frm_nbrs(r.x,r.y)
		mset(r.x,r.y,t)
	end
end

function rtile_frm_nbrs(x,y)
	n={}
	t=37
	
	for i=1,4 do
		dx=x+dirx[i]
		dy=y+diry[i]
		n[i]=mget(dx,dy)==16
	end
	
	if (n[1] and n[2] and n[3] and n[4]) return 58
	if (n[1] and n[2] and n[3]) return 54
	if (n[1] and n[2] and n[4]) return 55
	if (n[1] and n[3] and n[4]) return 56
	if (n[2] and n[3] and n[4]) return 57
	
	if (n[1] and n[3]) return 44
	if (n[1] and n[4]) return 45
	if (n[2] and n[3]) return 46
	if (n[2] and n[4]) return 47
	
	if (n[1] and n[2]) return 42
	if (n[3] and n[4]) return 43
	
	if (n[1]) return 38
	if (n[2]) return 39	
	if (n[3]) return 40
	if (n[4]) return 41
		
	return t
end

function gen_forest()
	for x=1,15 do
		for y=1,15 do
			r=rnd(1)
			if (r<0.2 and mget(x,y)==16) then
				mset(x,y,59)
			end
		end
	end
end

function gen_city()
	for x=3,11 do
		for y=3,11 do
			if rnd()<0.2 and 
			mget(x,y)==16 then
				local nbrs=false
				for i=1,8 do
					dx=x+dirx[i]
					dy=y+diry[i]
					if (mget(dx,dy)==34) nbrs=true
				end
				
				if not nbrs then
					mset(x,y,34)
					name=gen_name('area')
					a=new_area(x,y,name)
					add(areas, a)
				end
			end
			if (#areas > 3) return
		end
	end
end

function gen_suburbs()
	for x=0,15 do
		for y=0,15 do
			if mget(x,y) == 34 then
				for i=1,8 do
					dx,dy=x+dirx[i],y+diry[i]
					if mget(dx,dy)==16 then
						if rnd()<0.8 then
							if (i<=4) then mset(dx,dy,33)
							else mset(dx,dy,32)
							end
						end
					end
				end
			end
		end
	end
end

area_map={}
function gen_areas()
	for k,v in pairs(areas) do
		
	end
end

function gen_pop()
	for x=0,15 do
		pop[x]={}
		for y=0,15 do
			t=mget(x,y)
			p=0
			if t==34 then p=3
			elseif t==33 then p=2
			elseif t==32 then p=1
			else p=0
			end
			pop[x][y]=p
		end
	end
end

function gen_adj_pop()
	for x=0,15 do
		for y=0,15 do
			p=0
			for i=0,7 do
				t=mget(x+adjx[i+1],y+adjy[i+1])
				if not t==18 then
					if t==32 then p+=0.05 end
					if t==33 then p+=0.1 end
				end
				if pop[x][y]+p<4 then
					pop[x][y]+=p
				end
			end
		end
	end
end

function gen_name(type)
	if type=='area' then
		s=starts[flr(rnd() * #starts)+1]
		e=ends[flr(rnd() * #ends)+1]
	else
		s=map_starts[flr(rnd() * #map_starts)+1]
		e=map_ends[flr(rnd() * #map_ends)+1]
	end

	return s..e
end

--------
--loop--
--------

function find_loop(start)
	local vis,path=blankmap(0),{}
	local curr={x=start.x,y=start.y}
	path[1]=curr
	vis[curr.x][curr.y]=1
	repeat
		move=false
		for i=1,4 do
			dx=curr.x+dirx[i]
			dy=curr.y+diry[i]
			if ntwk[dx][dy]>0 then
				if vis[dx][dy]==0 then
					vis[dx][dy]=1
					curr={x=dx,y=dy}
					add(path,curr)
					move=true
					break
				end
			end
		end
		if move==false then
			if (adj_to_start(curr.x,curr.y,start.x,start.y)) curr=start
		end
	until move==false
	return {loop=(curr==start and #path>2),path=path}
end

function adj_to_start(x,y,sx,sy)
	for i=1,4 do
		dx=x+dirx[i]
		dy=y+diry[i]
		if (dx==sx and dy==sy) return true
	end
	return false
end

--checks if loop exists, and sets it to variable if so
function loop_handler()
	local start=stns[1]
	local l = find_loop(start)
	route=l.path
	loop_exists=l.loop
	return l.loop
end

-->8
--util

function blankmap(_dflt)
 local ret={} 
 if (_dflt==nil) _dflt=0
 
 for x=0,15 do
  ret[x]={}
  for y=0,15 do
   ret[x][y]=_dflt
  end
 end
 return ret
end

function inbounds(x,y)
	oob=x<0 or x>15 or y<0 or y>15
	return not oob
end

function is_line(x,y)
	return ntwk[x][y]==2
end

function is_stn(x,y)
	return ntwk[x][y]==1
end

function is_rideable(x,y)
	return is_stn(x,y) or is_line(x,y)
end

function calc_happ()
	
end

function at_stn(t)
	for s in all(stns) do
		if t.x==s.x and t.y==s.y then
			return s
		end	
	end
	return nil
end

function get_stn(x,y)
	for i,v in pairs(stns) do
		if v.x==x and v.y==y then
			return i
		end
	end
	return -1
end

function in_river(x,y)
	t=mget(x,y)
	return fget(t)==2
end

function add_msg(msg,dur)
	add(msgs,{msg=msg,dur=dur})
end

function get_area(x,y)
	for a in all(areas) do
		if a.x==x and a.y==y then
			return a
		end
	end
	return nil
end

shake=0
function doshake()
	if shakedur>=0 then
		shake+=shakedur/10000
	 -- this function does the
	 -- shaking
	 -- first we generate two
	 -- random numbers between
	 -- -16 and +16
	 local shakex=16-rnd(32)
	 local shakey=16-rnd(32)
	
	 -- then we apply the shake
	 -- strength
	 shakex*=shake
	 shakey*=shake
	 
	 -- then we move the camera
	 -- this means that everything
	 -- you draw on the screen
	 -- afterwards will be shifted
	 -- by that many pixels
	 camera(shakex,shakey)
	 
	 -- finally, fade out the shake
	 -- reset to 0 when very low
	 shake = shake*0.95
	 if (shake<0.05) shake=0
	 shakedur-=1
	end
end

smokedur=0
function drw_smoke(x,y)
	for i=1,3 do
		xoff=1
		if (i<3) xoff=-1

		circfill(x*8+(i*xoff),(y-1)*8+smokedur+(i),i/2,8)
		circfill(x*8+(2*xoff),(y-1)*8+smokedur+(i*2),i/2,9)
	end
	smokedur-=1
end

function print_outline(txt,x,y,col,back)
	if (not back) back=1
	print(txt,x,y,col)
	for i=1,8 do
		dx=x+dirx[i]
		dy=y+diry[i]
		print(txt,dx,dy,back)
	end
	print(txt,x,y,col)
end

function is_proximate(a,b)
	if (a.x==b.x and a.y==b.y) return true
	for i=1,8 do
		dx=a.x+dirx[i]
		dy=a.y+diry[i]
		if (b.x==dx and b.y==dy) return true
	end
	return false
end

function concat_table(main,extra) 
	for i=1,#extra do
		main[#main+i]=extra[i]
	end
end

function apply_select()
	for s in all(stns) do
		s.slct=s.hov
		slct=start
	end

	--if (train) train.slct=train.hov
end

function get_train_anim(tile)
	if (tile==80) return {off={-4,0,4},f={96,96,96}}
end
-->8
--network obj

----------
--trains--
----------

function new_train(x,y)
	local t={
		x=x,
		y=y,
		stp=1,
		cap=50,
		pass={},
		hov=false,
		slct=false,
		test=100,
		off=flr(#route/(#trns+1))
	}

	t.move=function()
		pos = ((tk%#route) + t.off)
		t.test=pos
		if (pos>#route) then
			diff=pos-#route
			pos=diff
		end
		t.x=route[pos].x
		t.y=route[pos].y

		local s=at_stn(t)
		if s then
			if #s.pass>=1 then
				concat_table(t.pass,s.pass)
				s.pass={}
			end
			for p in all(t.pass) do
				if (p.dest and is_proximate(s,p.dest)) then
					profit+=prc.tkt
					del(t.pass, p)
				end 
			end
		end
	end
	
	t.draw=function(s)
		t.hov=cx==t.x and cy==t.y
		val=flr((#t.pass/t.cap)*4)
		s=get_trn_spr(t.x,t.y)
		spr(s,t.x*8,t.y*8)
		if (t.slct) then 
			draw_effect(t,'select')
			t.draw_info()
		end
	end

	t.draw_info=function()
		print_outline('😐:' .. #t.pass,t.x*8-4,(t.y-1)*8,7)
	end

	return t
end

------------
--stations--
------------

function new_stn(x,y)
	local s={
		x=x,
		y=y,
		pass={},
		cap=100,
		days_full=0,
		hov=false,
		slct=false
	}
	
	s.draw=function()
		val=flr((#s.pass/s.cap)*7)
		spr(64+val,s.x*8,s.y*8)

		if (s.slct) then 
			draw_effect(s,'select')
			s.draw_info()
		end
	end
	
	s.draw_info=function()
		w=12 + #tostr(#s.pass)
		print_outline('😐:' .. #s.pass,s.x*8-4,(s.y+1)*8+2,7)
	end
	
	return s
end

--------------
--passengers--
--------------

function gen_pass()
	for s in all(stns) do
		p=0
		for i=1,8 do
			dx=s.x+dirx[i]
			dy=s.y+diry[i]
			p+=pop[dx][dy]
		end
		for i=1,ceil(p/8) do
			local dest=stns[ceil(rnd()*#stns)]
			local np=new_pass(dest)
			add(s.pass,np)

		end
	end
end

function new_pass(dest)
	local p={
		dest={
			x=dest.x,
			y=dest.y
		},
	}
	
	--add(debug,'dest ' .. p.dest.x .. p.dest.y)
	return p
end

-------------
--ticketing--
-------------

function take_tkts(n)
	profit+=(n * prc.tkt)
end

---------
--areas--
---------

function new_area(x,y,n)
	local a={
		x=x,
		y=y,
		name=n,
		hov=false
	}
	
	a.draw=function()
		if a.hov and tool==1 then
			len=#a.name
			print_outline(a.name,(a.x*8)-(len*4)/2,(a.y-1)*8,7)
		end
	end
	
	return a
end

---------------
--maintenance--
---------------

function calc_maint()
	m=(#stns*5)+(#trns*2)
	profit-=m
end
-->8
--ui

-------------
--constants--
-------------

shakedur=0

---------
--anims--
---------

slct_anim={spd=6,f={10,10,10,10,12,13,10,10,10,10}}
stn_anim={spd=16,f={72,73,74,75}}
trk_anim={spd=100,f={88,89,90,91,92,93,94,95}}

------------
--messages--
------------

function draw_msgs()
	ypos=50
	for m in all(msgs) do
		m.dur-=1
		len=#m.msg*4
		if (m.dur<=0) then del(msgs,m)
		elseif m.dur<18 then
			rectfill(2,128-m.dur-1,3+len,128-m.dur+10,0)
			print(m.msg,3,128-m.dur,m.col)
		elseif m.dur<110 then
			rectfill(2,109,3+len,120,0)
			print(m.msg,3,110,m.col)
		else
			rectfill(2,m.dur-1,3+len,m.dur+10,0)
			print(m.msg,3,m.dur,m.col)
		end
	end
end

function new_msg(msg,col,dur)
	local m={
		msg=msg,
	}
	
	if (col==nil) then m.col=7
	else m.col=col
	end
	
	
	if (dur==nil) then m.dur=128
	else m.dur=dur
	end
	
	return m
end


---------
--vmode--
---------

function vmode_for_tool()
	if tool<=5 then
		vmode=1
	elseif tool==6 then
		vmode=2
	elseif tool==7 then
		vmode=3 
	end 
end

-------
--hud--
-------

function draw_effect(target, mode)
	if (mode=='select') anim=slct_anim

	s=anim.f[flr(f/anim.spd)%#anim.f+1]
	spr(s,target.x*8,target.y*8)
end

function draw_cursor()
	spr(76+(tk%2),cx*8,cy*8)
end

function draw_hud()
	rectfill(2,116,125,125,6)
	spr(tbspr[mode],3,117)
	
	if (cash<0) c_col=8 else c_col=0
	print('$' .. cash,14,118,c_col)
	
	spr(22+tk%10,117,117)
	
	print('day:' .. day,92,119)
end

function draw_profit()
	prev_prf=profit_dt[#profit_dt]
	
	if prev_prf>=0 then
		add(msgs,new_msg('+' .. prev_prf,11))
	else
		add(msgs,new_msg(tostr(prev_prf),8))
	end
end

---------------
--select pane--
---------------

-----------
--toolbar--
-----------

function draw_toolbar()
	rectfill(0,0,128,10,0)
	spr(9,cx,cy+10)

	for i=1,#tbspr do
		spr(tbspr[i],tbpos[i],1)
	end
	
	draw_tool_name()
end

function draw_tool_name()
	name=tbnames[tool]
	len=#name*4
	rectfill(cx-len/2+2,cy+11,cx+len/2+4,cy+17,1)
	print(name,cx-(len/2)+4,(cy+12),7)
end

------------
--analysis--
------------

function draw_blnc()
	name='cash over time'
	tick=8
	xmarg=8
	ymarg=24
	draw_chart()
	draw_blnc_line()
	print(name,63-((#name*4)/2),108,6)
end

function draw_chart()
	line(xmarg,ymarg,xmarg,128-ymarg,5)
	line(xmarg,128-ymarg,128-xmarg,128-ymarg,5)
	
	for i=0,10 do
		line(xmarg,ymarg+(i*8),xmarg-3,ymarg+(i*8))
	end
end

function draw_blnc_line()
	w=4
	entries=16
	for i=max(#cash_dt-entries,1),#cash_dt do

		val=cash_dt[i]
		ypos=128-ymarg-(flr(val/1000)*tick)
		xpos=xmarg+i*w
		
		if i>1 then
			prev_val=cash_dt[i-1]
			
			if prev_val>val then
				col=8
			elseif prev_val<val then
				col=11
			else
				col=6
			end
			
			prevx=xpos-w
			prevy=128-ymarg-(flr(prev_val/1000)*tick)
			line(prevx,prevy,xpos,ypos,col)
			spr(115,prevx-1,prevy-1)
			
			if (i==#cash_dt) print(val,xpos+2,ypos+2,7)
		end
	end
end

------------------
--manager screen--
------------------

function show_mgmt()
	mgitems[1].lock=#trns<1
	mgitems[2].lock=#trns<1

	for x=1,14 do
		for y=2,7 do
			if (x==13) then spr(121,x*8,y*8)
			else spr(120,x*8,y*8)
			end
		end
	end
	title=(map_name .. ' rail co.')
	len=#title*4
	print_outline(title,10,mgmarg+1,7)

	for i,item in pairs(mgitems) do
		spr(item.s,mgmarg+mgpad,mgmarg+mgheight*i)
		print_outline(item.val,mgmarg*2+mgpad,mgmarg+mgheight*i+2,7)
		print_outline(item.name,128-mgmarg-(#item.name*4)-12,mgmarg+mgheight*i+2,7)	
		if mgopt==i then
			anim_pointer(mgmarg-4,mgmarg+mgheight*i+1)
			if not item.lock then
				spr(110,mgmarg+mgpad+8,mgmarg+mgheight*i)
				digits=#tostr(item.val)
				spr(111,mgmarg*2+mgpad+(4*digits)+1,mgmarg+mgheight*i)
			end
		end
		if item.lock then
			spr(122,mgmarg*2+mgpad,mgmarg+mgheight*i)
		end
	end
end

function anim_pointer(x,y)
	s=106+(f/16%4)
	spr(s,x,y)
end


----------
--manual--
----------

function draw_manual()
	cls()
	print("metro - how to play",8)
	print("",7)
	print("🅾️: open toolbar")
	print("❎: use tool")
	print("dpad: move cursor")
	print("",6)
	print("◆place stns near buildings")
	print("◆connect stns with track.")
	print("◆create lines between stns")
	print("◆lines must form a loop")
	print("◆passengers are added daily")
	print("◆hi-pop. areas will produce")
	print("more passengers.")
	print("◆failure to meet demand will")
	print("result in gameover")
	print("")
	print("have fun!")
end
-->8
--sfx

function play(e)
	
	if (e=='line-stp') sfx(4)
	if (e=='line-done') sfx(0)
	if (e=='line-new') sfx(3)
	if (e=='trk') sfx(1)
	if (e=='stn') sfx(2)
	if (e=='del') sfx(5)
	
	
	if (e=='opt-move') sfx(1)
	if (e=='opt-select') sfx(20)
end
__gfx__
000000007700007755000055011111101111111100000000000000000099aa005555555549a77a9470000007700000070667a000000006707000000700000000
00000000700000075000000511111111166666660999000000444400099999a05655555500000000000000000000000000000006700000000000000000000000
007007000000000000000000111111111666666609770000004004009919919a565555b500000000000000000000000000000006600000000000000000000000
000770000000000000000000117777711661111189999950444444449919919a5655bb55000000000000000000000000a0000007000000000000000000000000
0007700000000000000000001171717116610000999999504444444499999999565b55550000000000000000000000007000000a000000000000000000000000
007007000000000000000000116161611661000055955955444444449919919956b5555500000000000000000000000060000000000000060000000000000000
00000000700000075000000511515151166100005505500044444444099119905666666500000000000000000000000060000000000000070000000000000000
000000007700007755000055011111101661000000000000555555550099990055555555000000007000000770000007000a7660076000007000000700000000
3333333e3333333333333333333ffff8333333330000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
d33e33333333333333333333333333ff33333333000000005cccccc55cccccc55cccccc55cccccc55cccccc55cccccc55cccccc5511111155111111551111115
333333d333333333333333333333333f33333333000000005cccccc55cccccc55caaccc55ccaacc55cccaac55cccccc55cccccc5511111155117611551111115
e333333333333333f33333333333333f3333333f000000005cccccc55aacccc55caaccc55ccaacc55cccaac55ccccaa55cccccc5576111155116711551111675
333d33e333333333f33333333333333f3333333f00000000588ccc655aacccc55cccccc55cccccc55cccccc55ccccaa556ccc995567111155111111551111765
3333333333333333f3333333333333333333333f00000000583333655c3333c55c3333c55c3333c55c3333c55c3333c556333395513333155133331551333315
3d3e33d333333333ff33333333333333333333ff0000000053333335533333355333333553333335533333355333333553333335533333355333333553333335
33333333333333338ffff33333333333333ffff80000000055555555555555555555555555555555555555555555555555555555555555555555555555555555
3336333333363366673673670000000000000000ccccccccfccccccccccccccfffffffffccccccccfccccccfffffffff333ffffffcccccccffffff33cccccccf
66333363663553666656656600000000cc00cc00ccccccccfcccccccccccccffcffffcccccccccccfccccccfcccccccc3fffccccfccccccccccccff3cccccccf
3333353333333333355555530000000000cc00ccccccccccffccccccccccccffccccccccccccccccfccccccfccccccccffccccccfcccccccccccccf3cccccccf
3353333635366336675675670000000000000000ccccccccffccccccccccccffccccccccccccccccfccccccfccccccccfcccccccfcccccccccccccffcccccccf
6336333365363366665665660000000000000000ccccccccffccccccccccccffccccccccccccccccfccccccfccccccccfcccccccffcccccccccccccfcccccccf
33333333333355333555555300000000cc00cc00ccccccccffcccccccccccccfccccccccccccccccfccccccfccccccccfccccccc3fcccccccccccccfccccccff
3633536336335563675675670000000000cc00ccccccccccfccccccccccccccfcccccccccfffccccfccccccfccccccccfccccccc3ffccccccccccccfccccfff3
3336333335366366663663660000000000000000ccccccccfccccccccccccccfccccccccfffffffffccccccffffffffffccccccc33ffffffcccccccffffff333
00003003030030030b00b00bbbbbbbbb00000000000000003fffff33fccccccf33fffffffffffff33ffffff3333333e300000000000000000000000000000000
3000000030030030b00b00b0bbbbbbbb0000000000000000ffcccff3fccccccf3ffcccccccccccffffccccffd33e3eee00000000000000000000000000000000
003003000030030000b00b00bbbbbbbb0000000000000000fcccccfffccccccfffcccccccccccccffccccccf33eeeeee00000000000000000000000000000000
00000003030030030b00b00bbbbbbbbb0000000000000000fccccccffccccccffccccccccccccccffccccccfe3eee3e300000000000000000000000000000000
3003000030030030b00b00b0bbbbbbbb0000000000000000fccccccffccccccffccccccccccccccffccccccf33eee34300000000000000000000000000000000
000003000030030000b00b00bbbbbbbb0000000000000000fccccccfffcccccffcccccccccccccffffcccccf33eee34300000000000000000000000000000000
03000000030030030b00b00bbbbbbbbb0000000000000000fccccccf3ffcccffffcccccccccccff33ffcccff333433d300000000000000000000000000000000
0003003030030030b00b00b0bbbbbbbb0000000000000000fccccccf33fffff33fffffffffffff3333fffff33334333300000000000000000000000000000000
01111110011111100111111001111110011111100111111001111110011111107700007777000077770000777700007766000066000000000000000000000000
11111111111111111111111111111111111111111111111111111111111111117000000770000007701111077000000760000006077007700000000000000000
11111111111111111111111111111111111111111111111111111111111111110000000000011000011111100001100000000000070000700000000000000000
11777771117777711177777111777771117777711177777111777771117777710001100000111100011111100011110000000000000000000000000000000000
11717171117171711171717111717171117171711171717111717171117171710001100000111100011111100011110000000000000000000000000000000000
11616161116161611161616111616161116161611161616111616161116161610000000000011000011111100001100000000000070000700000000000000000
11515151115151511151515111515151115151511151515111515151115151517000000770000007701111077000000760000006077007700000000000000000
01111110011111100111111001111110011111100111111001111110011111107700007777000077770000777700007766000066000000000000000000000000
00166100000000000016610000000000001661000000000000000000000000007700007777000077776666777700007777000077770000777700007777000077
00166100000000000016610000000000001661000000000000000000000000007000000770166107716666177016610770000007700000077111111770000007
00166100111111111116610011111100001661110011111100000000000000000000000000166100016666100016610000000000011111106666666601111110
00166100666666666666610066666100001666660016666600000000000000000001100000166100016666100016610000011000066666606666666606666660
00166100666666666666610066666100001666660016666600000000000000000001100000166100016666100016610000011000066666606666666606666660
00166100111111111111110011166100001111110016611100000000000000000000000000166100016666100016610000000000011111106666666601111110
00166100000000000000000000166100000000000016610000000000000000007000000770166107716666177016610770000007700000077111111770000007
00166100000000000000000000166100000000000016610000000000000000007700007777000077776666777700007777000077770000777700007777000077
008cc80000000000008cc80000000000008cc8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800000000000088880000000000008888000000000000000000000000006666655688888800000000000000000000000000000000000000000000000000
008888008888888888888800888888000088888800888888000000000000000066666556ccccc8800000aa00000aa0000000aa0000000aa0000000000ddd0000
00888800c888888cc8888800c88888000088888c0088888c000000000000000066666556ccccc8880000aaa0000aaa000000aaa000000aaa000dddddddadd000
00888800c888888cc8888800c88888000088888c0088888c000000000000000066666556888888880000aa00000aa0000000aa0000000aa0000daaaddaaad000
008888008888888888888800888888000088888800888888000000000000000066666556a888a88800000000000000000000000000000000000dddddddadd000
0088880000000000000000000088880000000000008888000000000000000000666665568888881100000000000000000000000000000000000000000ddd0000
008cc8000000000000000000008cc80000000000008cc80000000000000000000000000011111100000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000777700000000001111111117777776011111100000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000770000000000011dd11dd17777777018888100000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000077770000000000d11dd11d17777776118118110000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000777777000000000d11dd11d17777777188888810000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000777777000000000d11dd11d17777776188888810000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000777777000000000d11dd11d17777777188888810000000000000000000000000000000000000000
000bb000000aa00000088000000000000000000000000000007007000000000011dd11dd17777776188888810000000000000000000000000000000000000000
000bb000000aa0000008800000000000000000000000000000700700000000001111111117777777111111110000000000000000000000000000000000000000
0066600000666000000066666666600000666666666660000000666666666000aaa0aaa0aaa0aaa0000000000000000000000000000000000005550000050500
066666000666660000066666666666000666666666666600000666666666660000a0a0a0a0a0a0a0005555000000000000000000000550000005050000005000
0666660006666600006666600066666006666666666666000066666000666660aaa0a0a0a0a0a0a005bbbb500000000000055000000550000550500005000000
0666666066666600006666000006666006666000006666000066660000066660a000a0a0a0a0a0a005bbbb500000000000055000055000000500505000005000
0666666666666600006660000000666006660000000666000066600000006660aaa0aaa0aaa0aaa005bbbb500005000005500000055055000050050000000000
0666666666666600006660000000666006660000000666000066600000006660000000000000000005bbbb500000000000505500000055000000000000000000
06660666660666000066600000006660066600000006660000666000000066600000000000000000005555000050000000005000000000000000000000000000
06660066600666000066600000006660066600000006660000666000000066600000000000000000000000000000500000000000000000000000000000000000
06660066600666000066600000006660066600000006660000666000000066600000000000000000000000000000000000000000000000000000000000000000
06660000000666000066600000006660066600000006660000666000000066600000000000000000000000000000000000000000000000000000000000000000
06660000000666000066600000006660066600000006660000666000000066600000000000000000000000000000000000000000000000000000000000000000
06660000000666000066600000006660066600000006660000666000000066600000000000000000000000000000000000000000000000000000000000000000
00000000000666000066660000066666666600000006660006666600000666600000000000000000000000000000000000000000000000000000000000000000
06660000000666000066666000666666666655555006660066666660006666600000000000000000000000000000000000000000000000000000000000000000
00000000000666600662222222228826666000055506666666006666666666000000000000000000000000000000000000000000000000000000000000000000
06660000000666662228888828882820000066500000666660000666666660000000000000000000000000000000000000000000000000000000000000000000
00000000000062228882888882c62c20066500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002888888828cc62cc2826600000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000
0000000000002cc778c618ccc1881810000000000000000000000000000000000000550000000800008000000008000000800000000000000000800000000800
000000000002cccc78cc188881881100000000000000000000000000000000000055550000055555555550000055550055555000000000000055550000055555
000000000002ccccc888188881110000000000000000000000000000000000000055550000055556665550000055550065555000000555000055550000055566
00000000002888888888181110000000000000000000000000000000000000005555550055555556665555550055555565565555005555555555550055555566
00000000001a788a7881110000000000000000000000000000000000000000005555550055566656666665550055555565666555555555555555550055566666
00000000000188881110000000000000000000000000000000000000000000006665550666566656666665666055566665666555555556666665550666566666
00000000000111111500000000000000000000000000000000000000000000006665550666566656666666666055566665666556565566666665550666666666
00000000000066655000000000000000000000000000000000000000000000006665555666566666666666666555566666666556565666666665555666666666
00000000006665500000000000000000000000000000000000000000000000006665555666566666666666666555566666666566666666666665555666666666
00000000666550000000000000000000000000000000000000000000000000006666666666566666666666666665666666666566666666666666566666666666
00000066655000000000000000000000000000000000000000000000000000006666666666566666666666666665666666666566666666666666566666666666
00066600000000000000000000000000000000000000000000000000000000006666666666666666666666666666666666666666666666666666666666666666
06000000000000000000000000000000000000000000000000000000000000006666666666666666666666666666666666666666666666666666666666666666
00000000000000000000000000000000000000000000000000000000000000006666666666666666666666666666666666666666666666666666666666666666
cccccccccccccccccccccccccf3333fc33333333cccccccc33333333cf3333fccf33333300000000000000000000000000000000000000000000000000000000
cccffffffffffffffffffccccf3333fc33333333ccffffcc33333333ff3333ffff33333300000000000000000000000000000000000000000000000000000000
ccff3333333333333333ffcccf3333fc33333333cff33ffc33333333333333333333333300000000000000000000000000000000000000000000000000000000
cff333333333333333333ffccf3333fc33333333cf3333fc33333333333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fccf3333fc33333333cf3333fc33333333333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fccf3333fc33333333cf3333fc33333333333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fccf3333fc333333ffcf3333fcff33333333333333ff33333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fccf3333fc333333fccf3333fccf33333333333333cf33333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fccccccccccccccccc33333333cccccccc33333333333333fc00000000000000000000000000000000000000000000000000000000
cf33333333333333333333fcffffffffccffffff33333333ffffffcc33333333333333ff00000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc33333333cff333333333333333333ffc333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc33333333cf33333333333333333333fc333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc33333333cf33333333333333333333fc333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc33333333cff333333333333333333ffc333333333333333300000000000000000000000000000000000000000000000000000000
cf33333333333333333333fcffffffffccffffff33333333ffffffccff3333ff333333ff00000000000000000000000000000000000000000000000000000000
cf33333333333333333333fccccccccccccccccc33333333cccccccccf3333fc333333fc00000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc00000000333333fccf3333fccf333333000000000000000000000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc00000000333333ffcf3333fcff333333000000000000000000000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc0000000033333333cf3333fc33333333000000000000000000000000000000000000000000000000000000000000000000000000
cf33333333333333333333fc0000000033333333cf3333fc33333333000000000000000000000000000000000000000000000000000000000000000000000000
cff333333333333333333ffc0000000033333333cf3333fc33333333000000000000000000000000000000000000000000000000000000000000000000000000
ccff3333333333333333ffcc0000000033333333cff33ffc33333333000000000000000000000000000000000000000000000000000000000000000000000000
cccffffffffffffffffffccc0000000033333333ccffffcc33333333000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccc0000000033333333cccccccc33333333000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000108000000000000000000000000000000000000000000000000000000000000000202000202020202020202020000000000000202020202000000000001010101010101010000000000000000080800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010e000011755147550d5351d5052250522505255051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d5051d505
011000000552504505105051050510505105051050510505105051050510505105051050510505105051050510505105051050510505105051050510505105051050510505105051050510505105051050500500
01160000041331a6351d6001a600167051470500705007051a6050070500705007050070500705007050070514705167051070500705167051470500705007050070500705007050070500705007050070500705
0110000011745147000d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000d52500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01140000070630862508625086151b600086000000008605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200001263412625126151260512600006000060000600006000060000600006000060012600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
012000000575508755015351100005725110001100011000110000000500005000051000000005000050000505755087550153511000057250000500005000051100000005000050000510000000050000500005
0110002010000100001000010000100001000013015110151001510015100251002510025100251002510025110000e60000600006000e6000e60013015110151001510015100251002510025100251002510025
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001172513725187250070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
__music__
03 0a0b4344

