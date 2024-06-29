using Test
using JSONPointer
using OrderedCollections

import JSONPointer: ElementInsertionError, ElementRetrievalError 

@testset "Basic Tests" begin
    pointer_doc = Dict(
        "foo" => ["bar", "baz"],
        "" => 0,
        "a/b" => 1,
        "c%d" => 2,
        "e^f" => 3,
        "g|h" => 4,
        "i\\j" => 5,
        "k\"l" => 6,
        " " => 7,
        "m~n" => 8
    )
    pointer_doc = PointerDict(pointer_doc)

    @test pointer_doc[j""] == pointer_doc
    @test pointer_doc[j"/foo"] == ["bar", "baz"] == get_pointer(pointer_doc, j"/foo")
    @test pointer_doc[JSONPointer.Pointer("/foo/0"; shift_index = true)] == "bar"
    @test pointer_doc[j"/foo/1"] == "bar"
    @test pointer_doc[j"/"] == 0
    @test pointer_doc[j"/a~1b"] == 1
    @test pointer_doc[j"/c%d"] == 2
    @test pointer_doc[j"/e^f"] == 3
    @test pointer_doc[j"/g|h"] == 4
    @test pointer_doc[JSONPointer.Pointer("/i\\j")] == 5
    @test pointer_doc[j"/k\"l"] == 6
    @test pointer_doc[j"/ "] == 7
    @test pointer_doc[j"/m~0n"] == 8

    @test get_pointer(pointer_doc, j"") == pointer_doc
    @test get_pointer(pointer_doc, j"/foo") == ["bar", "baz"]
    @test get_pointer(pointer_doc, JSONPointer.Pointer("/foo/0"; shift_index = true)) == "bar"
    @test get_pointer(pointer_doc, j"/foo/1") == "bar"
    @test get_pointer(pointer_doc, j"/") == 0
    @test get_pointer(pointer_doc, j"/a~1b") == 1
    @test get_pointer(pointer_doc, j"/c%d") == 2
    @test get_pointer(pointer_doc, j"/e^f") == 3
    @test get_pointer(pointer_doc, j"/g|h") == 4
    @test get_pointer(pointer_doc, JSONPointer.Pointer("/i\\j")) == 5
    @test get_pointer(pointer_doc, j"/k\"l") == 6
    @test get_pointer(pointer_doc, j"/ ") == 7
    @test get_pointer(pointer_doc, j"/m~0n") == 8

    for k in (
        j"",
        j"/foo",
        j"/foo/1",
        j"/",
        j"/a~1b",
        j"/c%d",
        j"/e^f",
        j"/g|h",
        JSONPointer.Pointer("/i\\j"),
        j"/k\"l",
        j"/ ",
        j"/m~0n",
    )
        @test haskey(pointer_doc, k)
        @test has_pointer(pointer_doc, k)
    end
end

