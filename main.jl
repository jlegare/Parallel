using Distributed

# ----------------------------------------
# CONFIGURATION
# ----------------------------------------

module CommandLine

    # ----------------------------------------
    # IMPORTED NAMESPACES
    # ----------------------------------------

    import ArgParse

    # ----------------------------------------
    # CONFIGURATION
    # ----------------------------------------

    export arguments

    # ----------------------------------------
    # EXPORTED FUNCTIONS
    # ----------------------------------------

    function arguments(arguments)
        parser = ArgParse.ArgParseSettings()

        @ArgParse.add_arg_table parser begin
            "--workers"
            arg_type = Int
            default  = 0
            help     = "number of worker processes"
        end

        return ArgParse.parse_args(arguments, parser)
    end
end

# ----------------------------------------
# DISTRIBUTED SET UP
# ----------------------------------------

arguments = CommandLine.arguments(ARGS)
worker_count = arguments["workers"]

@info "WORKERS ... $(worker_count)"

if worker_count > 0
    addprocs(worker_count)
end

# ----------------------------------------
# IMPORTS
# ----------------------------------------

@everywhere using SharedArrays

# ----------------------------------------
# FUNCTIONS
# ----------------------------------------

@everywhere function transfer(from::SharedArray{Int64}, to::SharedArray{Int64}, channel)
    function work(i, j)
        return i * j
    end

    for i ∈ localindices(from)
        snooze = rand()
        to[i] = work(from[i], myid())
        @info "IN $(myid()) ... $(i) ... $(snooze)."
        sleep(snooze)
        put!(channel, true)
    end

    return 0
end

# ----------------------------------------
# MAIN PROCESSING
# ----------------------------------------

const jobs_count = 16

S = SharedArray{Int64, 1}(jobs_count, )
T = SharedArray{Int64, 1}(jobs_count, )

channel = RemoteChannel(() -> Channel{Bool}(jobs_count))

for i ∈ 1:length(S)
    S[i] = i
end
                 

@sync begin
    for worker in procs(S)
        @async begin
            remotecall_wait(transfer, worker, S, T, channel)
        end
    end

    for i ∈ 1:jobs_count
        v = take!(channel)
        @info "HERE ... $(i)/$(jobs_count)"
    end

    @info "DONE!!!"
end

@show S
@show T
