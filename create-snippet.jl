#!/usr/bin/env julia --startup-file=no

using Pkg
using Dates

task = let
    task_name = ""
    primary_pkg = ""
    deps = String[]
    attrib = ""
    snippet = ""
    author = ""
    while !isempty(ARGS)
        arg = popfirst!(ARGS)
        if arg ∈ ("-n", "--name")
            task_name = popfirst!(ARGS)
        elseif arg ∈ ("-p", "--package")
            primary_pkg = popfirst!(ARGS)
        elseif arg ∈ ("-d", "--deps")
            deps = map(String ∘ strip, split(popfirst!(ARGS), ',', keepempty=false))
        elseif arg ∈ ("-a", "--author")
            author = popfirst!(ARGS)
        elseif arg ∈ ("-r", "--attribution")
            attrib = popfirst!(ARGS)
        elseif arg ∈ ("-s", "--snippet")
            snippet = popfirst!(ARGS)
        elseif arg ∈ ("-f", "--snippet-file")
            snippet = read(popfirst!(ARGS), String)
        else
            throw(ArgumentError("Unknown argument: $arg"))
        end
    end
    snippet = String(strip(chopsuffix(chopprefix(snippet, "```julia\n"), "\n```\n")))
    if any(isempty, (task_name, primary_pkg, author, snippet))
        println("Usage: create-snippet.jl --name <task name> --package <pkg> [--deps <dep1,dep2>] --author <name> [--attribution <text>] --snippet <code>")
        exit(1)
    end
    (name = task_name, package = primary_pkg, deps = deps,
     author = author, attribution = attrib, snippet = snippet)
end


# Github action setup

gh_token = get(ENV, "GITHUB_TOKEN", "")
gh_repo = get(ENV, "GITHUB_REPOSITORY", "")
gh_issue = get(ENV, "GITHUB_ISSUE_NUMBER", "")

const IssueItemState =
    @NamedTuple{state::Base.RefValue{Symbol}, duration::Base.RefValue{Float64}, desc::String}

IssueItemState(desc::String) = IssueItemState((Ref(:blocked), Ref(0.0), desc))

issue_checkboxes = (;
    taskdir = IssueItemState("Create task directory"),
    taskenv = IssueItemState("Initialise task environment"),
    taskscript = IssueItemState("Create task script"),
    taskrun = IssueItemState("Run task script"),
    taskjulia = IssueItemState("Determine minimum Julia version"))

issue_checkboxes_julia_versions = @NamedTuple{ver::String, success::Bool}[]

issue_checkboxes_lastfinished = Ref(time())

function issue_comment()
    cbox(item::IssueItemState) =
        string("- ", if item.state[] == :blocked
                   '🛑'
               elseif item.state[] == :running
                   '⏳'
               elseif item.state[] == :done
                   '✅'
               else
                   '❔'
               end, ' ',
               item.desc,
               if item.state[] == :done
                   string(" (", round(item.duration[], digits=3), "s)")
               else "" end)
    cio = IOBuffer()
    println(cio, "## Task creation status")
    println(cio, "\nBased on the provided information, we're creating a new task PR.\n")
    for (name, item) in pairs(issue_checkboxes)
        println(cio, cbox(item))
        if name === :taskjulia
            for (; ver, success) in issue_checkboxes_julia_versions
                println(cio, "  - $ver: ", if success "✅" else "❌" end)
            end
        end
    end
    String(take!(cio))
end

gh_comment_id = nothing

gh_comment_id = if any(isempty, (gh_token, gh_repo, gh_issue))
    nothing
else
    read(`gh api \
          repos/$gh_repo/issues/$gh_issue/comments \
          -F body="$(issue_comment())" \
          --jq .id`, String) |> strip
end

function update_issue_comment()
    isnothing(gh_comment_id) && return
    cmd = addenv(
      `gh api \
        /repos/$gh_repo/issues/comments/$gh_comment_id \
        --method PATCH \
        -F body="$(issue_comment())"`,
      "GITHUB_TOKEN" => gh_token
    )
    run(cmd)
