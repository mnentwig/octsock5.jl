# Purpose of this file: 
# Command-line driven test case for octsock5 high-speed data interface
# Usually, this will be run as two independent processes for server / client 

using octsock5;

function measureRoundtripTime(iOsSrv, iOsClt)
    t::UInt64 = time_ns();
    nRuns::UInt64 = 300000;
    for ix = 1 : nRuns
        if (iOsSrv != Void) octsock5_write(iOsSrv, ix, true); end
        if (iOsClt != Void) obj = octsock5_read(iOsClt); end
    end
    
    t = time_ns() - t;
    print("Average roundtrip time ", @sprintf("%1.3f", Float64(t)/1e6/Float64(nRuns)), " ms. Reference system: 0.009 ms\n");
end

function measureThroughput(iOsSrv, iOsClt)
    t::UInt64 = time_ns();
    nRuns::UInt64 = 20000;

    m = Array{Float64}(rand(20, 20, 20));
    for ix = 1 : nRuns
        if (iOsSrv != Void) octsock5_write(iOsSrv, m, true); end
        if (iOsClt != Void) obj = octsock5_read(iOsClt); end
    end
    
    t_s = Float64(time_ns() - t)/1e9;
    print("Average throughput ", @sprintf("%1.1f", Float64(nRuns*sizeof(m)/2^20)/t_s), " MBytes (2^20) per second. Reference system: 1800 TBD Pkg.test() seems to give lower performance. Find out, why\n");
end

function testAllTypes(iOsSrv, iOsClt, nRuns::Int, profiling::Bool)
    # === build data ===
    arg0 = sin.(1.1:10.1);
    arg0f = Array{Float32}(arg0);
    v_UInt8 = Array{UInt8}(0:127);
    v_Int8 = Array{Int8}(0:127);
    v_UInt16 = Array{UInt16}(0:127);
    v_Int16 = Array{Int16}(0:127);
    v_UInt32 = Array{UInt32}(0:127);
    v_Int32 = Array{Int32}(0:127);
    v_UInt64 = Array{UInt64}(0:127);
    v_Int64 = Array{Int64}(0:127);
    m_2 = Array{Float64}(rand(3, 3));
    m_3 = Array{Float64}(rand(3, 3, 3));
    d = Dict();
    d[1] = "two";
    d["three"] = 4;
    
    # === run tests ===
    arg = Void;
    for v = 0 : nRuns-1
        vv = v+13;
        
        vec = [mod(v, 127)+im*mod(v, 126), 
               mod(v, 125)+im*mod(v, 124),
               mod(v, 123)+im*mod(v, 122), ];
        if arg == Void
            arg = (
                # UInt, Int, float scalar
                UInt8(mod(v, 256)), 
                UInt16(mod(v, 65536)), 
                UInt32(v),
                UInt64(v),
                Int8(mod(v, 256)-128), 
                Int16(mod(v, 65536)-32768), 
                Int32(v),
                Int64(v),
                Float32(1.01*v),
                Float64(1.01*v), 
                
                # UInt, Int, float scalar complex
                UInt8(mod(v, 256))+im*UInt8(mod(vv, 256)), 
                UInt16(mod(v, 65536))+im*UInt16(mod(vv, 65536)), 
                UInt32(v)+im*UInt32(vv),
                UInt64(v)+im*UInt64(vv),
                Int8(mod(v, 256)-128)+im*Int8(mod(vv, 256)-128), 
                Int16(mod(v, 65536)-32768)+im*Int16(mod(vv, 65536)-32768), 
                Int32(v)+im*Int32(v),
                Int64(v)+im*Int64(v),
                Float32(1.01*v)+im*Float32(1.02*vv),
                Float64(1.01*v)+im*Float64(1.02*vv), 
                
                # UInt, int, float Array
                v_UInt8, v_Int8,
                v_UInt16, v_Int16,
                v_UInt32, v_Int32,
                v_UInt64, v_Int64,
                arg0, arg0f,            
                
                # complex vector
                Array{Complex{UInt8}}(vec),
                Array{Complex{UInt16}}(vec),
                Array{Complex{UInt32}}(vec),
                Array{Complex{UInt64}}(vec),
                Array{Complex{Int8}}(vec),
                Array{Complex{Int16}}(vec),
                Array{Complex{Int32}}(vec),
                Array{Complex{Int64}}(vec),
                
                # n-d matrix
                m_2, m_3,
                
                # complex matrix
                m_2-2.5*im*m_2, m_3-2.5*im*m_3,
                
                # string
                "Hello world. The quick brown fox jumps over the lazy dog. This sentence no verb. Lorem Ipsum!",
                
                # Dict
                d,
            );

            #arg = Array{Complex{UInt64}}(1:3)
            #arg = Array{Complex{Float64}}(rand(3)+1im*rand(3))
            #arg = Array{Complex{UInt64}}(floor.((2.^50)*rand(10000)) + 1im*floor.((2.^50)*rand(10000)));
        end
        
        if (iOsSrv != Void) octsock5_write(iOsSrv, arg, true); end
        if (iOsClt != Void) 
            obj = octsock5_read(iOsClt);
            if (profiling == false)
                if (obj != arg)                     
                    print("reference:", arg, "\n");
                    print("received:", obj, "\n");
                    error("verify fail"); 
                end
            end
        end
        #if profiling == false && (mod(v, 1000) == 0) print(v, "\n"); end
        if profiling == false
            arg = Void;
        end
    end
    if (!profiling)
        print("no errors detected");
    end
end

function main()
    srand(0);

    # === parse arguments ===
    iOsSrv = Void;
    iOsClt = Void;
    
    args::Dict{String, Bool} = Dict(
        "server" => false, 
        "client" => false, 
        "roundtrip" => false, 
        "throughput" => false,
        "profiling" => false, 
        "alltypes" => false, 
        "tcpip" => false);
    
    for arg::String in ARGS
        if haskey(args, arg)
            args[arg] = true;
        else
            error("invalid command line argument '" * arg * "'");
        end
    end

    # negative port number: Use Windows named pipes 
    portNum::Int64 = args["tcpip"] ? 2000 : -12345

    # === start link ===
    begin
        if (args["server"])
            iOsSrv = octsock5_new(isServer=true, portNum=portNum);
            print("SERVER_READY\n");
        end
        if (args["client"])
            iOsClt = octsock5_new(isServer=false, portNum=portNum);
        end
        if (args["server"])
            octsock5_accept(iOsSrv);
        end
    end
    
    # === run code once to remove startup time from benchmarks ===
    if (iOsSrv != Void) octsock5_write(iOsSrv, "Hello World", true); end
    if (iOsClt != Void) octsock5_read(iOsClt); end
    
    # === run tests ===
    if (args["roundtrip"])
        measureRoundtripTime(iOsSrv, iOsClt);
    end
    if (args["throughput"])
        measureThroughput(iOsSrv, iOsClt);
    end
    if (args["alltypes"])
        testAllTypes(iOsSrv, iOsClt, 10000, args["profiling"]);
    end
end
main()
