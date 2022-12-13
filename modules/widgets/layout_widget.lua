require('awful')



local widget = {
  fit = function (context, width, height)
    local m math.min(width, height)
    return m, m
  end
}
return widget
