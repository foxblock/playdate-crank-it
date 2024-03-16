if vec3d then return end  -- avoid loading twice the same module
vec3d = {}  -- create a table to represent the module

function vec3d.len(x, y, z)
    return math.sqrt(x*x + y*y + z*z)
end

function vec3d.norm(x, y, z)
    local len = vec3d.len(x, y, z)
    return x/len, y/len, z/len
end

-- assumes v1 is a normalized 3D-vector stored as a table with 3 entries: {[1] = x, [2] = y, [3] = z}
function vec3d.dot(v1, x2, y2, z2)
    return ((v1[1] * x2 + v1[2] * y2 + v1[3] * z2) / vec3d.len(x2, y2, z2))
end