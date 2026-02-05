--!strict

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local PerformanceEnabled = false
local PerformanceData: { [string]: {
	calls: number,
	totalTime: number,
	peakTime: number,
	lastCall: number,
	source: string?,
} } = {}

local StepConnections: { [string]: RBXScriptConnection } = {}

local Util = {}

function Util.EnablePerformanceTracking(enabled: boolean)
	PerformanceEnabled = enabled
end

function Util.GetPerformanceData(): { [string]: {
	calls: number,
	totalTime: number,
	avgTime: number,
	peakTime: number,
	lastCall: number,
	source: string?,
} }
	local result = {}
	for name, data in PerformanceData do
		result[name] = {
			calls = data.calls,
			totalTime = data.totalTime,
			avgTime = if data.calls > 0 then data.totalTime / data.calls else 0,
			peakTime = data.peakTime,
			lastCall = data.lastCall,
			source = data.source,
		}
	end
	return result
end

function Util.ClearPerformanceData()
	table.clear(PerformanceData)
end

type PerformanceReportEntry = {
	name: string,
	data: {
		calls: number,
		totalTime: number,
		avgTime: number,
		peakTime: number,
		lastCall: number,
		source: string?,
	},
}

function Util.PrintPerformanceReport()
	local data = Util.GetPerformanceData()
	local sorted: { PerformanceReportEntry } = {}
	for name, entry in data do
		table.insert(sorted, { name = name, data = entry })
	end
	table.sort(sorted, function(a: PerformanceReportEntry, b: PerformanceReportEntry)
		return a.data.totalTime > b.data.totalTime
	end)

	print("=== Performance Report ===")
	for _, entry in sorted do
		print(string.format(
			"[%s] calls: %d | total: %.4fms | avg: %.4fms | peak: %.4fms",
			entry.name,
			entry.data.calls,
			entry.data.totalTime * 1000,
			entry.data.avgTime * 1000,
			entry.data.peakTime * 1000
		))
	end
	print("==========================")
end

local function TrackStart(_name: string): number
	if not PerformanceEnabled then
		return 0
	end
	return os.clock()
end

local function TrackEnd(name: string, startTime: number, source: string?)
	if not PerformanceEnabled then
		return
	end

	local elapsed = os.clock() - startTime
	local entry = PerformanceData[name]

	if not entry then
		entry = {
			calls = 0,
			totalTime = 0,
			peakTime = 0,
			lastCall = 0,
			source = source,
		}
		PerformanceData[name] = entry
	end

	entry.calls += 1
	entry.totalTime += elapsed
	entry.lastCall = os.clock()
	if elapsed > entry.peakTime then
		entry.peakTime = elapsed
	end
end

function Util.ForEach<K, V>(tbl: { [K]: V }, callback: (value: V, key: K) -> (), trackingName: string?)
	local name = trackingName or "ForEach"
	local startTime = TrackStart(name)

	for key, value in tbl do
		callback(value, key)
	end

	TrackEnd(name, startTime)
end

function Util.ForEachAsync<K, V>(tbl: { [K]: V }, callback: (value: V, key: K) -> (), trackingName: string?)
	local name = trackingName or "ForEachAsync"
	local startTime = TrackStart(name)

	for key, value in tbl do
		task.spawn(callback, value, key)
	end

	TrackEnd(name, startTime)
end

function Util.Map<K, V, R>(tbl: { [K]: V }, callback: (value: V, key: K) -> R, trackingName: string?): { [K]: R }
	local name = trackingName or "Map"
	local startTime = TrackStart(name)
	local result = {}

	for key, value in tbl do
		result[key] = callback(value, key)
	end

	TrackEnd(name, startTime)
	return result
end

function Util.Filter<K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?): { V }
	local name = trackingName or "Filter"
	local startTime = TrackStart(name)
	local result = {}

	for key, value in tbl do
		if predicate(value, key) then
			table.insert(result, value)
		end
	end

	TrackEnd(name, startTime)
	return result
end

function Util.Find<K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?): V?
	local name = trackingName or "Find"
	local startTime = TrackStart(name)

	for key, value in tbl do
		if predicate(value, key) then
			TrackEnd(name, startTime)
			return value
		end
	end

	TrackEnd(name, startTime)
	return nil
end

