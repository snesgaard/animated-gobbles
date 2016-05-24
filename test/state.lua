require "state_engine"
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

state_engine.set(1, master)
state_engine.update()
signal.send("tick")
signal.send("tock")
state_engine.set(1, master)
state_engine.update()
signal.send("tock")
