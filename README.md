# JSONPointer
![LICENSE MIT](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat-square)
[![Run CI](https://github.com/YongHee-Kim/JSONPointer.jl/actions/workflows/ci-master.yml/badge.svg)](https://github.com/YongHee-Kim/JSONPointer.jl/actions/workflows/ci-master.yml)
[![Converage](https://github.com/YongHee-Kim/JSONPointer.jl/blob/gh-pages/docs/coverage/badge_linecoverage.svg)](https://yonghee-kim.github.io/JSONPointer.jl/coverage/index)

Implementation of JSON Pointers according to [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901)

## Overview
[JSONPointer](https://tools.ietf.org/html/rfc6901/) is a Unicode string containing a sequence of zero or more reference tokens, each prefixed by a '/' (%x2F) character.

## Examples

### Constructing Dictionary

```julia
using JSONPointer

p1 = j"/a/1/b"
p2 = j"/a/2/b"
data = PointerDict(p1 =>1, p2 => 2)
# PointerDict{String,Any} with 1 entry:
#  "a" => Any[OrderedDict{String,Any}("b"=>1), OrderedDict{String,Any}("b"=>2)]

```

### Accessing nested data

```julia
using JSONPointer

arr = [[10, 20, 30, ["me"]]]
arr[j"/1"] == [10, 20, 30, ["me"]]
arr[j"/1/2"] == 20
arr[j"/1/4"] == ["me"]
arr[j"/1/4/1"] == "me"

dict = PointerDict("a" => Dict("b" => Dict("c" => [100, Dict("d" => 200)])))
dict[j"/a"]
dict[j"/a/b"]
dict[j"/a/b/c/1"]
dict[j"/a/b/c/2/d"]
```

## Advanced

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

<<<<<<< develop
data[p1]
=======
    data[p1]
>>>>>>> master
```