end

function checkstage!(name::Symbol, next::Union{Symbol, Nothing} = nothing)
    ctime = time()
    issue_checkboxes[name].state[] = :done
    issue_checkboxes[name].duration[] = ctime - issue_checkboxes_lastfinished[]
    issue_checkboxes_lastfinished[] = ctime
    if !isnothing(next)
        issue_checkboxes[next].state[] = :running
    end
    update_issue_comment()
end

gh_output = if haskey(ENV, "GITHUB_OUTPUT")
    open(ENV["GITHUB_OUTPUT"], "a")
else
    devnull
end

# Remove all potentially sensitive environment variables
for key in keys(ENV)
    if startswith(key, "GITHUB_")
        delete!(ENV, key)
    end
end


# Task creation

git_initial_head = readchomp(`git rev-parse HEAD`)
git_initial_index = readchomp(`git hash-object .git/index`)

taskdir = joinpath(@__DIR__,
                   "tasks",
                   string(uppercase(first(task.package))),
                   task.package,
                   replace(task.name, r"[^A-Za-z0-9\-_]" => '-'))
taskfile = joinpath(taskdir, "task.jl")

@info "Creating task $(relpath(taskdir, @__DIR__))"

isdir(taskdir) && throw(ArgumentError("Task already exists: $taskdir"))

mkpath(taskdir)

Pkg.activate(taskdir)

checkstage!(:taskdir, :taskenv)
@info "Creating environment"

allpkgs = if task.package == "Base" String[] else String[task.package] end
append!(allpkgs, task.deps)
!isempty(allpkgs) && Pkg.add(allpkgs)

checkstage!(:taskenv, :taskscript)
@info "Constructing task script"

using_lines = String[]
imported_pkgs = String[]
script_lines = String[]

using_rx = r"^\s*using ([^ ]*)(?:$|\s|:)"
import_rx = r"^\s*import ([^ ]*)(?:$|\s|:)"

for line in eachline(IOBuffer(task.snippet))
    if !isempty(script_lines)
        push!(script_lines, line)
    elseif all(isspace, line)
    else
        umatch = match(using_rx, line)
        if isnothing(umatch)
            umatch = match(import_rx, line)
        end
        if isnothing(umatch)  
            push!(script_lines, line)
        else
            pkg = umatch.captures[1]
            pkg ∉ imported_pkgs &&
                push!(imported_pkgs, pkg)
            push!(using_lines, line)
        end
    end
end

for dep in append!(String[task.package], task.deps)
    if dep ∉ imported_pkgs
        push!(using_lines, "using $dep")
    end
end

open(taskfile, "w") do io
    println(io, "# Task: ", task.name)
    println(io, "# Package: ", task.package)
    if !isempty(task.deps)
        println(io, "# Dependencies: ", join(task.deps, ", "))
    end
    println(io, "# Author: @", task.author)
    if !isempty(task.attribution)
        println(io, "# Attribution: ", task.attribution)
    end
    println(io, "# Created: ", string(now()))
    println(io, "\n__t1 = time()\n")
    join(io, using_lines)
    println(io, "\n\n__t2 = time()\n")
    join(io, script_lines)
    println(io, "\n\n__t3 = time()\n")
    println(io, raw"""
    __t_using = __t2 - __t1
    __t_script = __t3 - __t2
    __t_total = __t3 - __t1
    println(stdout, "$__t_using, $__t_script, $__t_total seconds")
    """)
end


# Validation

checkstage!(:taskscript, :taskrun)
@info "Performing trial run of task"

taskoutput = last(collect(eachline(`julia --project=$taskdir $taskfile`)))

tasktimes = map(t -> parse(Float64, t), split(chopsuffix(taskoutput, " seconds"), ','))
@assert length(tasktimes) == 3

