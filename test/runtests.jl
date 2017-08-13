# [note1]: Expects julia.exe in path (e.g. use mingw with export PATH="$PATH:/c/julia/bin"
# [note2]: https://discourse.julialang.org/t/interpolating-an-empty-string-inside-backticks/2428/3
using octsock5
using Base.Test
function runTwoProcess(args::Cmd) # [note2]
    # start server process [note1]
    a1::Tuple = open(`julia.exe main.jl server $args`);

    # wait until server has bound the port
    resp1::String = readline(a1[1]);
    assert(contains(resp1, "SERVER_READY"));
    
    # start client process
    a2::Tuple = open(`julia.exe main.jl client $args`);
    
    # read all output
    resp1 = readstring(a1[2]);
    resp2::String = readstring(a2[2]);
    
    # clean shutdown
    close(a1[1]);
    close(a2[1]);
    return (resp1, resp2)
end

function runLatency()
    info("running latency test (windows named pipes)");
    (a,b) = runTwoProcess(`roundtrip`);
    info("Server reports: " * a)
    info("Client reports: " * b);
    
    info("running latency test (TCP/IP on localhost)");
    (a,b) = runTwoProcess(`roundtrip tcpip`);
    info("Server reports: " * a)
    info("Client reports: " * b);

    return true
end

function runThroughput()
    info("running throughput test (windows named pipes)");
    (a, b) = runTwoProcess(`throughput`)
    info("Server reports: " * a)
    info("Client reports: " * b);
    
    info("running throughput test (tcpip on localhost)");
    (a, b) = runTwoProcess(`throughput tcpip`)
    info("Server reports: " * a)
    info("Client reports: " * b);

    return true
end

function runAllTypes()
    info("running all types test");
    (a, b) = runTwoProcess(`alltypes`)
    info("Server reports: " * a)
    info("Client reports: " * b);
    return true
end

@test runLatency();
@test runThroughput();
@test runAllTypes();