@testset "URI Fragment Tests" begin
    doc = Dict(
        "foo" => ["bar", "baz"],
        ""=> 0,
        "a/b"=> 1,
        "c%d"=> 2,
        "e^f"=> 3,
        "g|h"=> 4,
        "i\\j"=> 5,
        "k\"l"=> 6,
        " "=> 7,
        "m~n"=> 8,
    )
    pointer_doc = PointerDict(doc)

    @test pointer_doc[j"#"] == pointer_doc
    @test pointer_doc[j"#/foo"] == ["bar", "baz"]
    @test pointer_doc[JSONPointer.Pointer("#/foo/0"; shift_index = true)] == "bar"
    @test pointer_doc[j"#/foo/1"] == "bar"
    @test pointer_doc[j"#/"] == 0
    @test pointer_doc[j"#/a~1b"] == 1
    @test pointer_doc[j"#/c%25d"] == 2
    @test pointer_doc[j"#/e%5Ef"] == 3
    @test pointer_doc[j"#/g%7Ch"] == 4
    @test pointer_doc[j"#/i%5Cj"] == 5
    @test pointer_doc[j"#/k%22l"] == 6
    @test pointer_doc[j"#/%20"] == 7
    @test pointer_doc[j"#/m~0n"] == 8

    @test get_pointer(doc, j"#") == doc
    @test get_pointer(doc, j"#/foo") == ["bar", "baz"]
    @test get_pointer(doc, JSONPointer.Pointer("#/foo/0"; shift_index = true)) == "bar"
    @test get_pointer(doc, j"#/foo/1") == "bar"
    @test get_pointer(doc, j"#/") == 0
    @test get_pointer(doc, j"#/a~1b") == 1
    @test get_pointer(doc, j"#/c%25d") == 2
    @test get_pointer(doc, j"#/e%5Ef") == 3
    @test get_pointer(doc, j"#/g%7Ch") == 4
    @test get_pointer(doc, j"#/i%5Cj") == 5
    @test get_pointer(doc, j"#/k%22l") == 6
    @test get_pointer(doc, j"#/%20") == 7
    @test get_pointer(doc, j"#/m~0n") == 8
end

@testset "WrongInputTests" begin
    @test_throws ArgumentError JSONPointer.Pointer("some/thing")
    pointer_doc = [0, 1, 2]
    @test_throws(
        ElementRetrievalError,
        pointer_doc[j"/a"],
    )
    @test_throws ElementRetrievalError get_pointer(Dict(), j"/a")
    @test_throws ElementRetrievalError pointer_doc[j"/10"]
    @test_throws ElementRetrievalError get_pointer(Dict("a"=> []), j"/a/1")
    @test_throws ElementRetrievalError get_pointer(Dict("a"=> (0,1)), j"/a/b")
end

@testset "JSONPointer Advanced" begin
    a = j"/a/2/d::array"
    b = j"/a/2/e::object"
    c = j"/a/2/f::boolean"

    @test a.tokens == ["a", 2, "d"]
    @test eltype(a) <: Vector{Any}
    @test eltype(b) <: OrderedDict{String, Any}
    @test eltype(c) <: Bool
end

@testset "construct Dict with JSONPointer" begin
    p1 = j"/a/1/b"
    p2 = j"/cd/2/ef"

    doc = Dict()
    set_pointer!(doc, p1, 1)
    set_pointer!(doc, p2, 2)
    @test length(doc) == 2

    pointer_doc = PointerDict(p1 =>1, p2 => 2)

    @test haskey(pointer_doc, p1)
    @test haskey(pointer_doc, p2)
    @test !haskey(pointer_doc, j"/x")
    @test !haskey(pointer_doc, j"/ba/5")
    @test has_pointer(doc, p1)
    @test has_pointer(doc, p2)
    @test !has_pointer(doc, j"/x")
    @test !has_pointer(doc, j"/ba/5")
    @test pointer_doc[p1] == get_pointer(doc, p1)
    @test pointer_doc[p2] == get_pointer(doc, p2)

    p1 = j"/ab/1"
    p2 = j"/cd/2/ef"

    pointer_doc = PointerDict(p1 => "This", p2 => "Is my Data")
    @test pointer_doc[p1] == "This"
    @test pointer_doc[p2] == "Is my Data"

    # this is not supported 
    doc = Dict(p1 => "This", p2 => "Is my Data")
    @test_broken get_pointer(doc, p1)
end

