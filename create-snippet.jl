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
        if arg == "--name"
            task_name = popfirst!(ARGS)
        elseif arg == "--package"
            primary_pkg = popfirst!(ARGS)
        elseif arg == "--deps"
            deps = map(String ∘ strip, split(popfirst!(ARGS), ',', keepempty=false))
        elseif arg == "--author"
            author = popfirst!(ARGS)
        elseif arg == "--attribution"
            attrib = popfirst!(ARGS)
        elseif arg == "--snippet"
            snippet = popfirst!(ARGS)
        elseif arg == "--snippet-file"
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

issue_checkboxes = (;
    taskdir =    (done = Ref(false), duration = Ref(0.0), desc = "Create task directory"),
    taskenv =    (done = Ref(false), duration = Ref(0.0), desc = "Initialise task environment"),
    taskscript = (done = Ref(false), duration = Ref(0.0), desc = "Create task script"),
    taskrun =    (done = Ref(false), duration = Ref(0.0), desc = "Run task script"),
    taskjulia =  (done = Ref(false), duration = Ref(0.0), desc = "Determine minimum Julia version"))

issue_checkboxes_lastfinished = Ref(time())

function issue_comment()
    cbox(item::@NamedTuple{done::Base.RefValue{Bool}, duration::Base.RefValue{Float64}, desc::String}) =
        string("- [", ifelse(item.done[], 'x', ' '), "] ", item.desc,
               if item.done[] string(" (", round(item.duration[], digits=3), "s)") else "" end)
    cio = IOBuffer()
    println(cio, "## Task creation status")
    println(cio, "\nBased on the provided information, we're creating a new task PR.\n")
    for item in issue_checkboxes
        println(cio, cbox(item))
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

function checkstage!(name::Symbol)
    ctime = time()
    issue_checkboxes[name].done[] = true
    issue_checkboxes[name].duration[] = ctime - issue_checkboxes_lastfinished[]
    issue_checkboxes_lastfinished[] = ctime
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

taskdir = joinpath(@__DIR__,
                   string(uppercase(first(task.package))),
                   task.package,
                   replace(task.name, r"[^A-Za-z0-9\-_]" => '-'))
taskfile = joinpath(taskdir, "task.jl")

@info "Creating task $taskdir"

isdir(taskdir) && throw(ArgumentError("Task already exists: $taskdir"))

mkpath(taskdir)

Pkg.activate(taskdir)

checkstage!(:taskdir)
@info "Creating environment"

allpkgs = if task.package == "Base" String[] else String[task.package] end
append!(allpkgs, task.deps)
Pkg.add(allpkgs)

checkstage!(:taskenv)
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

checkstage!(:taskscript)
@info "Performing trial run of task"

taskoutput = last(collect(eachline(`julia --project=$taskdir $taskfile`)))

tasktimes = map(t -> parse(Float64, t), split(chopsuffix(taskoutput, " seconds"), ','))
@assert length(tasktimes) == 3

println(gh_output, "task_time_using=", round(tasktimes[1], digits=3))
println(gh_output, "task_time_script=", round(tasktimes[2], digits=3))
println(gh_output, "task_time_total=", round(tasktimes[3], digits=3))

checkstage!(:taskrun)
@info "Determining minimum Julia version (TODO)"

# TODO: Re-create the environment with Julia 1.0 through to `VERSION`
# and keep the first one that works, using Juliaup.

checkstage!(:taskjulia)
@info "Finishing up"

deps = Pkg.Types.read_manifest(joinpath(taskdir, "Manifest.toml")).deps

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

rm(joinpath(taskdir, "Manifest.toml"), force=true)

if !isnothing(gh_comment_id)
    run(addenv(
      `gh api \
        /repos/$gh_repo/issues/comments/$gh_comment_id \
        --method DELETE`,
      "GITHUB_TOKEN" => gh_token))
end