function Util.Step(name: string, callback: (dt: number) -> (), renderStepped: boolean?): RBXScriptConnection
	if StepConnections[name] then
		error(`Step '{name}' already exists. Call StopStep('{name}') first if you want to replace it.`)
	end

	local event = (if renderStepped and RunService:IsClient()
		then RunService.RenderStepped
		else RunService.Heartbeat) :: typeof(RunService.Heartbeat)

	local connection = event:Connect(function(dt)
		local startTime = TrackStart(`Step:{name}`)
		callback(dt)
		TrackEnd(`Step:{name}`, startTime, name)
	end)

	StepConnections[name] = connection
	return connection
end

function Util.StopStep(name: string)
	local connection = StepConnections[name]
	if connection then
		connection:Disconnect()
		StepConnections[name] = nil
	end
end

function Util.GetActiveSteps(): { string }
	local result = {}
	for name in StepConnections do
		table.insert(result, name)
	end
	return result
end

function Util.EstimateMemoryUsage(...: any): number
	local args = table.pack(...)
	local success, encoded = pcall(function()
		return HttpService:JSONEncode(args)
	end)

	if success then
		return #encoded
	end
	return 0
end

function Util.Defer<T...>(callback: (T...) -> (), ...: T...)
	task.defer(callback, ...)
end

function Util.Delay<T...>(duration: number, callback: (T...) -> (), ...: T...)
	task.delay(duration, callback, ...)
end

function Util.WaitFor<T>(predicate: () -> T?, timeout: number?, interval: number?): T?
	local timeoutTime = timeout or 10
	local checkInterval = interval or 0.1
	local startTime = os.clock()

	while os.clock() - startTime < timeoutTime do
		local result = predicate()
		if result then
			return result
		end
		task.wait(checkInterval)
	end

	return nil
end

function Util.Reduce<K, V, R>(tbl: { [K]: V }, reducer: (accumulator: R, value: V, key: K) -> R, initial: R, trackingName: string?): R
	local name = trackingName or "Reduce"
	local startTime = TrackStart(name)
	local result = initial

	for key, value in tbl do
		result = reducer(result, value, key)
	end

	TrackEnd(name, startTime)
	return result
end

function Util.Every<K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?): boolean
	local name = trackingName or "Every"
	local startTime = TrackStart(name)

	for key, value in tbl do
		if not predicate(value, key) then
			TrackEnd(name, startTime)
			return false
		end
	end

	TrackEnd(name, startTime)
	return true
end

function Util.Some<K, V>(tbl: { [K]: V }, predicate: (value: V, key: K) -> boolean, trackingName: string?): boolean
	local name = trackingName or "Some"
	local startTime = TrackStart(name)

	for key, value in tbl do
		if predicate(value, key) then
			TrackEnd(name, startTime)
			return true
		end
	end

	TrackEnd(name, startTime)
	return false
end

function Util.Reverse<V>(tbl: { V }): { V }
	local result = {}
	for i = #tbl, 1, -1 do
		table.insert(result, tbl[i])
	end
	return result
end

function Util.Shuffle<V>(tbl: { V }): { V }
	local result = table.clone(tbl)
	for i = #result, 2, -1 do
		local j = math.random(1, i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

function Util.Copy<K, V>(tbl: { [K]: V }, deep: boolean?): { [K]: V }
	if not deep then
		return table.clone(tbl)
	end
	local result: { [K]: V } = {}
	for key, value in tbl do
		if type(value) == "table" then
			result[key] = Util.Copy(value :: any, true) :: any
		else
			result[key] = value
		end
	end
	return result
end

function Util.Keys<K, V>(tbl: { [K]: V }): { K }
	local result: { K } = {}
	for key in tbl do
		table.insert(result, key)
	end
	return result
end

function Util.Values<K, V>(tbl: { [K]: V }): { V }
	local result: { V } = {}
	for _, value in tbl do
		table.insert(result, value)
	end
	return result
end

function Util.Count<K, V>(tbl: { [K]: V }): number
	local count = 0
	for _ in tbl do
		count += 1
	end
	return count
end

function Util.Flat<V>(tbl: { any }, depth: number?): { V }
	local maxDepth = depth or 1
	local result: { V } = {}

	local function flatten(arr: { any }, currentDepth: number)
		for _, value in arr do
			if type(value) == "table" and currentDepth < maxDepth then
				flatten(value, currentDepth + 1)
			else
				table.insert(result, value)
			end
		end
	end

	flatten(tbl, 0)
	return result
end

return Util
