# Octsock5 - high speed inter-process data interface #

## Motivation: ##
Serialization and data exchange over windows named pipes and TCP/IP between processes.
* Main audience: high-performance math-centric applications
* Typical use case: Need performance but don't want C-level linkage to Julia
  * e.g. may not risk SEGFAULTs in complex system
  * e.g. want clean "reset" of math system via restarting the Julia slave processes
  * e.g. want multiple, fully independent math processes
* Optimized for latency
* Optimized for throughput
* Designed largely for math-centric applications
* Supports any combination of number formats:
  * 8/16/32/64 bit integer
  * signed / unsigned integer
  * Float32 / Float64 (aka "single", "float", "double")
  * real or complex
  * scalar, 1d, 2d, 3d dense matrices
  * column/row vector as 1xn or nx1 matrix

## Sister project: ##
C# end: https://github.com/mnentwig/octsock5_cSharp

## Dependencies ##
None (tested with Julia 6 on Windows 10 / 64 bit)

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
E.g. 750 MBytes / second round-trip on a 2013 i7 4930 4500 MHz, 37 us round-trip for a single scalar

Curiously, the C# loopback server currently outperforms the Julia implementation by about 20 %. 

## Known bugs ##
No check for valid types

## Getting started ##
* Make ```Pkg.test("octsock5") ```work
* Run "julia test/main.jl client server" (that is, give both "client" and "server" as command line arguments).

## Hello world ##
The code below transmits and receives a single string to and from the loopback server (which must be running). See test/main.jl for more details.
```julia
iOs::octsock5_cl = octsock5_new(isServer=false, portNum=-12345); 
# Note: a server would need here an additional call to octsock5_accept(iOs)
octsock5_write(iOs, "Hello World");
res::String = octsock5_read(iOs); assert(res == "Hello World");
```
    
In principle, client and server can run in the same process. This doesn't make too much sense for a real-world application, but is convenient for testing.

## Thoughts ##
* Dynamic memory management is expensive. Reading inbound data into pre-allocated (/reused) memory might be considerably faster, e.g. overwrite older data.
* Type stability equals speed. Numeric array types and strings have an advantage over Tuples and Dictionaries, since they avoid "Any" type.
* A suspected performance bottleneck (compared to C#) is single-byte "memcpy" in Julia's io libraries.

## See also ##
Julia has built-in serialization, but the protocol is fairly complex and not guaranteed to remain stable between versions.
