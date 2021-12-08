pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
-- picocad client
-- by @freds72
-- model & picocad format 
-- @johanpeitz

#include poly.lua
#include chunky_tank.p8l

-- globals
local _dithers,_cam,_plyr,_entities={}

-->8
-- maths
function lerp(a,b,t)
	return a*(1-t)+b*t
end

function make_v(a,b)
	return {
		b[1]-a[1],
		b[2]-a[2],
		b[3]-a[3]}
end
function v_clone(v)
	return {v[1],v[2],v[3]}
end
function v_dot(a,b)
	return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]
end
function v_scale(v,scale)
	v[1]*=scale
	v[2]*=scale
	v[3]*=scale
end
function v_add(v,dv,scale)
	scale=scale or 1
	return {
		v[1]+scale*dv[1],
		v[2]+scale*dv[2],
		v[3]+scale*dv[3]}
end
function v_lerp(a,b,t)
	return {
		lerp(a[1],b[1],t),
		lerp(a[2],b[2],t),
		lerp(a[3],b[3],t)
	}
end

function v_cross(a,b)
	local ax,ay,az=a[1],a[2],a[3]
	local bx,by,bz=b[1],b[2],b[3]
	return {ay*bz-az*by,az*bx-ax*bz,ax*by-ay*bx}
end
function v_len(v)
	local x,y,z=v[1],v[2],v[3]
	return sqrt(x*x+y*y+z*z)
end

function v_normz(v)
	local x,y,z=v[1],v[2],v[3]
	local d=sqrt(x*x+y*y+z*z)
	return {x/d,y/d,z/d},d
end

-- matrix functions
function m_x_v(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[5]*y+m[9]*z+m[13],m[2]*x+m[6]*y+m[10]*z+m[14],m[3]*x+m[7]*y+m[11]*z+m[15]}
end

function make_m_from_euler(x,y,z)
		local a,b = cos(x),-sin(x)
		local c,d = cos(y),-sin(y)
		local e,f = cos(z),-sin(z)
  
    -- yxz order
  local ce,cf,de,df=c*e,c*f,d*e,d*f
	 return {
	  ce+df*b,a*f,cf*b-de,0,
	  de*b-cf,a*e,df+ce*b,0,
	  a*d,-b,a*c,0,
	  0,0,0,1}
end