@testset "test for 'getindex', 'get', 'get!'" begin
    doc = [Dict("a" => 10)]
    pointer_doc = [PointerDict("a" => 10)]
    @test doc[j"/1/a"] == 10
    @test pointer_doc[j"/1/a"] == 10

    p1 = j"/a/b/c/d/e/f/g/1/2/a/b/c"
    doc = Dict{String, Any}()
    set_pointer!(doc, p1, "sooo deep")
    @test get_pointer(doc, p1, missing) == "sooo deep"
    @test ismissing(get_pointer(doc, j"/nonexist", missing))

    pointer_doc = PointerDict(doc)
    @test pointer_doc[p1] == "sooo deep"
    @test ismissing(get(pointer_doc, j"/nonexist", missing))

    @test has_pointer(doc, j"/a/b/c")
    @test has_pointer(doc, j"/a/b/c/d")
    @test has_pointer(doc, j"/a/b/c/d/e/f/g/1")
    @test !has_pointer(doc, j"/a/b/c/d/e/f/g/2")

    @test haskey(pointer_doc, j"/a/b/c")
    @test haskey(pointer_doc, j"/a/b/c/d")
    @test haskey(pointer_doc, j"/a/b/c/d/e/f/g/1")
    @test !haskey(pointer_doc, j"/a/b/c/d/e/f/g/2")

    @test isa(pointer_doc[j"/a/b/c"], AbstractDict)
    @test isa(pointer_doc[j"/a/b/c/d"], AbstractDict)
    @test isa(pointer_doc[j"/a/b/c/d/e"], AbstractDict)
    @test isa(pointer_doc[j"/a/b/c/d/e/f/g"], Array)
    @test ismissing(pointer_doc[j"/a/b/c/d/e/f/g/1/1"])

    @test get(pointer_doc, j"/a/f", missing) |> ismissing
    @test get(pointer_doc, j"/a/b/c/d/e/f/g/5", 10000) == 10000

    @test_throws ElementRetrievalError pointer_doc[j"/a/f"]
    @test_throws ElementRetrievalError pointer_doc[j"/x"]
    @test_throws ElementRetrievalError pointer_doc[j"/a/b/c/d/e/f/g/5"]

    pointer_doc = [[10, 20, 30, ["me"]]]
    @test pointer_doc[j"/1"] == [10, 20, 30, ["me"]]
    @test pointer_doc[j"/1/2"] == 20
    @test pointer_doc[j"/1/4"] == ["me"]
    @test pointer_doc[j"/1/4/1"] == "me"

    # get isn't defined for array
    @test_broken get(pointer_doc, j"/1", missing) |> ismissing

    pointer_doc = PointerDict()
    @test "this" == get!(pointer_doc, j"/a", "this")
    @test pointer_doc[j"/a"] == pointer_doc["a"] == "this"

    @test [1,2,3] == get!(pointer_doc, j"/b", Any[1,2,3])
    @test pointer_doc[j"/b"] == pointer_doc["b"] == [1,2,3]
    @test pointer_doc[j"/b/1"] == pointer_doc["b"][1] == 1
    @test pointer_doc[j"/b/2"] == pointer_doc["b"][2] == 2

    @test get!(pointer_doc, j"/b/5", missing) |> ismissing
    @test pointer_doc[j"/b/5"] === pointer_doc["b"][5]

    @test "that" == get(pointer_doc, "c", "that")
    @test haskey(pointer_doc, "c") == false
    @test "that" == get!(pointer_doc, "c", "that")
    @test haskey(pointer_doc, "c")
    pointer_doc["e"] = [1]
end

@testset "literal string for a Number" begin
    p1 = j"/\5"
    p2 = j"/\559"
    p3 = j"/\900/10"

    d = PointerDict(p1 => 1, p2 => 2, p3 => 3)
    @test d[p1] == 1
    @test d["5"] == 1
    @test d[p2] == 2
    @test d["559"] == 2

    @test d[p3] == 3
    @test isa(d["900"], Array)
end

@testset "unique" begin
    arr = [j"/a", j"/b", j"/a/1", j"/b/c/d", j"/a", j"/b/c/d"]
    unique_arr = unique(arr)
    @test length(unique_arr) == 4
    @test j"/a" in unique_arr
    @test j"/b" in unique_arr
    @test j"/a/1" in unique_arr
    @test j"/b/c/d" in unique_arr
    @test unique(unique_arr) == unique_arr

    empty!(arr)
    @test isempty(arr)
    @test unique(arr) == arr 
