# JSONPointer
![LICENSE MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)
[![Run CI](https://github.com/YongHee-Kim/JSONPointer.jl/actions/workflows/ci-master.yml/badge.svg)](https://github.com/YongHee-Kim/JSONPointer.jl/actions/workflows/ci-master.yml)
[![Converage](https://github.com/YongHee-Kim/JSONPointer.jl/blob/gh-pages/docs/coverage/badge_linecoverage.svg)](https://yonghee-kim.github.io/JSONPointer.jl/coverage/index)

Implementation of JSON Pointers according to [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901)

# Overview
[JSONPointer](https://tools.ietf.org/html/rfc6901/) is a Unicode string containing a sequence of zero or more reference tokens, each prefixed by a '/' (%x2F) character.

## Key Features
- JSONPointer Syntax Support: The package supports the creation and manipulation of JSON Pointers, allowing users to navigate and access elements within JSON data structures.

**Exported Functions and Types:**
- `@j_str`: allowing string literal `j"/foo"` to construct a JSONPointer 
- `PointerDict`: A type that extends AbstractDict to support JSON Pointers.
- `has_pointer`, `get_pointer`, `set_pointer!`: Functions to check if a pointer exists, retrieve a value by pointer, and set a value by pointer, respectively.

# Tutorial 

## Installation  
JSONPointer is a registered package, you can simply install it by using the Julia package manager in two ways:

with the `Pkg` module
```julia 
using Pkg
Pkg.add("JSONPointer")
```
or the package manager REPL, simply press the ']' key.
```julia
pkg> add JSONPointer
```

## Creating JSONPointer 
To create a JSONPointer, you can use the litteral string `j` or more verbose `JSONPointer.Pointer` type

```julia
using JSONPointer

p1 = j"/foo/bar"
p2 = j"/bar/1"
# or 
p1 = JSONPointer.Pointer("/foo/bar")
p2 = JSONPointer.Pointer("/bar/1")
```
In this example, p1 and p2 are JSONPointers that reference paths within a JSON structure.

## Using JSONPointer with `AbstractDict`
To integrate JSONPointer with AbstractDict types in Julia, you have two effective approaches:

1. Leveraging JSONPointer Functions: Utilize the newly defined functions specifically for JSONPointer, such as `set_pointer!`, `get_pointer`, and `has_pointer`, to interact with your AbstractDict objects.

2. Employing `PointerDict`: Enclose `AbstractDict` instances within PointerDict, which seamlessly integrates with the base interface, enabling operations such as `doc[key]`, `doc[key] = value`, and `haskey(doc, key)`.

### Setting values 
```julia
p1 = j"/foo/bar"
p2 = j"/bar/1"

doc = Dict{String, Any}()
set_pointer!(doc, p1, 1)
set_pointer!(doc, p2, 2)

# with PointerDict
pointer_doc = PointerDict(p1 => 1, p2 =>2)
```

### Getting Values
Continuing from the previous example 
```julia 
pointer_doc[j"/foo"] == get_pointer(doc, j"/foo")
pointer_doc[j"/bar"][1] == get_pointer(doc, j"/bar/1")
```

### haskey check 
One other essential features is checking if `key` is valid within `Abstractdict`
```julia 
doc = Dict("a" => Dict("b" => Dict("c" => [100, Dict("d" => 200)])))
has_pointer(doc, j"/a")
has_pointer(doc, j"/a/b")
has_pointer(doc, j"/a/b/c/1")
has_pointer(doc, j"/a/b/c/2")
has_pointer(doc, j"/a/b/c/2/d")

pointer_doc = PointerDict(doc)
haskey(pointer_doc, j"/a")
haskey(pointer_doc, j"/a/b")
haskey(pointer_doc, j"/a/b/c/1")
haskey(pointer_doc, j"/a/b/c/2")
haskey(pointer_doc, j"/a/b/c/2/d")
```

## Advanced Usage

## Array-index 
- Note that Julia is using 1-based index, 0-based index can be used if argument `shift_index = true` is given to a `JSONPointer.Pointer` constructer
``` julia
julia>JSONPointer.Pointer(j"/foo/0"; shift_index = true)
```

### Constructing Dictionary With Static type

You can enforce type with `::T` at the end of pointer:
```julia
p1 = j"/a::array"
p2 = j"/b/2::string"
data = PointerDict(p1 => [1,2,3], p2 => "Must be a String")

# both of these will throw errors 
data = PointerDict(p1 => "MethodError", p2 => "Must be a String")
data = PointerDict(p1 => [1,2,3], p2 => :MethodError)
```

The type `T` must be one of the six types supported by JSON:
  * `::string`
  * `::number`
  * `::object`
  * `::array`
  * `::boolean`
  * `::null`

### append!, deleteat!, pop! with JSONPointer 
JSONPointer provides basic manipulations after the creation 
```julia
p1 = j"/Root/header"

append!(p1, "id") == j"/Root/header/id"
deleteat!(p1, 1) == j"/header/id"
pop!(p1) == j"/header"
```
Note that these mutates the pointer

### String number as a key
If you need to use a string number as key for dict, put '\' in front of a number
```julia
p1 = j"/\10"
data = PointerDict(p1 => "this won't be a array")
```