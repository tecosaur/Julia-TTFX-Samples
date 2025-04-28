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
    snippet = String(strip(chopsuffix(chopprefix(snippet, "```julia\n"), "```")))
    if any(isempty, (task_name, primary_pkg, author, snippet))
        println("Usage: create-snippet.jl --name <task name> --package <pkg> [--deps <dep1,dep2>] --author <name> [--attribution <text>] --snippet <code>")
        exit(1)
    end
    (name = task_name, package = primary_pkg, deps = deps,
     author = author, attribution = attrib, snippet = snippet)
end

taskdir = joinpath(@__DIR__,
                   string(uppercase(first(task.package))),
                   task.package,
                   replace(task.name, r"[^A-Za-z0-9\-_]" => '-'))
taskfile = joinpath(taskdir, "task.jl")

mkpath(taskdir)

Pkg.activate(taskdir)
Pkg.add(append!(String[task.package], task.deps))

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

rm(joinpath(taskdir, "Manifest.toml"), force=true)

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
    println(stdout, "($__t_using, $__t_script, $__t_total) seconds")
    """)
end
