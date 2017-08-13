# Octsock5 - high speed inter-process data interface #

## Motivation: ##
Serialization and data exchange over windows named pipes and TCP/IP between processes.
Intended for high-performance application (latency and throughput) supporting a subset of data structures

## Supported data types ##
* Signed/Unsigned Integer 8/16/32/64 bit
* 32/64 bit float
* Real, complex
* +/-Inf, NaN
* numeric arrays 1, 2, 3-dimensional
* Tuples (Any type)
* Dictionaries (Any type / Any type)
* Strings

## Automatic conversion ##
* RowVector
* UnitRange
* LinSpace
* StepRangeLen

are converted into equivalent Arrays

## API ##
```julia
* function octsock5_new(;isServer::Bool=false, portNum::Int64=-1)
```
Creates octsock5_cl object as server/client using windows named pipes (negative portNum) or TCP/IP (positive)

```julia
* function octsock5_accept(self::octsock5_cl)
```

Starts the server (Note, the client may connect already once the server's "octsock5_new" has returned)

```julia
* function octsock5_delete(self::octsock5_cl)
```

Closes the server/client

```julia
* function octsock5_write(self::octsock5_cl, arg)
```

Sends "arg"

```julia
* function octsock5_read(self::octsock5_cl)
```

Returns the next argument to "octsock5_write" on the remote end

## Performance ##
E.g. 1800 MBytes / second round-trip on 4.5G i4930 (with large array), 10 us round-trip for a single scalar

## Known bugs ##
No check for valid types

## Getting started ##
* Make ```Pkg.test("octsock5") ```work
* Run "julia test/main.jl client server" (that is, give both "client" and "server" as command line arguments).

When doing so, the below lines in test/main.jl demonstrate transmission of a single string:
```julia
if (iOsSrv != Void) octsock5_write(iOsSrv, "Hello World"); end
if (iOsClt != Void) res::String = octsock5_read(iOsClt); assert(res == "Hello World"); end
```
    
Note, client and server can run in the same process. This doesn't make too much sense for a real-world application, but is convenient for testing.

## Thoughts ##
* Dynamic memory allocation is expensive. Reading inbound data into pre-allocated (/reused) memory might be considerably faster, e.g. overwrite older data.
* Type stability equals speed. Numeric array types and strings have an advantage over Tuples and Dictionaries, since they avoid "Any" type.
