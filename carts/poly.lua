function polyfill(v,c)	
	if(#v<3) return
	color(c)
	local p0,spans=v[#v],{}
	local x0,y0=p0.x,p0.y
	-- ipairs is slower for small arrays
	for i=1,#v do
		local p1=v[i]
		local x1,y1=p1.x,p1.y
		local _x1,_y1,_v1=x1,y1
		if(y0>y1) x0,y0,x1,y1=x1,y1,x0,y0
		local dx=(x1-x0)/(y1-y0)
		local cy0=y0\1+1
		if(y0<0) x0-=y0*dx y0=0 cy0=0
		-- sub-pix shift
		x0+=(cy0-y0)*dx
		if(y1>127) y1=127
		for y=cy0,y1 do
			local span=spans[y]
			if span then
				rectfill(x0,y,span,y)
			else
				spans[y]=x0
			end
			x0+=dx
		end
		x0,y0=_x1,_y1
	end
end

function polyline(v,c)
	color(c)
	local nv=#v
	for i,p1 in pairs(v) do
		local p0=v[i%nv+1]
		line(p0.x,p0.y,p1.x,p1.y)
	end
end

function tpoly(v,uv)
	local p0,spans=v[#v],{}
	local x0,y0=p0.x,p0.y
	local u0,v0=uv[#uv-1],uv[#uv]
	-- ipairs is slower for small arrays
	for i=1,#v do
		local p1=v[i]
		local x1,y1=p1.x,p1.y
		local u1,v1=uv[2*i-1],uv[2*i]
		local _x1,_y1,_u1,_v1=x1,y1,u1,v1
		if(y0>y1) x0,y0,x1,y1,u0,v0,u1,v1=x1,y1,x0,y0,u1,v1,u0,v0
		local dy=y1-y0
		local dx,du,dv=(x1-x0)/dy,(u1-u0)/dy,(v1-v0)/dy
		local cy0=y0\1+1
		if(y0<0) x0-=y0*dx u0-=y0*du v0-=y0*dv y0=0 cy0=0
		-- sub-pix shift
		local sy=cy0-y0
		x0+=sy*dx
		u0+=sy*du
		v0+=sy*dv
		if(y1>127) y1=127
		for y=cy0,y1 do
			local span=spans[y]
			if span then
				--rectfill(x[1],y,x0,y,offset/16)
				
				local a,au,av,b,bu,bv=x0,u0,v0,unpack(span)
				if(a>b) a,au,av,b,bu,bv=b,bu,bv,a,au,av
				local ca,cb=a\1+1,b\1
				if ca<=cb then
					-- pixel perfect sampling
					local sa,dab=ca-a,b-a
					local dau,dav=(bu-au)/dab,(bv-av)/dab
					tline(ca,y,cb,y,au+sa*dau,av+sa*dav,dau,dav)
				end
			else
				spans[y]={x0,u0,v0}
			end
			x0+=dx
			u0+=du
			v0+=dv
		end
		x0,y0,u0,v0=_x1,_y1,_u1,_v1
	end
end

-- perpsective correct rasterization for polygons n=(0 1 0)
function tpoly_flat(v,uv)
	local p0,spans=v[#v],{}
	local x0,y0,w0=p0.x,p0.y,p0.w
	-- ensure proper interpolation in screen space
	local u0,v0=uv[#uv-1]*w0,uv[#uv]*w0
	-- ipairs is slower for small arrays
	for i=1,#v do
		local p1=v[i]
		local x1,y1,w1=p1.x,p1.y,p1.w
		local u1,v1=uv[2*i-1]*w1,uv[2*i]*w1
		local _x1,_y1,_u1,_v1,_w1=x1,y1,u1,v1,w1
		if(y0>y1) x0,y0,x1,y1,u0,v0,w0,u1,v1,w1=x1,y1,x0,y0,u1,v1,w1,u0,v0,w0
		local dy=y1-y0
		local dx,du,dv,dw=(x1-x0)/dy,(u1-u0)/dy,(v1-v0)/dy,(w1-w0)/dy
		local cy0=y0\1+1
		if(y0<0) x0-=y0*dx u0-=y0*du v0-=y0*dv w0-=y0*dw y0=0 cy0=0
		-- sub-pix shift
		local sy=cy0-y0
		x0+=sy*dx
		u0+=sy*du
		v0+=sy*dv
		w0+=sy*dw
		if(y1>127) y1=127
		for y=cy0,y1 do
			local span=spans[y]
			if span then
				--rectfill(x[1],y,x0,y,offset/16)
				
				local x0,u0,v0,w0,x1,u1,v1,w1=x0,u0,v0,w0,unpack(span)
				if(x0>x1) x0,u0,v0,w0,x1,u1,v1,w1=x1,u1,v1,w1,x0,u0,v0,w0
				local rx,lx=x0\1+1,x1\1
				if rx<=lx then
					-- pixel perfect sampling
					local sdx,dab=rx-x0,x1-x0
					-- perspective correction
					local du,dv=(u1/w1-u0/w0)/dab,(v1/w1-v0/w0)/dab
					tline(rx,y,lx,y,u0/w0+sdx*du,v0/w0+sdx*dv,du,dv)
				end
			else
				spans[y]={x0,u0,v0,w0}
			end
			x0+=dx
			u0+=du
			v0+=dv
			w0+=dw
		end
		x0,y0,u0,v0,w0=_x1,_y1,_u1,_v1,_w1
	end
end