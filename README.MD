# Garry's mod profiler

A profiler based on `debug.sethook` and `SysTime`. Perfect for the following things:

- Finding performance bottlenecks (i.e. which code is spent the most time on)
- Finding out which functions are called most
- Identifying the source of lag spikes
- Profiling specific functions

This profiler distinguishes itself from [DBugR](https://github.com/oubliette32/DBugR) in its approach.
DBugR profiles at hooks, timers and net messages specifically. FProfiler looks purely at functions outside of their context.

I would recommend DBugR to measure networking and/or specific hooks and/or timers. I would recommend FProfiler for the things mentioned above.


## About bottlenecks

When faced with performance problems, people tend to dive in the code to perform micro-optimisations. Think of localising libraries to the scope of a file, storing `LocalPlayer()` in a variable for re-use and that kind of stuff. This is a naive approach and is unlikely to get you very far.
The reason for that is very simple: micro-optimisations have **very** little effect on the eventual performance of the game. They're called micro-optimisations for a reason.

What you *should* be after is macro-optimisations, i.e. the big guys. Attacking those will give you the biggest benefit. Doubling your FPS is not uncommon when you attack the big guys.

What do I mean by macro-optimisation/the big guys you ask? Think of reducing an O(n^2) algorithm to an O(n lg n) one. Think of things like using more efficient data structures, more efficient algorithms, caching the results of complicated calculations, alternative ways to calculate things that don't give the exact right result, but give a "good enough" result and are *way faster* than the original algorithm. **THAT** kind of shit.

That's where the profiler comes in. Always mistrust what you **think** is a big performance hog is, **measure** it. Even the assumptions of people who have optimising code as their profession are often proven wrong by the profiler. Don't be smug and think you can do any better.

When working on performance, the profiler is to be your guide. The profiler is to tell you what to optimise. Do not bother with anything other than the most expensive functions for you wil be wasting your time.
