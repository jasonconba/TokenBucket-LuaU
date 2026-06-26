--!strict

type UserId = number

type Bucket = {
	tokens: number,
	last: number,
}

type TokenBucketT = {
	capacity: number,
	refillPerSecond: number,
	buckets: { [UserId]: Bucket },

	allow: (self: TokenBucketT, userId: UserId) -> boolean,
}

local TokenBucket = {}
TokenBucket.__index = TokenBucket

--- Creates a limiter that allows at most `capacity` events, refilling back to
--- full at a rate of `capacity / windowSeconds` tokens per second.
--- @param capacity -- The maximum number of events allowed in the window.
--- @param windowSeconds -- The duration of the window in seconds.
--- @return A new TokenBucket limiter.
function TokenBucket.new(capacity: number, windowSeconds: number): TokenBucketT
	assert(capacity >= 1, "capacity must be >= 1")
	assert(windowSeconds > 0, "windowSeconds must be > 0")

	local self = {
		capacity = capacity,
		refillPerSecond = capacity / windowSeconds,
		buckets = {},
	}
	return (setmetatable(self, TokenBucket) :: any) :: TokenBucketT
end

--- Refills the bucket with tokens based on the elapsed time since the last refill.
--- @param b -- The bucket to refill.
--- @param now -- The current time in seconds.
--- @param cap -- The maximum number of tokens the bucket can hold.
--- @param rate -- The rate at which tokens are refilled per second.
local function refill(b: Bucket, now: number, cap: number, rate: number)
	local elapsed = now - b.last
	if elapsed > 0 then
		b.tokens = math.min(cap, b.tokens + elapsed * rate)
		b.last = now
	end
end

--- Whether the user is allowed to perform an action.
--- @param userId UserId
--- @return true if the user is allowed to perform an action, false otherwise.
function TokenBucket:allow(userId: UserId): boolean
	local now = time()
	local b = self.buckets[userId] :: Bucket
	if not b then
		b = { tokens = self.capacity, last = now }
		self.buckets[userId] = b
	else
		refill(b, now, self.capacity, self.refillPerSecond)
	end

	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

return TokenBucket
