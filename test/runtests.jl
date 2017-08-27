# [note1]: Expects julia.exe in path (e.g. use mingw with export PATH="$PATH:/c/julia/bin"
# [note2]: https://discourse.julialang.org/t/interpolating-an-empty-string-inside-backticks/2428/3
using octsock5
using Base.Test
function runTwoProcess(args::Cmd, cSharp::Bool, tcpIp::Bool) # [note2]
    # start server process [note1]

    if cSharp
        assert(false == tcpIp);
        # run C# server implementation
        a1::Tuple = open(`csharp.exe`);
    else
        # run Julia server implementation
        if tcpIp
            a1 = open(`julia.exe main.jl server tcpip`);
        else
            a1 = open(`julia.exe main.jl server`);
        end
    end
    # wait until server has bound the port
    resp1::String = readline(a1[1]);
    assert(contains(resp1, "SERVER_READY"));
    
    # start client process
    #sleep(0.5);
    if tcpIp
        a2::Tuple = open(`julia.exe main.jl client $args tcpip`);
    else
        a2 = open(`julia.exe main.jl client $args`);
    end
    # read all output
    while true
        resp1 = readline(a1[1]);
        if contains(resp1, "SERVER_EXIT")
            break;
        end
    end
    resp2::String = readstring(a2[2]);
    
    # clean shutdown
    close(a1[1]);
    close(a2[1]);
    return (resp1, resp2)
end

function runLatency(cSharp::Bool, tcpIp::Bool)
    info("running latency test");
    (a,b) = runTwoProcess(`roundtrip`, cSharp, tcpIp);
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

function runThroughput(cSharp::Bool, tcpIp::Bool)
    info("running throughput test");
    (a, b) = runTwoProcess(`throughput`, cSharp, tcpIp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

function runAllTypes(cSharp::Bool, tcpIp::Bool)
    info("running all types test");
    (a, b) = runTwoProcess(`alltypes`, cSharp, tcpIp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

# tests NaN, Inf
function runSpecials(cSharp::Bool, tcpIp::Bool)
    info("running +/-Inf, NaN test");
    (a, b) = runTwoProcess(`specials`, cSharp, tcpIp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

# tests a large data package (blocking problems?
function runLarge(cSharp::Bool, tcpIp::Bool)
    info("running large data package test");
    (a, b) = runTwoProcess(`large`, cSharp, tcpIp)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

# opens and closes repeatedly. Tests, whether handles are cleanly released.
function reopen(tcpIp::Bool)    
    if tcpIp
        portNum::Int64 = 20000;
    else
        portNum = -12345;
    end
    for i = 1 : 100            
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

# pass == 1 : Julia loopback server, windows named pipes
# pass == 2 : Julia loopback server, TCP/IP (slow)
# pass == 3 : C# loopback server, windows named pipes
for pass = 1 : 3
    tcpIp::Bool = (pass == 2);
    cSharp::Bool = (pass == 3);

    if pass < 3
        @test reopen(tcpIp);
    end

    @test runLarge(cSharp, tcpIp);
    @test runLatency(cSharp, tcpIp);
    @test runThroughput(cSharp, tcpIp);
    @test runSpecials(cSharp, tcpIp);
    @test runAllTypes(cSharp, tcpIp);
    if pass < 3
        @test reopen(tcpIp);
    end
end
