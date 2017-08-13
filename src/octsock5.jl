# octSock5
# Copyright (c) 2017, Markus Nentwig
# All rights reserved.
module octsock5

export octsock5_cl, octsock5_new, octsock5_accept, octsock5_write, octsock5_read, octsock5_delete;

__precompile__() 

# profiling note: global "const" refers to the type, not the value.
# A macro provides the compiler with a literal instead of a variable.
macro H0_FLOAT() 	return Int64(0x00000001); end
macro H0_INTEGER() 	return Int64(0x00000002); end
macro H0_SIGNED() 	return Int64(0x00000004); end
macro H0_COMPLEX() 	return Int64(0x00000008); end
macro H0_ARRAY() 	return Int64(0x00000010); end
macro H0_TUPLE() 	return Int64(0x00000020); end
macro H0_STRING() 	return Int64(0x00000040); end
macro H0_DICT() 	return Int64(0x00000080); end
macro H0_TERM() 	return Int64(0x00000100); end
macro HEADERTYPE() 	return Int64; end
macro HEADERLEN()	return 6; end

# unique number that identifies each scalar / array / complex / number type combination
function TYPEID(H0::Int64, nBytes::Int64) 
    return (H0 + (nBytes << 16))::Int64;
end

type octsock5_cl
    header::Array{@HEADERTYPE};
    headerSize::UInt64;
    stringMem::Array{UInt8};
    stringMemSize::UInt64;    
    stringMemPtr::Ptr{UInt8};
    server::Any;
    io::IO;
    octsock5_cl() = (x = new());
end

function octsock5_new(;isServer::Bool=false, portNum::Int64=-1)
    self::octsock5_cl = octsock5_cl(); 
    self.header = Array{@HEADERTYPE}(@HEADERLEN);
    self.headerSize = sizeof(self.header);
    # pre-allocate initial memory for inbound strings
    self.stringMemSize = 1000;
    self.stringMem = Array{UInt8}(self.stringMemSize);
    self.stringMemPtr = pointer(self.stringMem);
    
    if (portNum < 0)
        # === Windows named pipes ===
        # default implementation. Use this.
        if (false == is_windows())
            error("named pipes are windows-OS specific, others must use TCP/IP ports");
        end
        conn::Any = string("\\\\.\\pipe\\octsock5_", @sprintf("%i", portNum));
    else
        # === TCP/IP ===
        # TBD support connection to another host
        # on localhost, expect 2x latency, 1/3 throughput relative to windows named pipes.
        conn = portNum;
    end
    
    if isServer        
        self.server = listen(conn);
    else
        self.server = Void;
        self.io = connect(conn); # TBD: Could connect to another host here.
    end
    # auto-close if object is abandoned or on shutdown
    finalizer(self, octsock5_delete);
        
    return self;
end

# octsock5_accept is split from octsock5_new, because the client can only start when the server is up
# but accept is a blocking function
# server: octsock5_new, acknowledge
# client: octsock5_new
# server: octsock5_accept
function octsock5_accept(self::octsock5_cl)
    if (self.server == Void)
        error("not in server mode");
    end
    self.io = accept(self.server);    
end

function octsock5_delete(self::octsock5_cl)
    try 
        close(self.io);
    catch end
    nothing;
end

function writeHeader(self::octsock5_cl)
    unsafe_write(self.io, Ref(self.header), (@HEADERLEN)*sizeof(@HEADERTYPE));
    nothing; 
end

function writePointer(self::octsock5_cl, ptr::Ptr{Void}, len::UInt64)
    unsafe_write(self.io, ptr, len);
    nothing; 
end

function writeScalar{T}(self::octsock5_cl, arg::T)
    unsafe_write(self.io, Ref{T}(arg), sizeof(T));
    nothing;
end

