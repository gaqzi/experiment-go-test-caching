# An experiment to understand when Go will cache tests

I was adding Go's build cache into a persistant cache for CI and a colleague realized we might get some false-positive tests for our black box integration tests because they don't "declare their dependencies" for the compiler, they run as network services, and we wanted  to understand how we could make our BB integration tests ensure they always get run and never get cached, due to it.

When reading `go help test` I saw that the tests will not cache if an environment variable used in the test has changed. So I wanted to understand how that happens, and what the scope of the cache was.

My conclusion from the experiment and reading code:

- Go runs tests per package, and packages in parallel, so if any test in the package relies on an environment variable and it changes, it invalidates the cache for all tests in that package
- This does not extend to subpackages
- If a library uses an environment variable and it's called through the test it's caught
  - This is not surprising because Go hooks into the `os.Getenv` call and logs each variable there, but I wanted it positively confirmed

I made a script, [test.sh], that runs my test scenarios:
- SETUP: empty logs and clear testcache

The numbers below are the test runs:
1. DRONE_COMMIT_SHA is empty: no cached packages
2. DRONE_COMMIT_SHA is empty: 3 cached packages
3. DRONE_COMMIT_SHA=1: 1 cached package that doesn't rely on the env var
4. DRONE_COMMIT_SHA=1: 3 cached packages

---

Raw notes of my research and how I ended up here:

- Any test that relies on environment variables will only cache if the variables are the same, so we got to wondering whether we could use the DRONE_SHA (or whatever equivalent for the current HEAD), because then we would have a unique var and not have to worry.
    - I'll do an experiment for this and see if we could add something into test-kit to get this benefit, I will start by looking at how the tests are setup with [[test-kit]] to see that, and then I'll do a test repo (👋) and try some approaches
    - https://github.com/golang/go/issues/24589 seems to show a bug around this, so maybe I can find the code for how it works there…
        - https://news.ycombinator.com/item?id=16398488 for a link to a commit for file based
        - https://github.com/golang/go/blob/master/src/internal/testlog/log.go
        - basically, every time you look up env vars and open files there’s an overhead to log it, so there’s an extra if in those lookups to support testing, neat!
        - if you have TestMain then testing/internal/testdeps will be smart enough [to not set the logger multiple times.](https://github.com/golang/go/blob/a85b8810c49515c469d265c399febfa48442a983/src/testing/internal/testdeps/deps.go#L111)
        - Then we use the testlog file and write it to a special place for the go command, through a flag: https://github.com/golang/go/blob/665af869920432879629c1d64cf59f129942dcd6/src/cmd/go/internal/test/test.go#L1547
    - Okay, time check: I don't need to fully understand how it works right now, I do want to share this later, but I can research it further after I have proven the ideas.
        - Most likely, what will make sense is that it only checks if the variable is used __at all__, so it shouldn't matter which test? Because it seems it doesn't know which test used the variable (which makes sense, that's complicated).

          https://github.com/golang/go/blob/a85b8810c49515c469d265c399febfa48442a983/src/testing/internal/testdeps/deps.go#L91-L107 doesn't say anything of context.
        - Invalidates when:
            - New test in package: YES
                - implies: modified test in package
            - ENV Var changes then in package changes: YES
                - Even tests that don't use the variable: YES
            - Test in sub-package: NO
                - The other package is invalidated, so the cache is on the package level
            - External module used in sub-package without reading var: YES
                - The module uses the env var but it's not immediately visible
        - I want to make a single script that runs these scenarios so I can validate that it works as expected
          - [test.sh]

[test.sh]: ./test.sh
