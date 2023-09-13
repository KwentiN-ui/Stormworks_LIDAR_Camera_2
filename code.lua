-- Colors
backgr = {0, 30, 30} -- background
textc = {255,255,255} -- text
colorscale = {r=0,g=1,b=0} -- image, values between 0-1

-- SETTINGS
pos_offset = 6 -- make larger if you have black upper left corner
img_res = 16   -- default resolution
zoom = 0.5     -- default zoom. Between 1 and 0

setc = screen.setColor

posmax = img_res^2
scanning = false
contin = false
curpos = 1 - pos_offset
w,h = 64,64 
x0,y0 = 0,0
image = {}
upscaled_img = {}
upscaled_data = {}
pad = 6
selected = {px=nil,py=nil,val=nil}

mode = 2

scanbutton = {cur=false,last=false}
zoombutton = {cur=false,last=false}
modebutton = {cur=false,last=false}


function isPointInRectangle(x, y, rectX, rectY, rectW, rectH)
	return x > rectX and y > rectY and x < rectX+rectW and y < rectY+rectH
end

function to_xy(pos,n)
	-- returns (x,y) for a position integer between 1 and n*n
	return {x=(pos-1)%n+1,y=math.floor((pos-1)/n)+1}
end

function to_pos(x, y, n)
    -- returns the position integer for given (x, y) coordinates in an n*n matrix
    return (y-1)*n + x
end

function upscale(vector, new_width, new_height)
    local size = #vector
    local n = math.sqrt(size)
    
    local scale_x = new_width / n
    local scale_y = new_height / n
    
    local resized_vector = {}
    
    for y = 1, new_height do
        local source_y = (y - 0.5) / scale_y + 0.5
        
        if source_y < 1 then
            source_y = 1
        elseif source_y > n then
            source_y = n
        end
        
        local y1 = math.floor(source_y)
        local y2 = math.ceil(source_y)
        local y_alpha = source_y - y1
        
        for x = 1, new_width do
            local source_x = (x - 0.5) / scale_x + 0.5
            
            if source_x < 1 then
                source_x = 1
            elseif source_x > n then
                source_x = n
            end
            
            local x1 = math.floor(source_x)
            local x2 = math.ceil(source_x)
            local x_alpha = source_x - x1
            
            local top_left = vector[(y1-1)*n + x1]
            local top_right = vector[(y1-1)*n + x2]
            local bottom_left = vector[(y2-1)*n + x1]
            local bottom_right = vector[(y2-1)*n + x2]
            
            local interpolated_value = (1 - y_alpha) * ((1 - x_alpha) * top_left + x_alpha * top_right) + 
                                       y_alpha * ((1 - x_alpha) * bottom_left + x_alpha * bottom_right)
            
            table.insert(resized_vector, interpolated_value)
        end
    end
    
    return resized_vector
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
	-- Read data
	dst = input.getNumber(10)
	isPressed = input.getBool(1)
	inputX = input.getNumber(3)
    inputY = input.getNumber(4)
    
    tilt_comp = {x=10*input.getNumber(12),y=10*input.getNumber(11)}
    if tilt_comp.x==nil then tilt_comp.x=0 end
    if tilt_comp.y==nil then tilt_comp.y=0 end
    
    -- Toggle Scan
    scanbutton.cur = isPressed and isPointInRectangle(inputX, inputY, w-pad, 0, pad, 8)
	if scanbutton.cur and not scanbutton.last then curpos = 1 - pos_offset image = {} scanning=not scanning end
	
	-- Zoom to selection
	zoombutton.cur = isPressed and isPointInRectangle(inputX,inputY,w-pad, 16, pad, 8)
	
	if zoombutton.cur and not zoombutton.last then
		scanning = true
		curpos = 1 - pos_offset
		image = {}
		if selected.val~=nil then
			zoom = zoom/2
			-- X0,Y0 anpassen!
			x0 = x0 + selected.px/(w-pad) * 2*zoom -zoom
			y0 = y0 + -selected.py/(h-pad) * 2*zoom +zoom
		else
			zoom = 2*zoom
			if zoom>1 then zoom=1 end
		end
		selected = {px=nil,py=nil,val=nil}
	end
	
	-- Cycle mode
	modebutton.cur = isPressed and isPointInRectangle(inputX,inputY,w-pad, h-pad, pad, pad)
	if modebutton.cur and not modebutton.last then
		mode = mode+1
		if mode>5 then mode=1 end
		
		if mode==1 then img_res = h end
		if mode==2 then img_res = h//2 end
		if mode==3 then img_res = h//4 end
		if mode==4 then img_res = h//8 end
		if mode==5 then img_res = h//16 end
		curpos = 1 - pos_offset
		posmax = img_res^2
		image = {}
	end
	
	reset = isPressed and isPointInRectangle(inputX,inputY,w-pad, 8, pad, 8)
	if reset then 
		zoom = 0.5 x0,y0 = 0,0 
		selected = {px=nil,py=nil,val=nil}
		curpos = 1 - pos_offset
		image = {}
		end
	
	-- Pixel selection
	if upscaled_data[1]~=nil and isPressed and isPointInRectangle(inputX, inputY, 0, 0, w-pad, h-pad) then
		selected.px = inputX
		selected.py = inputY
		selected.val = math.floor(upscaled_data[to_pos(inputX,inputY,w-pad)]*10)/10
	end
	
	-- clear selection (press on lower padding zone)
	if isPressed and isPointInRectangle(inputX, inputY, 0, h-pad, w-pad, pad) then
		selected = {px=nil,py=nil,val=nil}
	end
	
	if scanning then
		if curpos>0 then image[curpos] = dst end
		
		curpos = curpos + 1
		
		if curpos-1 >= posmax then -- SCAN FINISHED
			curpos = 1 - pos_offset
			normalized = normalize(image,0,255)
			upscaled_img = upscale(normalized,w-pad,h-pad)
			upscaled_data = upscale(image,w-pad,h-pad)
			image = {}
		end
		
		laser_out = pos_to_laserc(curpos,img_res,x0 - tilt_comp.x,y0 - tilt_comp.y,zoom)
		output.setNumber(1,laser_out.x)
		output.setNumber(2,laser_out.y)
	end
	
	output.setBool(1,scanning)
	scanbutton.last = scanbutton.cur
	zoombutton.last = zoombutton.cur
	modebutton.last = modebutton.cur
