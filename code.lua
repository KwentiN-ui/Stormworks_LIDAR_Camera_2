-- Colors
backgr = {0, 30, 30} -- background
textc = {255,255,255} -- text
colorscale = {r=0,g=1,b=0} -- image, values between 0-1


img_res = 10
scanning = false
contin = false
curpos = 1
zoom = 0.5 -- 1 -> 0
w,h = 64,64
x0,y0 = 0,0
image = {}
upscaled_img = {}
pad = 6

scanbutton = {cur=false,last=false}

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
    
    if math.floor(n) ~= n then
        error("Invalid vector size. Vector length must be a perfect square.")
    end
    
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
	posmax = img_res*img_res

	-- Read data
	dst = input.getNumber(10)
	isPressed = input.getBool(1)
	inputX = input.getNumber(3)
    inputY = input.getNumber(4)
    
    
    scanbutton.cur = isPressed and isPointInRectangle(inputX, inputY, w-pad, 0, pad, 8)

	if scanbutton.cur and not scanbutton.last then scanning=not scanning end
	output.setBool(1,scanning)
	if scanning then
		laser_out = pos_to_laserc(curpos,img_res,x0,y0,zoom)
		image[curpos] = dst
		curpos = curpos + 1
		
		if curpos-1 >= posmax then -- SCAN FINISHED
			--scanning = false
			curpos = 1
			image = normalize(image,0,100)
			upscaled_img = upscale(image,w-pad,h-pad)
		end
		
		output.setNumber(1,laser_out.x)
		output.setNumber(2,laser_out.y)
		output.setBool(1,scanning)

	end
	
	scanbutton.last = scanbutton.cur
end

function onDraw()
	w,h = screen.getWidth(),screen.getHeight()
	-- will always be drawn:
	screen.setColor(table.unpack(backgr)) --BG
	screen.drawClear()
	screen.setColor(255*colorscale.r,255*colorscale.g,255*colorscale.b)
	if scanning then screen.setColor(0,255,0) else screen.setColor(255,255,255) end
	screen.drawTextBox(0,0,w-1,8,"S",1,0)
	
    if image[1]~=nil then
    	for i=1,#upscaled_img do
    		px = to_xy(i,w-pad)
    		val = upscaled_img[i]
    		if val==nil then val = 0 end
    		screen.setColor(val*colorscale.r,val*colorscale.g,val*colorscale.b)
    		screen.drawRectF(px.x-1,px.y-1,1,1)
    		screen.setColor(255,0,0)

    	end
    elseif image[1]==nil then
    	screen.setColor(255,255,255)
    	screen.drawText(2,2,"no\ndata")
    end
end