println(gh_output, "task_time_using=", round(tasktimes[1], digits=3))
println(gh_output, "task_time_script=", round(tasktimes[2], digits=3))
println(gh_output, "task_time_total=", round(tasktimes[3], digits=3))

checkstage!(:taskrun, :taskjulia)
@info "Determining minimum Julia version (TODO)"

minjulia = VERSION
juliaup_julia = Cmd(filter(isfile, [
    expanduser("~/.julia/juliaup/bin/julia"), expanduser("~/.juliaup/bin/julia")]))
rm(joinpath(taskdir, "Manifest.toml"), force=true)
for minorver in 0:VERSION.minor
    # We could do a binary search, but it's probably quicker to fail to resolve on old versions
    # than succeed and install all the packages etc. on newer versions.
    if minorver > 1 # We can infer the last one failed
        push!(issue_checkboxes_julia_versions, (; ver = "1.$(minorver - 1)", success = false))
        update_issue_comment()
    end
    jlver = "1.$minorver"
    @info "Trying Julia $jlver"
    resolved = success(`$juliaup_julia +$jlver --project=$taskdir -e 'using Pkg; Pkg.resolve()'`)
    !resolved && continue
    instantiate = success(`$juliaup_julia +$jlver --project=$taskdir -e 'using Pkg; Pkg.instantiate()'`)
    !instantiate && continue
    trialrun = success(`$juliaup_julia +$jlver --project=$taskdir $taskfile`)
    if trialrun
        global minjulia = VersionNumber(1, minorver)
        push!(issue_checkboxes_julia_versions, (; ver = jlver, success = true))
        update_issue_comment()
        Pkg.compat("julia", "$minjulia")
        break
    end
    rm(joinpath(taskdir, "Manifest.toml"), force=true)
end

mdeps = Pkg.Types.read_manifest(joinpath(taskdir, "Manifest.toml")).deps
rm(joinpath(taskdir, "Manifest.toml"))

for (uuid, pkg) in mdeps
    if pkg.name == task.package || pkg.name ∈ task.deps
        Pkg.compat(pkg.name, ">=$(pkg.version)")
    end
end

rm(joinpath(taskdir, "Manifest.toml"), force=true)

checkstage!(:taskjulia)
@info "Finishing up"

for reg in Pkg.Registry.reachable_registries()
    for (uuid, regpkg) in reg
        if regpkg.name == task.package
            repourl = chopsuffix(Pkg.Registry.registry_info(regpkg).repo, ".git")
            ghrepo = match(r"https://github.com/(?<owner>[^/]+)/(?<repo>[^/]+)", repourl)
            if !isnothing(ghrepo)
                println(gh_output, "pkg_repo_owner=", ghrepo["owner"])
                println(gh_output, "pkg_repo_name=", ghrepo["repo"])
            end
        end
    end
end



# Cleanup

let allowed = (relpath(taskfile, @__DIR__),
               relpath(joinpath(taskdir, "Project.toml"), @__DIR__),
               "create-snippet-logs.txt",
               "snippet.jl")
    for line in eachline(`git status --untracked-files=all --porcelain=v1`)
        if !(startswith(line, "?? ") && line[4:end] in allowed)
            error("Unauthorized change detected: $line (only $(join(allowed, ", ", " and ")) allowed)")
        end
    end
end

git_final_head  = readchomp(`git rev-parse HEAD`)
git_final_index = readchomp(`git hash-object .git/index`)

if git_initial_head != git_final_head
    error("Git HEAD was sneakily rewritten from $git_initial_head to $git_final_head")
end
if git_initial_index != git_final_index
    error("Git index was sneakily modified from $git_initial_index to $git_final_index")
end

# if !isnothing(gh_comment_id)
#     run(addenv(
#       `gh api \
#         /repos/$gh_repo/issues/comments/$gh_comment_id \
#         --method DELETE`,
#       "GITHUB_TOKEN" => gh_token))
# end
