# [note1]: Expects julia.exe in path (e.g. use mingw with export PATH="$PATH:/c/julia/bin"
# [note2]: https://discourse.julialang.org/t/interpolating-an-empty-string-inside-backticks/2428/3
using octsock5
using Base.Test
function runTwoProcess(args::Cmd, cSharp::Bool) # [note2]
    # start server process [note1]
    if cSharp
        # run C# server implementation
        a1::Tuple = open(`csharp.exe`);
    else
        # run Julia server implementation
        a1 = open(`julia.exe main.jl server`);
    end
    
    # wait until server has bound the port
    resp1::String = readline(a1[1]);
    assert(contains(resp1, "SERVER_READY"));
    
    # start client process
    sleep(0.5);
    a2::Tuple = open(`julia.exe main.jl client $args`);
    # read all output
    resp1 = readstring(a1[2]);
    resp2::String = readstring(a2[2]);
    
    # clean shutdown
    close(a1[1]);
    close(a2[1]);
    return (resp1, resp2)
end

function runLatency(cSharp::Bool)
    info("running latency test (windows named pipes)");
    (a,b) = runTwoProcess(`roundtrip`, cSharp);
    info("Server reports: " * a)
    info("Client reports: " * b);
        
    # TCP/IP must be run manually, fails to connect for unknown reasons

    if (false == cSharp)
        info("TCP/IP tests need to be run manually for the time being");
        #info("running latency test (TCP/IP on localhost)");
        #(a,b) = runTwoProcess(`roundtrip tcpip`, cSharp);
        #info("Server reports: " * a)
        #info("Client reports: " * b);
    end
    return true
end

function runThroughput(cSharp::Bool)
    info("running throughput test (windows named pipes)");
    (a, b) = runTwoProcess(`throughput`, cSharp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    
    if (false == cSharp)
        info("TCP/IP tests need to be run manually for the time being");
        #info("running throughput test (tcpip on localhost)");
        #(a, b) = runTwoProcess(`throughput tcpip`, cSharp)
        #info("Server reports: " * a)
        #info("Client reports: " * b);
    end
    return true
end

function runAllTypes(cSharp::Bool)
    info("running all types test");
    (a, b) = runTwoProcess(`alltypes`, cSharp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

# tests NaN, Inf
function runSpecials(cSharp::Bool)
    info("running +/-Inf, NaN test");
    (a, b) = runTwoProcess(`specials`, cSharp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

# opens and closes repeatedly. Tests, whether handles are cleanly released.
function reopen()
    for i = 1 : 100
        portNum::Int64 = -123456;
        iServer::octsock5_cl = octsock5_new(isServer=true, portNum=portNum);
        iClient::octsock5_cl = octsock5_new(isServer=false, portNum=portNum);        
        octsock5_accept(iServer);
        s1::String = "Hello world this is a test.";
        s2::String = "Lorem Ipsum. Bonk.";
        octsock5_write(iServer, s1);
        octsock5_write(iClient, s2);
        assert(octsock5_read(iClient) == s1);
        assert(octsock5_read(iServer) == s2);
        octsock5_delete(iServer);
        octsock5_delete(iClient);
    end
    return true;
end


info("*** running Julia-Julia tests ***");
@test reopen();
@test runLatency(false);
@test runThroughput(false);
@test runSpecials(false);
@test runAllTypes(false);

info("*** running Julia-C# tests via csharp.exe loopback server ***");
@test runLatency(true);
@test runThroughput(true);
@test runSpecials(true);
@test runAllTypes(true);
