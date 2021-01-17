local vim = _G.vim
local M = {}
local uv = vim.loop


-- Creates a simple timeout function
--
-- local timer = setTimeout(1000, function(x) print(x) end, 'foo')
--
-- takes a timeout value in miliseconds and a callback and returns a timer instance
-- that can be used to cancel the execution of the callback before the timer runs out
-- the callback is executed after the amount of time `timeout` passes
M.setTimeout = function(timeout, callback, ...)
  local timer = uv.new_timer()
  local args = {...}

  local function ontimeout()
    -- clear timer before invoking callback
    if (not timer:is_active()) then timer:stop() end
    if (not timer:is_closing()) then timer:close() end
    callback(unpack(args))
  end
  timer:start(timeout, 0, vim.schedule_wrap(ontimeout))

  return timer
end

-- Clears a timeout handler
-- local timer = setTimeout(1000, function() print('foo') end)
-- clearTimeout(timer)
M.clearTimeout = function(timer)
  if (not timer:is_active()) then timer:stop() end
  if (not timer:is_closing()) then timer:close() end
end


-- created a debounced functions that delays invoking
-- `func` until `wait` miliseconds has elapsed since the last time
-- `func` was called
-- leading ensures that `func` is called immediate on the first call
-- to debounced.
-- local debounced = debounce(250, func, { leadingEdge: true })
-- returned function has `cancel` and `flush` methods
-- `cancel` to clean up and prevent further invocations of `func`
-- `flush` to immediate invoke `func`
-- sourced from: https://github.com/lodash/lodash/blob/42e2585e5fef7075b06c99ce4b6ef36003348fd3/debounce.js
M.debounce = function(wait, func, options, ...)
  wait = wait or 0
  options = options or {}
  local leading = options.leading or false
  local args = {...}
  local timer
  local lastCallTime
  local results
  local dbnc = {}

  -- invoce the func
  local function invokeFunc()
    results = func(unpack(args))
    return results
  end

  -- time remaining on wait
  local function timeRemaining(time)
    return wait - (time - (lastCallTime or 0))
  end

  -- should we invoke the func?
  local function shouldInvoke(time)
    local timeSinceLastCall = time - (lastCallTime or 0)

    return not lastCallTime or timeSinceLastCall > wait or timeSinceLastCall < 0
  end

  local function trailingEdge(time)
    timer = nil
    return invokeFunc(time)
  end

  -- setTimout callback has been called
  local function timerExpired()
    local time = uv.now()
    if (shouldInvoke(time)) then
      return trailingEdge(time)
    end
    timer = M.setTimeout(timeRemaining(time), timerExpired)
  end

  -- leading edge handler
  local function leadingEdge(time)
    timer = M.setTimeout(wait, timerExpired)
    return leading and invokeFunc(time) or results
  end

  -- external function to call
  dbnc.debounced = function()
    local time = uv.now()
    -- returns true on first call to debounce
    -- otherwise checks if we are outside of our wait window
    local isInvoking = shouldInvoke(time)
    lastCallTime = time

    -- outside of the wait window and we do not yet have a timer ready
    if (isInvoking and not timer) then
      return leadingEdge(time)
    end

    -- create a timer if none already
    if (not timer) then
      timer = M.setTimeout(wait, timerExpired)
    end
  end

  -- cancel future invocations
  dbnc.cancel = function()
    if (timer) then M.clearTimeout(timer) end
    timer = nil
    lastCallTime = nil
  end

  -- immediately invoke function
  dbnc.flush = function()
    return timer and results or trailingEdge(uv.now())
  end

  setmetatable(dbnc, {
    __call = function() return dbnc.debounced() end
  })
  return dbnc
end

return M