end

function onDraw()
	w,h = screen.getWidth(),screen.getHeight()
	-- will always be drawn:
	setc(table.unpack(backgr)) --BG
	screen.drawClear()
	setc(0,0,0)
	screen.drawRectF(0,0,w-pad,h-pad)
	
	if scanning then setc(0,255,0) else setc(table.unpack(textc)) end
	screen.drawTextBox(0,0,w-1,8,"S",1,0)
	
	if reset then setc(0,255,0) else setc(table.unpack(textc)) end
	screen.drawTextBox(0,8,w-1,8,"R",1,0)
	
	if zoombutton.cur then setc(0,255,0) else setc(table.unpack(textc)) end
	if selected.val~=nil then
		screen.drawTextBox(0,16,w-1,8,"+",1,0)
	else
		screen.drawTextBox(0,16,w-1,8,"-",1,0)
	end
	
	-- Modusanzeige
	setc(table.unpack(textc))
	if mode==1 then
		screen.drawRectF(w-pad,h-pad,pad,pad)	
	end
	if mode==2 then
		screen.drawRectF(w-pad,h-pad,pad/2,pad)	
	end
	if mode==3 then
		screen.drawRectF(w-pad,h-pad,pad/2,pad/2)	
	end
	if mode==4 then
		screen.drawRectF(w-pad,h-pad,pad/4,pad/2)	
	end
	if mode==5 then
		screen.drawRectF(w-pad,h-pad,pad/4,pad/4)
	end
	
    -- Progress line
	if scanning then
    	setc(table.unpack(textc))
    	screen.drawLine(0,h-pad,curpos/posmax*(w-pad),h-pad)
	end
	
    if upscaled_img[1]~=nil then
    	for i=1,#upscaled_img do
    		px = to_xy(i,w-pad)
    		val = upscaled_img[i]
    		if val==nil then val = 0 end
    		setc(val*colorscale.r,val*colorscale.g,val*colorscale.b)
    		screen.drawRectF(px.x-1,px.y-1,1,1)
    	end

    	-- Pixel selection marker
    	if selected.val~=nil then
    		setc(table.unpack(textc))
    		screen.drawCircle(selected.px,selected.py,3)
    		screen.drawTextBox(0,h-pad+1,w-pad,pad,selected.val,0)
    	end
    elseif upscaled_img[1]==nil then
    	setc(table.unpack(textc))
    	screen.drawTextBox(0,1,w-pad,8,"SCAN>",1)
    	screen.drawTextBox(0,9,w-pad,8,"RST>",1)
    	screen.drawTextBox(0,17,w-pad,8,"ZOOM>",1)
    	screen.drawTextBox(0,h-pad+1,w-pad,8,"RES>",1)
    end
end
