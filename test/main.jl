# Purpose of this file: 
# Command-line driven test case for octsock5 high-speed data interface
# Usually, this will be run as two independent processes for server / client interaction.
# Command line arguments "client", "server" define, which side is covered by the process (both is possible).
# Testcases are deterministic (srand), therefore both processes will run in sync
using octsock5;

function usererror(msg::String)
    error("\n\n#####" * msg * "#####\n");
end

function measureRoundtripTime(iOs)
    t::UInt64 = time_ns();
    nRuns::UInt64 = 300000;
    for ix = 1 : nRuns
        octsock5_write(iOs, ix);
        octsock5_read(iOs);
    end
    
    t = time_ns() - t;
    print("Average roundtrip time ", @sprintf("%1.3f", Float64(t)/1e6/Float64(nRuns)), " ms\n");
end

function measureThroughput(iOs::octsock5_cl)
    nRuns::UInt64 = 3000;
    m = Array{Float64}(rand(60, 100, 40));

    # === make first call without timing ===
    t::UInt64 = time_ns();
    octsock5_write(iOs, m);
    obj = octsock5_read(iOs);
    
    for ix = 1 : nRuns
        octsock5_write(iOs, m);
        octsock5_read(iOs);
    end
    
    t_s = Float64(time_ns() - t)/1e9;
    print("Average throughput ", @sprintf("%1.1f", Float64(nRuns*sizeof(m)/2^20)/t_s), " MBytes (2^20) per second, round-trip (one-way: about 2x)\n");
end

function testSpecials(iOs::octsock5_cl)
    arg::Tuple = (Inf, -Inf, NaN);
    octsock5_write(iOs, arg);
    obj::Tuple = octsock5_read(iOs); 
    if (obj !== arg)
        error("verify fail in Inf/-Inf/NaN");
    end
    print("OK\n");
end

function testLarge(iOs::octsock5_cl)
    a1::Array{Float64} = rand(10+00000, 10);
    octsock5_write(iOs, a1);
    a2::Array{Float64} = octsock5_read(iOs); 
    if (a1 != a2)
        error("verify fail in large test");
    end
    print("OK\n");
end

function testAllTypes(iOs::octsock5_cl, nRuns::Int, profiling::Bool)
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
        
        octsock5_write(iOs, arg);
        obj = octsock5_read(iOs);
        if (profiling == false)
            if (obj != arg)
                print("reference:", arg, "\n");
                print("received:", obj, "\n");
                error("verify fail"); 
            end
        end
        # if profiling == false && (mod(v, 1000) == 0) info(v, "\n"); end
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

    args::Dict{String, Bool} = Dict(
        "server" => false, 
        "client" => false, 
        "roundtrip" => false, 
        "throughput" => false,
        "profiling" => false, 
        "alltypes" => false, 
        "tcpip" => false, 
        "specials" => false,
        "helloworld" => false,
        "large" => false
    );
    
    for arg::String in ARGS
        if haskey(args, arg)
            args[arg] = true;
        else
            usererror("invalid command line argument '" * arg * "'");
        end
    end

    # negative port number: Use Windows named pipes 
    # positive port number: Use TCP/IP port 2000
    portNum::Int64 = args["tcpip"] ? 2000 : -12345
    
    if (args["server"] && args["client"]) 
        usererror("must use server or client argument"); # avoid lockup
    elseif (args["server"])
        for arg in ARGS
            if (!(arg == "server" || arg == "tcpip"))
                error("argument unsupported in server mode: " * arg);
            end
        end
        # === open link ===
        iOs::octsock5_cl = octsock5_new(isServer=true, portNum=portNum);
        # Agreed arbitrary token via STDOUT to guarantee that the server is up when the client is started
        # From the command line, start the client process only when this line has appeared
        # An automated startup would e.g. use redirected STDOUT or simply retry with timeout
        print("SERVER_READY\n");
        
        # Execution blocks here until connected
        octsock5_accept(iOs);
        print("got connection\n");

        # === run loopback server ===
        while (true)
            tmp = octsock5_read(iOs);
            octsock5_write(iOs, tmp);
            # agreed arbitrary token to stop the loopback server
            if tmp == "end loopback and have a nice day" break; end
        end
        octsock5_delete(iOs);
        print("SERVER_EXIT\n");
        return;
    elseif (args["client"])
        
        # === open link ===
        iOs = octsock5_new(isServer=false, portNum=portNum);

        # === run tests ===
        if (args["helloworld"])
            octsock5_write(iOs, "Hello World");
            res::String = octsock5_read(iOs); assert(res == "Hello World");
        end
        
        if (args["roundtrip"])
            measureRoundtripTime(iOs);
        end

        if (args["throughput"])
            measureThroughput(iOs);
        end

        if (args["alltypes"])
            testAllTypes(iOs, 10000, args["profiling"]);
        end

        if (args["specials"])
            testSpecials(iOs);
        end

        if (args["large"])
            testLarge(iOs);
        end
        
        # agreed arbitrary token to stop loopback server
        octsock5_write(iOs, "end loopback and have a nice day"); 
        tmpStr::String = octsock5_read(iOs);
        assert(tmpStr == "end loopback and have a nice day");        
        octsock5_delete(iOs);
    end # elseif client
end
main()
