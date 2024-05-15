-- Various methods

---@class DS_CommonMethods
local DS_CommonMethods = {}

function DS_CommonMethods.DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == 'table' then
            copy[k] = DS_CommonMethods.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

return DS_CommonMethods