-- Laser Distance Sensor geht von -1 bis 1
img_res = 10
scanning = true
contin = true
curpos = 1
posmax = img_res*img_res
zoom = 1 -- 1 -> 0
x0,y0 = 0,0
image = {}

function to_xy(pos,n)
	-- returns (x,y) for a position integer between 1 and n*n
	return {x=(pos-1)%n+1,y=(pos-1)//n+1}
end

function pos_to_laserc(pos,n,x0,y0,zoom)
	-- computes the needed laser position to capture matrix position `pos`
	local coords = to_xy(pos,n)
	return {x=2*zoom*coords.x/(n)-zoom/n - zoom + x0,y=-2*zoom*coords.y/n + zoom/n + zoom + y0}
end


function onTick()
	-- Read data
	dst = input.getNumber(1)
	
	if scanning then
		laser_out = pos_to_laserc(curpos,img_res,x0,y0,zoom)
		image[curpos] = dst
		print(curpos)
		print(laser_out)
		curpos = curpos + 1
		
		if curpos-1 >= posmax then
			scanning = false
			curpos = 1
		end
	end
	
	output.setNumber(1,laser_out.x)
	output.setNumber(2,laser_out.y)
end

function onDraw()
    -- your code
end
