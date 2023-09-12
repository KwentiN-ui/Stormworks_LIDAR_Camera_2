-- Laser Distance Sensor geht von -1 bis 1
img_res = 16
scanning = false
contin = false
curpos = 1
zoom = 0.5 -- 1 -> 0
w,h = 64,64
x0,y0 = 0,0
image = {}
upscaled_img = {}
function to_xy(pos,n)
	-- returns (x,y) for a position integer between 1 and n*n
	return {x=(pos-1)%n+1,y=(pos-1)//n+1}
end

function x2upscale(img,n)
	local upscaled = {}
	for i,v in ipairs(img) do
		table.insert(upscaled,v)
		
		oben = img[i-n]
		unten = img[i+n]
		links = img[i-1]
		rechts = img[i+1]
		amt = 4
		if oben == nil then
			oben = 0
			amt = amt-1
		end
		if unten == nil then
			unten = 0
			amt = amt-1
		end
		if links == nil then
			links = 0
			amt = amt-1
		end
		if rechts == nil then
			rechts = 0
			amt = amt-1
		end
				
		interpol = (oben+unten+links+rechts)/amt
		
		table.insert(upscaled,interpol)
	end
	return upscaled
end

function mult_upscale(img,n,k)
	if k==0 then return img end
	local upscaled = img
	local nl = n
	for i=1,k do
		upscaled = x2upscale(upscaled,nl)
		nl = nl*2
	end
	return upscaled
end

function pos_to_laserc(pos,n,x0,y0,zoom)
	-- computes the needed laser position to capture matrix position `pos`
	local coords = to_xy(pos,n)
	return {x=2*zoom*coords.x/(n)-zoom/n - zoom + x0,y=-2*zoom*coords.y/n + zoom/n + zoom + y0}
end

function normalize(vector,minValue,maxValue)
	local sorted = {}
	for i,v in ipairs(vector) do
		sorted[i] = v
	end
	table.sort(sorted)
    local minVector = sorted[1]
    local maxVector = sorted[#sorted]
    
    local scaledVector = {}
    
    for i, value in ipairs(vector) do
        local scaledValue = ((value - minVector) / (maxVector - minVector)) * (maxValue - minValue) + minValue
        table.insert(scaledVector, scaledValue)
    end
    
    return scaledVector
end

function onTick()
	posmax = img_res*img_res

	-- Read data
	dst = input.getNumber(1)
	if input.getBool(1) then scanning=true end
	output.setBool(1,scanning)
	if scanning then
		laser_out = pos_to_laserc(curpos,img_res,x0,y0,zoom)
		image[curpos] = dst
		curpos = curpos + 1
		
		if curpos-1 >= posmax then
			scanning = false
			curpos = 1
			image = normalize(image,0,100)
			scaling = math.tointeger(math.log(h^2/img_res^2)/math.log(2))
			upscaled_img = mult_upscale(image,img_res,scaling)
		end
		
		output.setNumber(1,laser_out.x)
		output.setNumber(2,laser_out.y)
		output.setBool(1,scanning)

	end
	
end

function onDraw()
	w,h = screen.getWidth(),screen.getHeight()
	if scanning and not contin then
		progress = math.floor(curpos/posmax*100)
		screen.setColor(255-progress*2.55,progress*2.55,0)
		screen.drawTextBox(0,0,w,h,tostring(progress).."%",0,0)	
	end
    if not scanning and image[1]~=nil then
    	for i=1,h*h do
    		px = to_xy(i,h)
    		val = upscaled_img[i]
    		screen.setColor(0,val,0)
    		screen.drawRectF(px.x-1,px.y-1,1,1)
    		screen.setColor(255,0,0)

    	end
    elseif image[1]==nil then
    	screen.setColor(255,255,255)
    	screen.drawText(2,2,"no\ndata")
    end
end
