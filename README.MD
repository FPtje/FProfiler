# Garry's mod profiler

A profiler based on `debug.sethook` and `SysTime`. Perfect for the following things:

- Finding performance bottlenecks (i.e. which code is spent the most time on)
- Finding out which functions are called most
- Identifying the source of lag spikes
- Profiling specific functions

This profiler distinguishes itself from [DBugR](https://github.com/oubliette32/DBugR) in its approach.
DBugR profiles at hooks, timers and net messages specifically. FProfiler looks purely at functions outside of their context.

I would recommend DBugR to measure networking and/or specific hooks and/or timers. I would recommend FProfiler for the things mentioned above.

## Using FProfiler
The `FProfiler` console command opens the profiler. Everything can be done from there.

Here's an explanation of the FProfiler menu:

UI thing | Description
------------ | -------------
Realm | Whether you're profiling the client or the server. Note: You need to be a SuperAdmin (or have the `FProfiler` permission in your favourite admin mod) to be allowed to do any serverside profiling!
(Re)start profiling | Starts a profiling session. If there is any previous profiling session, it starts anew, disregarding any old data.
Stop profiling | Stop an ongoing profiling session.
Continue profiling | Continue a profiling session that has previously been stopped. It will simply continue gathering data.
Profiling Focus | Focus the profiling on a specific function. Note: you **cannot** put arbitrary Lua in there, just function names! E.g. `player.GetAll` will work, but `hook.GetTable().Think.Cavity` will _not_.
Bottlenecks | Shows the functions that the game has spent its most time on. The top ones are the ones that hurt your FPS most.
Top n most expensive | Perfect for finding the cause of lag spikes. Lists the functions that took a long time on specific times they were called. Differs from the Bottlenecks tab in that Bottlenecks is about *all* the times the functions were called, this tab is about the single times they ran at their slowest.
Focus button | Sets the profiling focus to the selected function

## Using FProfiler in code

FProfiler has an API, a simple one too. All functions listed below are shared:
```lua
-- Starts profiling.
-- When focus is given, the profiler will only profile the focussed upon function, and the functions it calls
FProfiler.start([focus])

-- Stops profiling
FProfiler.stop()

-- Continue profiling
FProfiler.continueProfiling()
```

All the data of the profiling sessions can be seen in the `FProfiler` menu. Because of that, there need to be **no** data retrieving functions in the API.
If you don't want to use the UI, you *probably* want the profiling in a custom format. There are some internal functions available for that. Check out `lua/fprofiler/gather.lua` and `lua/fprofiler/report`.


## About bottlenecks

When faced with performance problems, people tend to dive in the code to perform micro-optimisations. Think of localising libraries to the scope of a file, storing `LocalPlayer()` in a variable for re-use and that kind of stuff. This is a naive approach and is unlikely to get you very far.
The reason for that is very simple: micro-optimisations have **very** little effect on the eventual performance of the game. They're called micro-optimisations for a reason.

What you *should* be after is macro-optimisations, i.e. the big guys. Attacking those will give you the biggest benefit. Doubling your FPS is not uncommon when you attack the big guys.

What do I mean by macro-optimisation/the big guys you ask? Think of reducing an O(n^2) algorithm to an O(n lg n) one. Think of things like using more efficient data structures, more efficient algorithms, caching the results of complicated calculations, alternative ways to calculate things that don't give the exact right result, but give a "good enough" result and are *way faster* than the original algorithm. **THAT** kind of shit.

That's where the profiler comes in. Always mistrust what you **think** is a big performance hog is, **measure** it. Even the assumptions of people who have optimising code as their profession are often proven wrong by the profiler. Don't be smug and think you can do any better.

When working on performance, the profiler is to be your guide. The profiler is to tell you what to optimise. Do not bother with anything other than the most expensive functions for you will be wasting your time.
