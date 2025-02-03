type Task = (() -> ()) | RBXScriptConnection | { Disconnect: () -> () } | { Destroy: () -> () } | Instance | Maid
export type Maid = {
	ClassName: "Maid",
	new: () -> Maid,
	isMaid: (value: any) -> boolean,
	GiveTask: (maid: Maid, task: Task) -> number,
	GiveTasks: (maid: Maid, tasks: { Task }) -> (),
	GivePromise: (maid: Maid, promise: any) -> any,
	DoCleaning: (maid: Maid) -> (),
	Destroy: (maid: Maid) -> (),
	Clean: (maid: Maid) -> (),

	_tasks: { [number]: Task },
}

---	Manages the cleaning of events and other things.
-- Useful for encapsulating state and make deconstructors easy
-- @classmod Maid
-- @see Signal

local Maid: Maid = {}
Maid.ClassName = "Maid"

--- Returns a new Maid object
-- @constructor Maid.new()
-- @treturn Maid
function Maid.new(): Maid
	return setmetatable({
		_tasks = {},
	}, Maid)
end

function Maid.isMaid(value: any): boolean
	return type(value) == "table" and value.ClassName == "Maid"
end

--- Returns Maid[key] if not part of Maid metatable
-- @return Maid[key] value
function Maid:__index(index)
	if Maid[index] then
		return Maid[index]
	else
		return self._tasks[index]
	end
end

--- Add a task to clean up. Tasks given to a maid will be cleaned when
--  maid[index] is set to a different value.
-- @usage
-- Maid[key] = (function)         Adds a task to perform
-- Maid[key] = (event connection) Manages an event connection
-- Maid[key] = (Maid)             Maids can act as an event connection, allowing a Maid to have other maids to clean up.
-- Maid[key] = (Object)           Maids can cleanup objects with a `Destroy` method
-- Maid[key] = nil                Removes a named task. If the task is an event, it is disconnected. If it is an object,
--                                it is destroyed.
function Maid:__newindex(index, newTask)
	if Maid[index] ~= nil then
		error(("'%s' is reserved"):format(tostring(index)), 2)
	end

	local tasks = self._tasks
	local oldTask = tasks[index]

	if oldTask == newTask then
		return
	end

	tasks[index] = newTask

	if oldTask then
		if type(oldTask) == "function" then
			oldTask()
		elseif typeof(oldTask) == "RBXScriptConnection" or (typeof(oldTask) == "table" and oldTask.Disconnect) then
			oldTask:Disconnect()
		elseif oldTask.Destroy then
			oldTask:Destroy()
		end
	end
end

--- Same as indexing, but uses an incremented number as a key.
-- @param task An item to clean
-- @treturn number taskId
function Maid:GiveTask(task: Task): number
	if not task then
		error("Task cannot be false or nil", 2)
	end

	local taskId = #self._tasks + 1
	self[taskId] = task

	if type(task) == "table" and not task.Destroy and not task.Disconnect then
		warn("[Maid.GiveTask] - Gave table task without .Destroy\n\n" .. debug.traceback())
	end

	return taskId
end

function Maid:GiveTasks(tasks: { Task })
	for _, task in tasks do
		self:GiveTask(task)
	end
end

function Maid:GivePromise(promise: {}): {}
	if not promise:IsPending() then
		return promise
	end

	local newPromise = promise.resolved(promise)
	local id = self:GiveTask(newPromise)

	-- Ensure GC
	newPromise:Finally(function()
		self[id] = nil
	end)

	return newPromise
end

--- Cleans up all tasks.
-- @alias Destroy
function Maid:DoCleaning()
	local tasks = self._tasks

	-- Disconnect all events first as we know this is safe
	for index, oldTask in pairs(tasks) do
		if typeof(oldTask) == "RBXScriptConnection" or (typeof(oldTask) == "table" and oldTask.Disconnect) then
			tasks[index] = nil
			oldTask:Disconnect()
		end
	end

	-- Clear out tasks table completely, even if clean up tasks add more tasks to the maid
	local index, oldTask = next(tasks)
	while oldTask ~= nil do
		tasks[index] = nil
		if type(oldTask) == "function" then
			oldTask()
		elseif typeof(oldTask) == "RBXScriptConnection" or (typeof(oldTask) == "table" and oldTask.Disconnect) then
			oldTask:Disconnect()
		elseif oldTask.Destroy then
			oldTask:Destroy()
		end
		index, oldTask = next(tasks)
	end
end

--- Alias for DoCleaning()
-- @function Destroy
Maid.Destroy = Maid.DoCleaning
Maid.Clean = Maid.DoCleaning

return Maid