function octsock5_write(self::octsock5_cl, arg::Dict)
    self.header[1] = @H0_DICT;
    writeHeader(self);
    
    for item::Pair in arg
        # === write key ===
        octsock5_write(self, item[1]);
        # === write value ===
        octsock5_write(self, item[2]);
    end
    
    self.header[1] = @H0_TERM;
    writeHeader(self);
    nothing;
end

function octsock5_write(self::octsock5_cl, arg::Tuple)
    tupLen::UInt64 = length(arg);
    
    self.header[1] = @H0_TUPLE;
    self.header[2] = tupLen;
    writeHeader(self);
    
    for ix::UInt64 = 1:tupLen
        octsock5_write(self, arg[ix]);
    end
    nothing;
end

function octsock5_write(self::octsock5_cl, arg::String)
    len::UInt64 = length(arg);
    self.header[1] = @H0_STRING;
    self.header[2] = len;        
    writeHeader(self);
    writePointer(self, Ptr{Void}(pointer(arg)), len);
    nothing;
end

function octsock5_write(self::octsock5_cl, arg::T) where T <: Union{RowVector, UnitRange, LinSpace, StepRangeLen}
    octsock5_write(self, Array(arg));
    nothing;
end

function octsock5_write{T}(self::octsock5_cl, arg::Array{T})
    H0::Int64 = (T <: Complex) 		? (@H0_ARRAY) | (@H0_COMPLEX) 	: (@H0_ARRAY);
    H0 |= (real(T) <: AbstractFloat) 	? (@H0_FLOAT) 			: 0;
    H0 |= (real(T) <: Integer) 		? (@H0_INTEGER) 		: 0;
    H0 |= (real(T) <: Signed) 		? (@H0_SIGNED) 			: 0;

    nd::Int64 = ndims(arg); 
    nBytes::UInt64 = sizeof(T); 
    self.header[1] = H0;
    self.header[2] = nBytes;
    self.header[3] = nd;
    
    for dim = 1 : nd
        self.header[3+dim] = size(arg, dim);
    end

    writeHeader(self);
    writePointer(self, Ptr{Void}(pointer(arg)), UInt64(sizeof(arg)));
    nothing;
end

function octsock5_write{T}(self::octsock5_cl, arg::T)
    H0::Int64 = (T <: Complex) 		? (@H0_COMPLEX) : 0;
    H0 |= (real(T) <: AbstractFloat)	? (@H0_FLOAT) 	: 0;
    H0 |= (real(T) <: Integer) 		? (@H0_INTEGER) : 0;
    H0 |= (real(T) <: Signed) 		? (@H0_SIGNED) 	: 0;
    nBytes::UInt64 = sizeof(T); 
    self.header[1] = H0;
    self.header[2] = nBytes;
    self.header[3] = 1;
    
    writeHeader(self);
    writeScalar(self, arg);
    nothing;
end

function readScalar{T}(self::octsock5_cl, dummy::T)
    r::Ref{T} = Ref{T}(dummy);
    p::Ptr{T} = Base.unsafe_convert(Ptr{T}, r);
    
    unsafe_read(self.io, p, sizeof(dummy));
    return r.x::T;
end

function readArray{T}(self::octsock5_cl, dummy::T)
    H3::Int64 = self.header[3];
    H4::Int64 = self.header[4];
    H5::Int64 = self.header[5];
    H6::Int64 = self.header[6];
    if (H3 == 1)
        obj::Array{T} = Array{T, 1}(H4);
        nElem::UInt64 = H4;
        p1::Ptr{Void} = pointer(obj);
    elseif (H3 == 2)
        obj = Array{T, 2}(H4, H5);
        nElem = H4*H5;
        p1 = pointer(obj);
    elseif (H3 == 3)
        obj = Array{T, 3}(H4, H5, H6);
        nElem = H4*H5*H6;
        p1 = pointer(obj);
    else
        error("invalid number of dimensions");
    end       
    
    nBytes::UInt64 = sizeof(T) * nElem;

    unsafe_read(self.io, p1, nBytes);
    return obj; 