end

@testset "Failed setindex!" begin
    d = PointerDict("a" => [1])
    @test_throws ElementInsertionError d[j"/a/b"] = 1
end

@testset "grow object and array" begin
    d = PointerDict(j"/a" => Dict())
    d[j"/a/b"] = []
    d[j"/a/b/2"] = 1
    d[j"/a/b/5"] = 2
    @test_throws Exception d[j"/a/5"] = "something"
    @test_throws Exception d[j"/a/b/gd"] = "nothing"

    @test isa(d[j"/a/b"], Array)
    @test isa(d[j"/a/b/1"], Missing)
end

@testset "Enforce type on JSONPointer" begin
    p1 = j"/a/1::string"
    p2 = j"/a/2::number"
    p3 = j"/a/3::object"
    p4 = j"/a/4::array"
    p5 = j"/a/5::boolean"
    p6 = j"/a/6::null"

    pointer_doc = PointerDict(p1 =>"string", p2 => 1, p3 => Dict(), p4 => [], p5 => true, p6 => missing)
    @test pointer_doc[p1] == "string"
    @test pointer_doc[p2] == 1
    
    @test_throws ArgumentError pointer_doc[p1] = 1
    @test_throws ArgumentError pointer_doc[p2] = "string"
    
    d = PointerDict(p1 =>missing, p2 => missing, p3 => missing, p4 => missing, p5 => missing)
    @test d[p1] == ""
    @test d[p2] == 0
    @test isa(d[p3], OrderedDict)
    @test isa(d[p4], Array{Any, 1})
    @test d[p5] == false
end

@testset "Exceptions" begin
    # error on undefined datatype
    @test_throws DomainError JSONPointer.Pointer("/a::nothing")
    @test_throws DomainError JSONPointer.Pointer("/a/1::Int")

    # error for 0 based indexing 
    @test_throws BoundsError JSONPointer.Pointer("/0")
    @test_throws BoundsError JSONPointer.Pointer("/a/0")
    @test isa(JSONPointer.Pointer("/0"; shift_index = true), JSONPointer.Pointer)

end

@testset "PointerDicts" begin
    d = Dict("foo"=>1, "bar"=>2)
    _keys = collect(keys(d))
    pd = PointerDict(d)

    @test length(pd) == length(d)

    @test empty!(PointerDict(Dict("foo"=>1, :bar=>2))) isa PointerDict
    @test empty(pd) == PointerDict(empty(d))

    @test haskey(pd, "foo")
    @test getkey(pd, "buz", nothing) === nothing

    @testset "convert" begin
        expected = OrderedDict
        result = convert(expected, pd)

        @test result isa expected
    end

    @testset "iterate" begin
        @test iterate(pd) == iterate(d)
        @test iterate(pd, 1) == iterate(d, 1)
        @test iterate(pd, 2) == iterate(d, 2)
    end

    @testset "iteratorsize" begin
        @test Base.IteratorSize(pd) == Base.IteratorSize(d)
    end

    @testset "iteratoreltype" begin
        @test Base.IteratorEltype(pd) == Base.IteratorEltype(d)
    end

    push!(pd, "buz" => 10)
    @test pop!(pd, "buz") == 10
    @test pop!(pd, "buz", 20) == 20
    @test get(pd, delete!(pd, "foo"), 10) == 10

    @testset "merge & mergewith" begin
        a = PointerDict(j"/dict/a"=>1, j"/array/1"=>2, "c"=>3)
        b = PointerDict(j"/dict/b"=>4, j"/array/1"=>5)
        c = PointerDict(j"/dict/dict"=>Dict("aa"=>100), "d"=>nothing)

        @test @inferred(merge(a, b)) == PointerDict(j"/dict/a" => 1, "c"=>3, j"/dict/b" => 4, j"/array"=>Any[2, 5])
        @test @inferred(merge(a, b, c)) == PointerDict(j"/dict/a" => 1, "c"=>3, j"/dict/b" => 4, j"/array"=>Any[2, 5], j"/dict/dict" => Dict("aa" => 100), "d" => nothing)
    end
