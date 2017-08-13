# Octsock5 - high speed inter-process data interface #

## Motivation: ##
Serialization and data exchange over windows named pipes and TCP/IP between processes.
Intended for high-performance application (latency and throughput) supporting a subset of data structures

## Supported data types ##
* Signed/Unsigned Integer 8/16/32/64 bit
* 32/64 bit float
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
* function octsock5_new(;isServer::Bool=false, portNum::Int64=-1)

Creates octsock5_cl object as server/client using windows named pipes (negative portNum) or TCP/IP (positive)

* function octsock5_accept(self::octsock5_cl)

Starts the server (Note, the client may connect already once the server's "octsock5_new" has returned)

* function octsock5_delete(self::octsock5_cl)

Closes the server/client

* function octsock5_write(self::octsock5_cl, arg)

Sends "arg"

* function octsock5_read(self::octsock5_cl)

Returns the next argument to "octsock5_write" on the remote end