end

function octsock5_read(self::octsock5_cl)
    headerSize::UInt64 = self.headerSize; # remove this
    
    # === read header ===
    unsafe_read(self.io, Ref(self.header), headerSize);
    H0::Int64 = self.header[1];
    
    if ((H0 & @H0_TERM) != 0)
        return Void;
    end
    
    # === handle tuples ===
    if ((H0 & @H0_TUPLE) != 0)
        local nElemTuple::UInt64 = self.header[2];
        local objTuple::Array{Any} = Array{Any}(nElemTuple);
        for ix::UInt64 = 1:nElemTuple
            objTuple[ix] = octsock5_read(self);
        end
        return Tuple(objTuple);
    end

    # === handle string ===
    if ((H0 & @H0_STRING) != 0)        
        nBytesStr::Int64 = self.header[2];
        # allocate memory
        if self.stringMemSize < nBytesStr
            self.stringMemSize = nBytesStr;
            self.stringMem = Array{UInt8}(self.stringMemSize);
            self.stringMemPtr = pointer(self.stringMem);
        end
        unsafe_read(self.io, self.stringMemPtr, nBytesStr);
        return unsafe_string(self.stringMemPtr, nBytesStr);
    end

    # === handle Dict ===
    if ((H0 & @H0_DICT) != 0)
        local objDict::Dict = Dict();
        while true
            key = octsock5_read(self);
            if (key == Void)
                return objDict;
            end
            objDict[key] = octsock5_read(self);
        end
    end

    nElemBytes::Int64 = self.header[2];
    isComplex::Bool = ((H0 & @H0_COMPLEX) != 0);
    isSigned::Bool = ((H0 & @H0_SIGNED) != 0);
    tId::UInt64 = TYPEID(H0, self.header[2]);
    if ((H0 & @H0_ARRAY) == 0)
        # === handle array ===
        if ((H0 & @H0_COMPLEX) != 0)        
            if (nElemBytes == 2)
                if 	(tId == TYPEID((@H0_INTEGER) | (@H0_COMPLEX), 2)) return readScalar(self, Complex{UInt8}(0));
                elseif	(tId == TYPEID((@H0_INTEGER) | (@H0_COMPLEX) | (@H0_SIGNED), 2)) return readScalar(self, Complex{Int8}(0));
                else error(); end
            elseif (nElemBytes == 4)
                if 	(tId == TYPEID((@H0_INTEGER) | (@H0_COMPLEX), 4)) return readScalar(self, Complex{UInt16}(0));
                elseif 	(tId == TYPEID((@H0_INTEGER) | (@H0_COMPLEX) | (@H0_SIGNED), 4)) return readScalar(self, Complex{Int16}(0));
                else error(); end            
            elseif (nElemBytes == 8)
                if 	(tId == TYPEID((@H0_FLOAT)   | (@H0_COMPLEX), 8)) return readScalar(self, Complex{Float32}(0));
                elseif 	(tId == TYPEID((@H0_INTEGER) | (@H0_COMPLEX), 8)) return readScalar(self, Complex{UInt32}(0));
                elseif 	(tId == TYPEID((@H0_INTEGER) | (@H0_COMPLEX) | (@H0_SIGNED), 8)) return readScalar(self, Complex{Int32}(0));
                else error(); end
            elseif (nElemBytes == 16)
                if 	(tId == TYPEID((@H0_COMPLEX) | (@H0_FLOAT), 16)) return readScalar(self, Complex{Float64}(0));                
                elseif 	(tId == TYPEID((@H0_COMPLEX) | (@H0_INTEGER), 16)) return readScalar(self, Complex{UInt64}(0));
                elseif 	(tId == TYPEID((@H0_COMPLEX) | (@H0_INTEGER) | (@H0_SIGNED), 16)) return readScalar(self, Complex{Int64}(0));
                else error() end
            else error(); end
        else
            if (nElemBytes == 1)
                if 	(tId == TYPEID((@H0_INTEGER), 1)) return readScalar(self, UInt8(0));
                elseif	(tId == TYPEID((@H0_INTEGER) | (@H0_SIGNED), 1)) return readScalar(self, Int8(0));
                else error(); end
            elseif (nElemBytes == 2)
                if 	(tId == TYPEID((@H0_INTEGER), 2)) return readScalar(self, UInt16(0));
                elseif 	(tId == TYPEID((@H0_INTEGER) | (@H0_SIGNED), 2)) return readScalar(self, Int16(0));
                else error(); end            
            elseif (nElemBytes == 4)
                if 	(tId == TYPEID((@H0_FLOAT), 4)) return readScalar(self, Float32(0));
                elseif 	(tId == TYPEID((@H0_INTEGER), 4)) return readScalar(self, UInt32(0));
                elseif 	(tId == TYPEID((@H0_INTEGER) | (@H0_SIGNED), 4)) return readScalar(self, Int32(0));
                else error(); end
            elseif (nElemBytes == 8)
                if 	(tId == TYPEID((@H0_FLOAT), 8)) return readScalar(self, Float64(0));                
                elseif 	(tId == TYPEID((@H0_INTEGER), 8)) return readScalar(self, UInt64(0));
                elseif 	(tId == TYPEID((@H0_INTEGER) | (@H0_SIGNED), 8)) return readScalar(self, Int64(0));
                else error(); end
            else error(); end
        end
    else 
        # === handle scalar ===
        if ((H0 & @H0_COMPLEX) != 0)        
            if (nElemBytes == 2)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_COMPLEX), 2)) return readArray(self, Complex{UInt8}(0));
                elseif	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_COMPLEX) | (@H0_SIGNED), 2)) return readArray(self, Complex{Int8}(0));
                else error(H0);
                end
            elseif (nElemBytes == 4)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_COMPLEX), 4)) return readArray(self, Complex{UInt16}(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_COMPLEX) | (@H0_SIGNED), 4)) return readArray(self, Complex{Int16}(0));
                else error() end            
            elseif (nElemBytes == 8)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_FLOAT)   | (@H0_COMPLEX), 8)) return readArray(self, Complex{Float32}(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_COMPLEX), 8)) return readArray(self, Complex{UInt32}(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_COMPLEX) | (@H0_SIGNED), 8)) return readArray(self, Complex{Int32}(0));
                else error() end
            elseif (nElemBytes == 16)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_COMPLEX) | (@H0_FLOAT), 16)) return readArray(self, Complex{Float64}(0));                
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_COMPLEX) | (@H0_INTEGER), 16)) return readArray(self, Complex{UInt64}(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_COMPLEX) | (@H0_INTEGER) | (@H0_SIGNED), 16)) return readArray(self, Complex{Int64}(0));
                else error() end
            else error(); end
        else
            if (nElemBytes == 1)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER), 1)) return readArray(self, UInt8(0));
                elseif	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_SIGNED), 1)) return readArray(self, Int8(0));
                else error();
                end
            elseif (nElemBytes == 2)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER), 2)) return readArray(self, UInt16(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_SIGNED), 2)) return readArray(self, Int16(0));
                else error() end            
            elseif (nElemBytes == 4)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_FLOAT), 4)) return readArray(self, Float32(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER), 4)) return readArray(self, UInt32(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_SIGNED), 4)) return readArray(self, Int32(0));
                else error() end
            elseif (nElemBytes == 8)
                if 	(tId == TYPEID((@H0_ARRAY) | (@H0_FLOAT), 8)) return readArray(self, Float64(0));                
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER), 8)) return readArray(self, UInt64(0));
                elseif 	(tId == TYPEID((@H0_ARRAY) | (@H0_INTEGER) | (@H0_SIGNED), 8)) return readArray(self, Int64(0));
                else error() end
            else error(); end
        end
end
end
end # module