end

@testset "Miscellaneous" begin 
    p1 = j"/a/b/1/c"

    @test p1 == j"/a/b/1/c"
    @test p1 != j"/b/a/1/c"

    arr = [1,2,3]
    haskey(arr, j"/1")
    !haskey(arr, j"/4")
end

@testset "append!, deleteat!, pop! for JSONPointer " begin 
    p1 = j"/Root/header"
    p2 = j"/Root/Array/1"
    p3 = j"/Root/Array/2/id"
    p4 = j"/Root/Array/3/comments/1"

    # appendc! tests 
    @test append!(p1, "id") == j"/Root/header/id"
    @test deleteat!(p1, 1) == j"/header/id"
    @test pop!(p1) == j"/header"

    @test append!(p2, "somelongvalues") == j"/Root/Array/1/somelongvalues"
    @test deleteat!(p2, 2) == j"/Root/1/somelongvalues"
    @test pop!(p2) == j"/Root/1"

    @test append!(p3, 1) == j"/Root/Array/2/id/1"
    @test deleteat!(p3, 3) == j"/Root/Array/id/1"
    @test pop!(p3) == j"/Root/Array/id"

    @test append!(p4, 2) == j"/Root/Array/3/comments/1/2"
    deleteat!(p4, 5) == j"/Root/Array/3/comments/2"
    @test pop!(p4) == j"/Root/Array/3/comments"
end

@testset "Testing has_pointer, get_pointer, set_pointer! with Dict and OrderedDict using j literals" begin
    # Create a simple dictionary for testing
    dict = Dict("foo" => 1, "bar" => 2)
    ordered_dict = OrderedDict("foo" => 1, "bar" => 2)

    # Test has_pointer
    @test has_pointer(dict, j"/foo")
    @test has_pointer(ordered_dict, j"/bar")
    @test !has_pointer(dict, j"/baz")
    @test !has_pointer(ordered_dict, j"/baz")

    # Test get_pointer
    @test get_pointer(dict, j"/foo") == 1
    @test get_pointer(ordered_dict, j"/bar") == 2
    @test_throws ElementRetrievalError get_pointer(dict, j"/baz")
    @test_throws ElementRetrievalError get_pointer(ordered_dict, j"/baz")

    # Test set_pointer!
    set_pointer!(dict, j"/foo", 3)
    set_pointer!(ordered_dict, j"/bar", 4)
    @test get_pointer(dict, j"/foo") == 3
    @test get_pointer(ordered_dict, j"/bar") == 4

    # Test setting a new key
    set_pointer!(dict, j"/baz", 5)
    set_pointer!(ordered_dict, j"/baz", 6)
    @test has_pointer(dict, j"/baz")
    @test has_pointer(ordered_dict, j"/baz")
    @test get_pointer(dict, j"/baz") == 5
    @test get_pointer(ordered_dict, j"/baz") == 6
end

@testset "misc test coverage" begin 
    p1 = j"/Root/header"

    @test length(p1) == length(eachindex(p1))

    p2 = j"/NullArray/1::null"
    @test eltype(p2) == Missing 
    @test ismissing(JSONPointer._null_value(p2))


    pointer_doc = PointerDict(Dict(:a => 1))
    @test isa(pointer_doc, PointerDict)
    @test isa(PointerDict(pointer_doc), PointerDict)

    @test JSONPointer.dicttype(pointer_doc) == PointerDict

    doc = Dict("a" => 1)
    set_pointer!(doc, "b", 2)
    @test get_pointer(doc, "a", 0) == 1 
    @test get_pointer(doc, "b", 0) == 2 
    @test ismissing(get_pointer(doc, "c", missing))
end