-- inline matrix vector multiply invert
-- inc. position
function m_inv_x_v(m,v)
	local x,y,z=v[1]-m[13],v[2]-m[14],v[3]-m[15]
	return {m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
end

function m_inv_x_n(m,v)
	local x,y,z=v[1],v[2],v[3]
	return {m[1]*x+m[2]*y+m[3]*z,m[5]*x+m[6]*y+m[7]*z,m[9]*x+m[10]*y+m[11]*z}
end


-- returns basis vectors from matrix
function m_right(m)
	return {m[1],m[2],m[3]}
end
function m_up(m)
	return {m[5],m[6],m[7]}
end
function m_fwd(m)
	return {m[9],m[10],m[11]}
end
function m_set_pos(m,v)
	m[13],m[14],m[15]=unpack(v)
end

-- optimized 4x4 matrix mulitply
function m_x_m(a,b)
	local a11,a21,a31,_,a12,a22,a32,_,a13,a23,a33,_,a14,a24,a34=unpack(a)
	local b11,b21,b31,_,b12,b22,b32,_,b13,b23,b33,_,b14,b24,b34=unpack(b)

	return {
			a11*b11+a12*b21+a13*b31,a21*b11+a22*b21+a23*b31,a31*b11+a32*b21+a33*b31,0,
			a11*b12+a12*b22+a13*b32,a21*b12+a22*b22+a23*b32,a31*b12+a32*b22+a33*b32,0,
			a11*b13+a12*b23+a13*b33,a21*b13+a22*b23+a23*b33,a31*b13+a32*b23+a33*b33,0,
			a11*b14+a12*b24+a13*b34+a14,a21*b14+a22*b24+a23*b34+a24,a31*b14+a32*b24+a33*b34+a34,1
		}
end

-- sort
-- https://github.com/morgan3d/misc/tree/master/p8sort
function sort(data)
	local n = #data 
	if(n<2) return
	
	-- form a max heap
	for i = n\2+1, 1, -1 do
	 -- m is the index of the max child
	 local parent, value, m = i, data[i], i + i
	 local key = value.key 
	 
	 while m <= n do
	  -- find the max child
	  if ((m < n) and (data[m + 1].key > data[m].key)) m += 1
	  local mval = data[m]
	  if (key > mval.key) break
	  data[parent] = mval
	  parent = m
	  m += m
	 end
	 data[parent] = value
	end 
   
	-- read out the values,
	-- restoring the heap property
	-- after each step
	for i = n, 2, -1 do
	 -- swap root with last
	 local value = data[i]
	 data[i], data[1] = data[1], value
   
	 -- restore the heap
	 local parent, terminate, m = 1, i - 1, 2
	 local key = value.key 
	 
	 while m <= terminate do
	  local mval = data[m]
	  local mkey = mval.key
	  if (m < terminate) and (data[m + 1].key > mkey) then
	   m += 1
	   mval = data[m]
	   mkey = mval.key
	  end
	  if (key > mkey) break
	  data[parent] = mval
	  parent = m
	  m += m
	 end  
	 
	 data[parent] = value
	end
end

-->8
-- cam & game objects
function make_cam()
  local up={0,1,0}
  local fwd={0,0,1}
	return {
		pos={0,0,0},    
		track=function(self,pos,m)	
      fwd=m_fwd(m)
      local m={unpack(m)}		
      -- inverse view matrix
      m[2],m[5]=m[5],m[2]
			m[3],m[9]=m[9],m[3]
      m[7],m[10]=m[10],m[7]
      --
      self.m=m_x_m(m,{
        1,0,0,0,
        0,1,0,0,
        0,0,1,0,
        -pos[1],-pos[2],-pos[3],1
      })
      self.pos=pos
    end,
		draw_horizon=function(self,ground_color,sky_color)
			
			-- cam up in world space
			local n=m_up(self.m)
			-- a bit ugly
			v_scale(n,-1)

			-- intersection between camera eye and up plane (world space)
      local x0,y0=63.5,63.5+n[3]*128/n[2]

			-- horizon 'normal'
			n[3]=0
			v_normz(n)
			-- spread clouds
			v_scale(n,16)
			local u,v=n[1],n[2]
			
			-- horizon intersections
			local xl,yl,xr,yr=0,y0-u*x0/v,128,y0+u*(128-x0)/v			
			-- yl: min
			-- yr: max
			if(yl>yr) xl,yl,xr,yr=xr,yr,xl,yl
			
			cls(sky_color)
			rectfill(0,128,128,yr,ground_color)
			polyfill({{x=xl,y=yl},{x=xr,y=yr},{x=xl,y=yr}},ground_color)
		end,    
    draw=function(self,model,model_m)
      -- pack obj to world to cam into a single matrix
      local m,cam_pos=m_x_m(self.m,model_m),m_inv_x_v(model_m,self.pos)
      -- sun vector in model space
      local sun=m_inv_x_n(model_m,{-0.707,-0.707,0})

      -- visible polys (for sorting)
      local polys={}
      for _,part in pairs(model) do
        -- vertex cache
        local verts={}
        for _,face in pairs(part.f) do
          if face.dbl or v_dot(face.n,cam_pos)>=face.cp then
            local p,zkey,outcode,clipcode={},0,0xffff,0          
            for i,k in ipairs(face) do
              local v=verts[k]
              if not v then
                local code,x,y,z=0,unpack(m_x_v(m,part.v[k]))

                if z<1 then code=2 end
                if 2*x>z then code|=4
                elseif 2*x<-z then code|=8 end
                if 2*y>z then code|=16
                elseif 2*y<-z then code|=32 end
                -- save world space coords for clipping
                -- to screen space
                local w=128/z
                v={x,y,z,x=63.5+x*w,y=63.5-y*w,w=w,outcode=code}    
                verts[k]=v
              end
              outcode&=v.outcode
              clipcode+=v.outcode&2              
              zkey+=v[3]
              p[i]=v
            end
            -- visible and not straddling camera plane?
            if outcode==0 and clipcode==0 then            
              p.key=-zkey/#face
              p.face=face
              add(polys,p)          
            end
          end
        end
      end
      -- sort
      sort(polys)
      -- render
      for _,poly in ipairs(polys) do
        --
        local face=poly.face
        local light=mid(-v_dot(sun,face.n),0.0,1)
        -- TY - adjust lighting - overbrighten to preserve original colours, clamp the end result to min 0.2 to avoid crushing anything to black
        light = min( (light * light) * 8 + 0.2, 1 )
        if light>0 then
          pal(_dithers[flr(12*(1-light))],2)

          if face.notex then          
            polyfill(poly,face.c)
          else
            tpoly(poly,face.uv)
          end
        else
          polyfill(poly,0)
        end        
      end
    end
  }
end

-- basic fps controller
function make_player(x,y,z)
  local angle,dangle={0,0,0},{0,0,0}
  local velocity={0,0,0,}

  return {
    pos={x,y,z},
    m=make_m_from_euler(0,0,0),
    update=function(self)
      -- damping
      v_scale(dangle,0.6)
      v_scale(velocity,0.7)

      dangle=v_add(dangle,{stat(39),stat(38),0})
      angle=v_add(angle,dangle,1/1024)

      -- move
      local dx,dz,a=0,0,angle[2]
      if(btn(0,1)) dx=1
      if(btn(1,1)) dx=-1
      if(btn(2,1)) dz=1
      if(btn(3,1)) dz=-1
      local c,s=cos(a),-sin(a)
      velocity=v_add(velocity,{dz*s-dx*c,0,dz*c+dx*s},1/8)
      self.pos=v_add(self.pos,velocity)
      self.m=make_m_from_euler(unpack(angle))
    end
  }
end

-- create a game object with a 3d model
local _loaded={}
function make_3dobject(pos,model)
  if not _loaded[model] then
    -- set normals (not stored in model)  
    for _,part in pairs(model) do
      -- y is flipped?
      for k,v in pairs(part.v) do
        v[1]+=part.pos[1]
        v[2]+=part.pos[2]
        v[3]+=part.pos[3]
        v[2]=-v[2]
      end
      for _,face in pairs(part.f) do
        local v0=part.v[face[1]]
        local n=v_normz(v_cross(make_v(v0,part.v[face[2]]),make_v(v0,part.v[face[#face]])))
        face.n=n
        -- for fast backface culling
        face.cp=v_dot(n,v0)
      end
    end
    _loaded[model]=true
  end

  local rotv=(1-rnd(2))/8
  return {
    pos=pos,
    rot={0,0,0},
    model=model,
    update=function(self)
      -- todo: set pos & rotation according to game rules
      -- example:
      self.rot[2]=rotv*time()

      -- rotation
      local m=make_m_from_euler(unpack(self.rot))
      -- translation
      m_set_pos(m,self.pos)

      -- attach updated matrix
      self.m=m
    end
  }
end

-->8
-- update & draw
function _init()
  -- capture mouse
  -- enable lock+button alias
  poke(0x5f2d,7)

  -- set textures from spritesheet
  -- todo: should be set in game cart
  palt(0,false)
  for i=0,15 do
    for j=0,15 do
      mset(i,j,i+j*16)
    end
  end

  -- shading ramps
  local fadetable={
    {0,0,0,0,0,0,0},
    {1,1,1,0,0,0,0},
    {2,2,2,1,0,0,0},
    {3,3,3,1,0,0,0},
    {4,2,2,2,1,0,0},
    {5,5,1,1,1,0,0},
    {6,13,13,5,5,1,0},
    {6,6,13,13,5,1,0},
    {8,8,2,2,2,0,0},
    {9,4,4,4,5,0,0},
    {10,9,4,4,5,5,0},
    {11,3,3,3,3,0,0},
    {12,12,3,1,1,1,0},
    {13,5,5,1,1,1,0},
    {14,13,4,2,2,1,0},
    {15,13,13,5,5,1,0}
  }
  for j=1,7,0.5 do
    local dithered_fade={}    
    for i,fade in pairs(fadetable) do
      dithered_fade[i-1]=fade[flr(j+0.5)]|fade[flr(j)]<<4
    end
    _dithers[(j-1)*2]=dithered_fade
  end

  _cam=make_cam()
  _plyr=make_player(0,5,-10)
  _entities={
    make_3dobject({5,0,5},chunky_tank),
    make_3dobject({-5,0,5},chunky_tank),
    make_3dobject({-5,0,-5},chunky_tank),
    make_3dobject({5,0,-5},chunky_tank)
  }
end

function _update()
  _plyr:update()
  
  for _,e in pairs(_entities) do
    e:update()
  end

  _cam:track(_plyr.pos,_plyr.m)

end

function _draw()
  fillp()
  _cam:draw_horizon(3,12)
  -- dithered fill mode
  fillp(0xa5a5|0b0.011)

  -- collect entities
  local drawables={}
  for _,e in pairs(_entities) do
    local p=m_x_v(_cam.m,e.pos)
    add(drawables,{model=e.model,m=e.m,key=-p[3]})
  end
  -- global sort
  sort(drawables)
  -- draw
  for _,d in ipairs(drawables) do
    _cam:draw(d.model,d.m)
  end
end

__gfx__
00000000dddddddddddddddddddddddddddddddddddddddddddd55dddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000
00000000dccccccccccccccddccccccccccccccddd1111dddcccd6cccccccccccccccccccccccccddccccccccccccccccccccccccccccccd0000000000000000
00000000dccccccccccccccddccccccccccccccdd111111ddcc5dccccccccccccccccccccccccccddc66cccccccccccccccccccccccc66cd0000000000000000
00000000dcccccccccccc888888ccccccccccccdd111111ddc5d6cccccccc555555ccccccccccccddc55cccccccccccccccccccccccc55cd0000000000000000
00000000dcc777777ccc88888888ccc777777ccdd111111ddcdccccccccc57777775cccccccccccddccccccccccccccccccccccccccccccd0000000000000000
00000000dccc777777c8887777888c777777cccdd111111ddd6ccccccccc77000077cccccccccccddccccccccccccccccccccccccccccccd0000000000000000
00000000dccccccc77c8877777788c77cccccccddd1111dddcc5555555cc70000007cc5555555ccddccccccccccccccccccccccccccccccd0000000000000000
00000000dccccc77777887788778877777cccccddddddddddcc7777777cc70000007cc7777777ccddc555555cccccccccccccccc555555cd0000000000000000
11111111dcccccc777788778877887777ccccccd00000000dcc7000007cc70555507cc7000007ccddc500005cccccccccccccccc500005cd0000000000000000
11111111dcccccccc77887777778877ccccccccd00000000dcc7555557cc70555507cc7555557ccddc5cccc5cccccccccccccccc5cccc5cd0000000000000000
11111111dcccccccc77888777788877ccccccccd00000000dcc6777776cc77000077cc6777776ccddcc7777cccccccccccccccccc7777ccd0000000000000000
11111111dccccccccc7c88888888c7cccccccccd00000000dccccccccccc67777776cccccccccccddccccccccccccccccccccccccccccccd0000000000000000
11111111dcccccccccccc888888ccccccccccccd00000000dccccccccccccccccccccccccccccccddccccccccccccccccccccccccccccccd0000000000000000
11111111dcccccccccccccc55ccccccccccccccd00000000dccccccccc555555555555cccccccccddccccccccccccccccccccccccccccccd0000000000000000
11111111ddddddddddddddd55ddddddddddddddd00000000ddddddddcc551111111155ccddddddddddddddddcccc66666666ccccdddddddd0000000000000000
11111111555555555555555115555555555555550000000055555555cc666666666666cc5555555555555555ccc6666666666ccc555555550000000000000000
000dddddddddddddddd111111111111ddddd56ddddddd000dddddddddddddddd1111111111111111dddddddddddddddddddddddddccc66666666cccd00000000
000dccccccccccccccddddddddddddddccccd6ccccccd000dccccccccccccccd1115555555555111dcccccccccc56ccccccccccddccccccccccccccd00000000
00dccc6666ccccccccccccccccccccccccccd6cccccccd00dccc66666666cccd5551111111111555dcccccccccc56ccccccccccddccccccccccccccd00000000
00dccdd55ddccccccccd5555555555dcccccd6cccccccd00dccc66666666cccd5555555555555555556cccccccc56ccccccccccddcc66cccccc66ccd00000000
0dccc677776cccccccccccccccccccccccccd6ccccccccd0dccc51111115cccd1115555555555111ddccccccccc56ccccccccccddcc55cccccc55ccd00000000
0dccdd5555ddcccccccd5555555555dcccccd6ccccccccd0dccc5cccccc5cccd5551111111111555dcccccccccc56ccccccccccddccccccccccccccd00000000
dcccccccccccccccccccccccccccccccccccd6cccccccccddccccccccccccccd5555555555555555dcccccccccc56ccccccccccddccccccccccccccd00000000
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd0000000000000000dccc5ddddddddddd6ccccccddccddddddddddccd00000000
511000000000000000000000000000000000000000000000dddddddddddddddddddddddddddddddddccc5dcccccccccd6ccccccddcd5555555555dcd00000000
511000000000000000000000000000001111111111111101dddddddddddddddddddddddddddddddddccc5dcccccccccd6ccccccddd511111111115dd00000000
05110000000000000000000000000000155555555555511066666666666666666666666666666666dccc5dcccccccccd6ccccccd551000000000015500000000
05110000000000000000000000000000155dd555555d515066666666666666666666666666666666dccc5dcccccccccd6ccccccd510000000000001500000000
0051100000000000000000000000000001555dddddd5150066666666666666666666666666666666dccc5dcccccccccd6ccccccd511111111111111500000000
00511000000000000000000000000000001155555551110066666666666666666666666666666666dccc5dcccccccccd6ccccccd511100000000111500000000
000511111111111111111111111111111111111111115000dddddddddddddddddddddddddddddddddccc5dcccccccccd6ccccccd111100000000111100000000
000055551555155515551555155515551555155515550000dddddddddddddddddddddddddddddddddccc5dcccccccccd6ccccccd111111111111111100000000
ddddddddddddddddddddddddddddddddddddddd5dddddddddddddddddddddddddddddddddddddddddccc5ddddddddddd6ccccccd000000000000000000000000
dccccccccccccccccccccccccccccccccccccccd6ccccccddddddddddddddddddddddddddddddddddcccccccccc56ccccccccccd000000000000000000000000
dccccccccccccccccccccccccccccccccccccccd6ccccccd55555555555555555555555555555555dcccccccccc56ccccccccccd000000000000000000000000
dccccccccccccccccccccccccccccccccccccccd6ccccccd55555555555555555555555555555555dcccccccccc56ccccccccccd000000000000000000000000
dccccccccccccccccccccccccccccccccccccccd6ccccccd55555555555555555555555555555555dcccccccccc56ccccccccccd000000000000000000000000
dcccccccccccccccddddddddddddddddcccccccd6ccccccd55555555555555555555555555555555dcccccccccc56ccccccccccd000000000000000000000000
dcccccccccccccccd55115511551155dcccccccd6ccccccd11111111111111111111111111111111dcccccccccc56ccccccccccd000000000000000000000000
ddddddddddddddddd55115511551155dddddddd56ddddddd11111111111111111111111111111111dddddddddddddddddddddddd000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000d6d000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000ddccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000ccccccccc600000000000000000000000000000000000000000000000000000000c6cccc00000000000000000
000000000000000000000000000000000000000cdccdcddccc000000000000000000000000000000000000000000000000000dcdcc6dddcd66dddddd00000000
00000000000000000000000000000000000000c7cd5ddcccccd00000000000000000000000000000000000000000000000000cccccdccc7d5555555000000000
00000000000000000000000000000000000000c87cccc77cccc6000000000000000000000000000000000000000000000000dc7787787ccd1111111000000000
00000000000000000000000000000000000dddd8cc57c00c00cd1000000000000000000000000000000000000000000000dcccc787787ccccd00000000000000
000000000000000000000000000000000001ccccdc57c006ccccdd00000000000000000000000000000000000000000000dccccc888ccccccc00000000000000
00000000000000000000000000000000000cdcc5dccc55115dd5cccd00000000000000000000000000000000000000000ddddddd51555cc6cc00000000000000
00000000000000000000000000000000000ccdcc5ccdccccccddcccc0000000000000000000000000000000000000000cdddddd111111dd6cc60000000000000
000000000000000000000000000000000000cdcccccd5cccc7c6666c0000000000000000000000000000000000000000dc66cccccc55dcc6ccd0000000000000
00000000000000000000000000000000000dcdc666cd55515cdccccc0000000000000000000000000000000000000000cd5dcccd5555ccccccc0000000000000
0000000000000000000000000000000000050dc5cccc111110dd1111000000000000000000000000000000000000000dddddddddddd000000000000000000000
00000000000000000000000000000000002201d11111122210515555000000000000000000000000000000000000000010000000000005555510000000000000
00000000000000000000000000000000000211515555222221515555200000000000000000000000000000000000000210000000000005d55d00000000000000
000000000000000000000000000000dd0002215155d666d222222000000000000000000000000000000000000000000205111111111101555120000000000000
000000000000000000000000000ccccccd00222d666dddd000000000000000000000000000000000000000000000000000000222225515555220000000000000
00000000000000000000000d6ccc6cccccd0d666ddddd55000000000000000000000000000000000000000000000000000000000000000000020000000000000
00000000000000000000dccc5dccd6ccccccdddddd55555500000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000cccccccccccdccccdddcdd55555555100000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005dcc5dcccdc56cdddccccd55555511110000000000000000000000000000000000000000000000000000000000000000000000000000000d
000000000000000ccdccc5cccccddcccccc77c111100000000000000000000000000000000000000000000000000000000000000000000000000000000000005
000000000000000cccdcccccddccdd8cc777ccd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000005c
0000000000000005c5cddddccccc88888777ccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000dccc0d
00000000000000c077ccccccccc88777877ccccd0000000000000000000000000000000000000000000000000000000000000000000000000000000000dccccc
000000000000ddc557cccc7777c87887877cccccdc0000000000000000000000000000000000000000000000000000000000000000000000000000000cddd7dc
0000000000dccccc5c5dcc7cc77877778cccccdd5ccd00000000000000000000000000000000000000000000000000000000000000000000000000001dcc6ccc
000000000cdcccdc7c7dccc777788888cccdd556ccccc00000000000000000000000000000000000000000000000000000000000000000000000000ddcdd5dcc
000000000ccdddd5c60dccccc778885cdd55cccd6cdddd0000000000000000000000000000000000000000000000000000000000000000000000000dccd7dccc
00000000d66ddcc65c6dccccccccc555cccccccdd6dcccc000000000000000000000000000000000000000000000000000000000000000000000000ddcccdccc
00000000c1ccc65d6ccdcccccdd55ccdd15dddddd6cccccd00000000000000000000000000000000000000000000000000000000000000000000000cdcc55555
00000000ccccc775cdddccdd55ccdd115111dcccd6cccccd0000000000000000000000000000000000000000000000000000000000000000000000ddcccccccc
00000000dcdcd5ddcccdd55cccd515111ddcccccd6cccccdd0000000000000000000000000000000000000000000000000000000000000000000006ddddddddd
000000000dccddddccc5cccccddd1dddcc55dcccd6ccddd0000000000000000000000000000000000000000000000000000000000000000000000cdccccccccc
0000000000d12dcdccccccddddcddcc555ccdcccdddd0011000000000000000000000000000000000000000000000000000000000000000000000cccdd55ddcc
0000000022222c6ddcdddddcccccd55cc555ccddd001115100000000000000000000000000000000000000000000000000000000000000000000cdcdd57776cc
0000000002222c6cddddcccccccccc555ccddd000115555100000000000000000000000000000000000000000000000000000000000000000000ddcccccccccc
000000000222d56cdcc66dccccccdcccddd000115555551500000000000000000000000000000000000000000000000000000000000000000000110000dddddd
000000000022dc1cccd576cccccccdd000000055d55dd51000000000000000000000000000000000000000000000000000000000000000000000510000000000
000000000022dc5dcc6555cccddd0000000000555d55511200000000000000000000000000000000000000000000000000000000000000000000211000000000
0000000000022dcdcdcccddd00000000000000011511155220000000000000000000000000000000000000000000000000000000000000000002211000000000
00000000000222cccddd000000000000000000111155222220000000000000000000000000000000000000000000000000000000000000000002251100000000
00000000000022dd1000000000000000001115152222200000000000000000000000000000000000000000000000000000000000000000000002225551111111
00000000000022211000000000000011155122222000000000000000000000000000000000000000000000000000000000000000000000000000222222555155
00000000000002221100000000111555222220000000000000000000000000000000000000000000000000000000000000000000000000000000000002222225
00000000000000222110001115512222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000022
00000000000000222111115522222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000022255222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000022222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000002200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

