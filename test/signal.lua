function slave2()
  signal.wait("tock")
  error("should be dead")
end
function slave()
  signal.wait("tock")
  concurrent.fork(slave2)
  signal.wait("tock")
  error("should be dead")
end
function master()
  signal.wait("tick")
  concurrent.fork(slave)
  return master()
end

local co = concurrent.detach(master)
signal.send("tick")
signal.send("tock")
concurrent.join(co)
signal.send("tock")
